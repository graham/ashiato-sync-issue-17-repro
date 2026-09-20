<#
    Run the ashiato-sync issue #17 reproduction once, or until it fails.

        powershell -ExecutionPolicy Bypass -File tools\issue17\run_repro.ps1
        powershell -ExecutionPolicy Bypass -File tools\issue17\run_repro.ps1 -Repeat 40
        powershell -ExecutionPolicy Bypass -File tools\issue17\run_repro.ps1 -Repeat 40 -TraceRoot D:\issue17

    EXIT CODE 0 MEANS THE BUG APPEARED, which is backwards from a test and the right way
    round for a reproduction: you ran this to find the fault, so finding it is success.
    1 means it did not appear, and 2 means the run could not be judged at all.

    -Repeat N runs up to N times and stops at the first failure, which is what you want
    when you are waiting for an intermittent fault. -All runs all N regardless and prints
    the rate, which is what you want when you are checking whether a fix holds.
#>
param(
    [int]$Repeat = 1,
    [switch]$All,
    [string]$TraceRoot = "",
    # A run is about forty seconds. This is the point at which something is wrong with
    # the machine rather than with the library.
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$root = Split-Path -Parent $root
$godot = Join-Path $root "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$project = Join-Path $root "cockpit"
if (-not (Test-Path $godot)) { Write-Host "Godot is missing. Run setup first." -ForegroundColor Red; exit 2 }

$failed = 0
$passed = 0
$unjudged = 0

for ($i = 1; $i -le $Repeat; $i++) {
    $log = Join-Path $env:TEMP ("issue17_run_{0}.log" -f [Guid]::NewGuid().ToString("N"))
    $arguments = @('--headless','--xr-mode','off','--path',$project,'res://tests/issue17_repro.tscn')
    if ($TraceRoot -ne "") { $arguments += @('--','--trace-root=' + $TraceRoot) }

    # REDIRECTED TO A FILE, NOT PIPED. A pipeline here hands back nothing until the process
    # ends, so a run that hangs looks identical to a run that is working, and the deadline
    # below could never report what the process had already said.
    $p = Start-Process -FilePath $godot -ArgumentList $arguments -WorkingDirectory $root `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Minimized -PassThru
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not $p.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
    $timedOut = -not $p.HasExited
    if ($timedOut) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        # The console executable is a wrapper that starts the real editor and returns, so
        # killing the wrapper can leave the editor and its two children behind. Match them
        # by this checkout's path, never by image name: other Godot work may be running.
        Get-CimInstance Win32_Process -Filter "Name like '%odot%'" |
            Where-Object { $_.CommandLine -and $_.CommandLine -like ("*" + $project + "*") } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    }
    Start-Sleep -Milliseconds 300
    $text = if (Test-Path $log) { Get-Content $log -Raw } else { "" }

    # JUDGED BY THE PRINTED RESULT LINE, NEVER BY THE EXIT CODE. Godot writes to stderr on
    # a healthy run and its exit code carries other meanings.
    $result = ([regex]::Match($text, '(?m)^RESULT=(\w+)')).Groups[1].Value
    $checks = ([regex]::Match($text, '(?m)^RESULT=\w+ ?(.*)$')).Groups[1].Value
    $summary = ([regex]::Match($text, '(?m)^ISSUE17 near=.*$')).Value
    $verdict = ([regex]::Match($text, '(?m)^\s+VERDICT\s+: (.*)$')).Groups[1].Value

    # A FAILED RUN IS NOT AUTOMATICALLY THE BUG, and saying it is would be the worst thing
    # this script could do. The two peers not converging, a missing library, a port already
    # held -- all of those print RESULT=FAIL too, and none of them is the fault being
    # reported. Only the freshness checks mean what we are here for, so only they count.
    # Reported once as "BUG REPRODUCED" on a run whose peers never started, 2026-09-20.
    $isTheBug = ($result -eq "FAIL") -and ($checks -match 'far_craft_stay_fresh|near_craft_stay_fresh')

    if ($Repeat -gt 1) { Write-Host ("run {0,3}/{1}: " -f $i, $Repeat) -NoNewline }
    if ($timedOut) {
        Write-Host "TIMED OUT after $TimeoutSeconds s -- not judged" -ForegroundColor Yellow
        Write-Host "  the whole output is at $log"
        $unjudged++
    } elseif ($isTheBug) {
        Write-Host "BUG REPRODUCED" -ForegroundColor Green
        if ($summary) { Write-Host ("  " + $summary) }
        if ($verdict) { Write-Host ("  " + $verdict) }
        $failed++
        Remove-Item "$log*" -ErrorAction SilentlyContinue
        if (-not $All) { break }
    } elseif ($result -eq "FAIL") {
        Write-Host "COULD NOT RUN -- this is NOT the bug" -ForegroundColor Red
        Write-Host ("  the run failed on: " + $checks)
        if ($verdict) { Write-Host ("  " + $verdict) }
        Write-Host "  the whole output is at $log"
        Write-Host "  the usual cause is a stale build or import; try setup.ps1 -Force"
        $unjudged++
    } elseif ($result -eq "PASS") {
        Write-Host "healthy this run" -ForegroundColor DarkGray
        if ($summary) { Write-Host ("  " + $summary) -ForegroundColor DarkGray }
        $passed++
        Remove-Item "$log*" -ErrorAction SilentlyContinue
    } else {
        Write-Host "NO RESULT LINE -- the run did not get far enough to be judged" -ForegroundColor Red
        Write-Host "  the whole output is at $log"
        $unjudged++
    }
}

$ran = $failed + $passed + $unjudged
Write-Host ""
Write-Host ("{0} run(s): {1} reproduced the bug, {2} were healthy, {3} could not be judged." -f $ran, $failed, $passed, $unjudged)
if ($ran -gt 0 -and ($failed + $passed) -gt 0) {
    Write-Host ("reproduction rate: {0:N0}%  ({1} of {2} judged runs)" -f (100.0 * $failed / ($failed + $passed)), $failed, ($failed + $passed))
}

if ($failed -gt 0) { exit 0 }
if ($unjudged -eq $ran) { exit 2 }
exit 1
