<#
.SYNOPSIS
Runs the public GDScript conformance suite from a fresh, isolated addon project.

.DESCRIPTION
The addon project's bin directory is build output and is intentionally ignored. A fresh
worktree therefore has the test project but no library. This runner stages the addon
source with the repository's committed Cockpit DLLs, performs a fresh editor import, and
runs conformance with a wall-clock deadline. It never consumes an ignored DLL left by an
earlier build.

Read RESULT= in the preserved log rather than relying on Godot's exit code.
#>
param(
    [string]$GodotPath = "",
    [int]$Deadline = 60,
    [string]$LogDirectory = "",
    [switch]$KeepWorkspace
)

$ErrorActionPreference = "Stop"
$ashiatoRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $ashiatoRoot
$addonSource = Join-Path $ashiatoRoot "addon"
$artifactSource = Join-Path $repoRoot "cockpit\addons\ashiato\bin"

if ($Deadline -lt 1) { throw "Deadline must be at least one second." }

if (-not $GodotPath) {
    $checkoutWithTools = $repoRoot
    try {
        $commonGit = (& git -C $repoRoot rev-parse --path-format=absolute --git-common-dir 2>$null |
            Select-Object -First 1)
        if ($commonGit) { $checkoutWithTools = Split-Path -Parent $commonGit.Trim() }
    } catch {}
    $GodotPath = Join-Path $checkoutWithTools `
        "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
}
$GodotPath = [System.IO.Path]::GetFullPath($GodotPath)
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot not found at $GodotPath. Pass -GodotPath explicitly."
}

$requiredArtifacts = @("ashiato_gd.dll", "ashiato_gd.double.dll")
foreach ($name in $requiredArtifacts) {
    $source = Join-Path $artifactSource $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Committed addon artifact is missing: $source"
    }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
if (-not $LogDirectory) {
    $LogDirectory = Join-Path $env:TEMP ("ashiato_conformance_logs\" + $stamp)
}
$LogDirectory = [System.IO.Path]::GetFullPath($LogDirectory)
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

$workspaceParent = Join-Path $env:TEMP "ashiato_conformance_workspaces"
New-Item -ItemType Directory -Path $workspaceParent -Force | Out-Null
$workspace = Join-Path $workspaceParent ("run_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $workspace | Out-Null

function Invoke-BoundedGodot {
    param([string]$Label, [string[]]$Arguments)
    $stdout = Join-Path $LogDirectory ($Label + ".log")
    $stderr = $stdout + ".err"
    $process = Start-Process -FilePath $GodotPath -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr `
        -ArgumentList $Arguments
    $finished = $process.WaitForExit($Deadline * 1000)
    if (-not $finished) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        $process.WaitForExit()
        return @{ Finished = $false; Stdout = $stdout; Stderr = $stderr }
    }
    return @{ Finished = $true; Stdout = $stdout; Stderr = $stderr }
}

$passed = $false
try {
    # robocopy gives us an exact recursive copy while excluding generated editor state.
    # Return codes below 8 are success (including "files copied").
    & robocopy $addonSource $workspace /E /XD .godot | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }

    $stagedBin = Join-Path $workspace "addons\ashiato\bin"
    New-Item -ItemType Directory -Path $stagedBin -Force | Out-Null
    foreach ($name in $requiredArtifacts) {
        Copy-Item -LiteralPath (Join-Path $artifactSource $name) `
            -Destination (Join-Path $stagedBin $name)
        $hash = (Get-FileHash -Algorithm SHA256 (Join-Path $stagedBin $name)).Hash
        Write-Host ("Staged {0} ({1})" -f $name, $hash)
    }

    $import = Invoke-BoundedGodot "import" @(
        "--headless", "--xr-mode", "off", "--desktop-only", "--editor", "--import",
        "--quit-after", "300", "--path", $workspace)
    if (-not $import.Finished) { throw "Fresh import exceeded the ${Deadline}s deadline." }
    $importText = (Get-Content $import.Stdout, $import.Stderr -Raw `
        -ErrorAction SilentlyContinue) -join "`n"
    if ($importText -match "GDExtension dynamic library not found|Failed loading resource|Parse Error|SCRIPT ERROR|SHADER ERROR|Compile Error") {
        throw "Fresh import reported a load or compile failure. See $($import.Stdout)"
    }
    $extensionList = Join-Path $workspace ".godot\extension_list.cfg"
    if (-not (Test-Path -LiteralPath $extensionList) -or
            -not (Select-String -LiteralPath $extensionList `
                -Pattern "res://addons/ashiato/ashiato.gdextension" -Quiet)) {
        throw "Fresh import did not discover the Ashiato GDExtension."
    }

    $run = Invoke-BoundedGodot "conformance" @(
        "--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120",
        "--path", $workspace, "res://tests/conformance.tscn")
    if (-not $run.Finished) { throw "Conformance exceeded the ${Deadline}s deadline." }
    $runText = (Get-Content $run.Stdout, $run.Stderr -Raw `
        -ErrorAction SilentlyContinue) -join "`n"
    if ($runText -notmatch "\[conformance\] RESULT=PASS") {
        throw "Conformance did not report RESULT=PASS. See $($run.Stdout)"
    }
    $unexpected = $runText -split "`r?`n" | Where-Object {
        $_ -match "^(ERROR|SCRIPT ERROR|SHADER ERROR):" -and
        $_ -notmatch "\[ashiato\] add\(\): component was not registered" -and
        $_ -notmatch "\[ashiato\] field .* has an unknown type"
    }
    if ($unexpected) {
        throw "Conformance printed an unexpected engine error: $($unexpected[0])"
    }
    if (($importText + $runText) -match "OpenXR|XR_ERROR|XR runtime") {
        throw "A run attempted to initialize an XR runtime. See logs in $LogDirectory"
    }

    $passed = $true
    Write-Host "[run_conformance] RESULT=PASS"
    Write-Host "Logs: $LogDirectory"
} catch {
    Write-Host "[run_conformance] RESULT=FAIL ($($_.Exception.Message))" -ForegroundColor Red
    Write-Host "Logs: $LogDirectory"
} finally {
    if ($KeepWorkspace) {
        Write-Host "Workspace: $workspace"
    } else {
        $resolvedParent = [System.IO.Path]::GetFullPath($workspaceParent).TrimEnd('\')
        $resolvedWorkspace = [System.IO.Path]::GetFullPath($workspace)
        if ((Split-Path -Parent $resolvedWorkspace) -ne $resolvedParent -or
                -not (Split-Path -Leaf $resolvedWorkspace).StartsWith("run_")) {
            throw "Refusing to remove unexpected workspace path: $resolvedWorkspace"
        }
        Remove-Item -LiteralPath $resolvedWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not $passed) { exit 1 }
