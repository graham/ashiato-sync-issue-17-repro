## RENDER ONE BROWSER-READY CINEMATIC MP4 FOR EVERY DRAWN, FLYING CRAFT.
##
##   powershell -ExecutionPolicy Bypass -File cockpit\tools\create_all_video_demos.ps1
##   ... -ListOnly
##   ... -Kinds cessna,fighter -Seconds 12 -OutputDirectory C:\share\fleet
##
## The set is queried from the running simulation: airplane, helicopter and tiltrotor
## movement models which VehicleCatalogue marks as drawn. Completed files are preserved if
## a later craft fails, and the script reports every failure together at the end.
param(
    [string[]]$Kinds = @(),
    [ValidateRange(4, 60)][double]$Seconds = 24,
    [ValidateRange(1, 120)][int]$Fps = 30,
    [string[]]$Shots = @("orbit", "flyby"),
    [ValidateSet("plain", "fine")][string]$Finish = "fine",
    [ValidateSet("day", "evening", "night")][string]$Time = "day",
    [string]$OutputDirectory = "",
    [string]$Godot = "",
    [string]$Ffmpeg = "",
    [switch]$ListOnly
)

$ErrorActionPreference = "Stop"
# `-Shots orbit,flyby` typed inside PowerShell arrives as an ARRAY, and a [string] parameter
# would join it with a space: the scene then refused "orbit flyby" as an unknown shot. Through
# `powershell -File` the same words arrive as one string. Accept both and pass one comma list.
$Shots = ($Shots | ForEach-Object { $_.Split(",") } | ForEach-Object { $_.Trim() } |
    Where-Object { $_ }) -join ","
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$cockpit = Join-Path $repo "cockpit"
$oneVideo = Join-Path $PSScriptRoot "create_video_demo.ps1"

function Find-GodotEditor {
    param([string]$Asked)
    if ($Asked) {
        if (-not (Test-Path -LiteralPath $Asked)) { throw "Godot editor not found at $Asked." }
        return [IO.Path]::GetFullPath($Asked)
    }
    $commonText = (& git -C $repo rev-parse --git-common-dir 2>$null | Select-Object -First 1)
    $primary = $repo
    if ($commonText) {
        $common = $commonText.Trim()
        if (-not [IO.Path]::IsPathRooted($common)) { $common = Join-Path $repo $common }
        $resolvedCommon = [IO.Path]::GetFullPath($common)
        if ((Split-Path -Leaf $resolvedCommon) -eq ".git") { $primary = Split-Path -Parent $resolvedCommon }
    }
    $found = @(
        (Join-Path $repo "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"),
        (Join-Path $primary "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"),
        (Join-Path $repo "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"),
        (Join-Path $primary "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $found) { throw "No Godot editor found. Pass -Godot or run tools\bootstrap.ps1." }
    return $found
}

$Godot = Find-GodotEditor $Godot
if ($Kinds.Count -eq 0) {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $kindLines = @(& $Godot --headless --xr-mode off --path $cockpit `
        res://tools/list_video_demo_kinds.tscn 2>&1 | ForEach-Object { "$_" })
    $ErrorActionPreference = $savedPreference
    $kindLine = $kindLines | Where-Object { $_ -match '^VIDEO_DEMO_KINDS=' } | Select-Object -Last 1
    if (-not $kindLine) {
        throw "Godot did not report VIDEO_DEMO_KINDS. Output:`n$($kindLines -join [Environment]::NewLine)"
    }
    $Kinds = @($kindLine.Substring("VIDEO_DEMO_KINDS=".Length).Split(",") | Where-Object { $_ })
} else {
    # PowerShell accepts either `-Kinds cessna,fighter` or `-Kinds cessna fighter` depending
    # on the caller, so normalize both into the same unique sequence.
    $Kinds = @($Kinds | ForEach-Object { $_.Split(",") } | ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Where-Object { $_ } | Select-Object -Unique)
}

if ($Kinds.Count -eq 0) { throw "There are no craft to render." }
if (-not $OutputDirectory) {
    $stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
    $OutputDirectory = Join-Path $repo "videos\$stamp-cockpit-fleet"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)

Write-Host ("Craft ({0}): {1}" -f $Kinds.Count, ($Kinds -join ", "))
Write-Host "Output: $OutputDirectory"
if ($ListOnly) {
    Write-Host "LIST_ONLY=PASS"
    exit 0
}

[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$passed = [Collections.Generic.List[string]]::new()
$failed = [Collections.Generic.List[string]]::new()
$started = Get-Date
for ($index = 0; $index -lt $Kinds.Count; $index++) {
    $kind = $Kinds[$index]
    $output = Join-Path $OutputDirectory ("cockpit-{0}-cinematic-demo.mp4" -f $kind)
    $stills = Join-Path $OutputDirectory ("{0}-stills" -f $kind)
    Write-Host ("`n=== [{0}/{1}] {2} ===" -f ($index + 1), $Kinds.Count, $kind.ToUpperInvariant()) `
        -ForegroundColor Cyan
    $arguments = @{
        Kind = $kind; Seconds = $Seconds; Fps = $Fps; Shots = $Shots
        Finish = $Finish; Time = $Time; Output = $output; Stills = $stills; Godot = $Godot
    }
    if ($Ffmpeg) { $arguments.Ffmpeg = $Ffmpeg }
    try {
        & $oneVideo @arguments
        if (-not (Test-Path -LiteralPath $output) -or (Get-Item -LiteralPath $output).Length -eq 0) {
            throw "No non-empty MP4 was written."
        }
        $passed.Add($kind)
    } catch {
        $failed.Add($kind)
        Write-Warning ("{0} failed: {1}" -f $kind, $_.Exception.Message)
    }
}

$elapsed = (Get-Date) - $started
Write-Host "`nFLEET VIDEO SUMMARY" -ForegroundColor Cyan
Write-Host ("Passed ({0}): {1}" -f $passed.Count, ($passed -join ", "))
Write-Host ("Failed ({0}): {1}" -f $failed.Count, ($failed -join ", "))
Write-Host ("Elapsed: {0:hh\:mm\:ss}" -f $elapsed)
Write-Host "VIDEOS=$OutputDirectory"
if ($failed.Count -gt 0) { throw "$($failed.Count) craft video(s) failed." }
Write-Host "RESULT=PASS" -ForegroundColor Green
