# THE TEST FIELD'S STRESS TEST, ON REQUEST: its `stress` traffic at each scale, one headless run a scale, and the table.
#
#   powershell -File cockpit\tools\testfield_stress.ps1                       # scales 1, 2, 4
#   powershell -File cockpit\tools\testfield_stress.ps1 -Scales 8             # 200 aircraft: about 25 minutes
#   powershell -File cockpit\tools\testfield_stress.ps1 -Scales 1,2           # just those
#
# The user, 2026-09-19: "have a stress test that increases the amount of ai traffic on that map (not by default but
# runnable on request)". It is not a suite and nothing runs it unless asked. Each run is tests/testfield_stress.tscn with
# `--traffic=stress --traffic-scale=K`: a minute of simulation to spread the traffic, then two measured, and one `STRESS`
# line of numbers (see that file). The runs take a MEASUREMENT line in C:\gg-wt\GPU_SLOT_HOLD when that file exists,
# wait while anybody else holds one, and remove their own line at the end, because a timing beside somebody else's
# render is not a timing. The table is written to the console and to testfield_stress.txt beside the logs.
# -Scales IS A COMMA STRING split here: an [int[]] parameter handed "1,2,4,8" through `powershell -File` arrives as the
# one number 1248, and the first run asked for 31,200 aeroplanes.
param(
    [string]$Scales = "1,2,4",
    [int]$Deadline = 1200
)
$scaleList = @($Scales -split "[, ]+" | Where-Object { $_ -ne "" } | ForEach-Object { [int]$_ })
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$godot = Join-Path $root "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
if (-not (Test-Path $godot)) { $godot = Join-Path (Split-Path -Parent $root) "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe" }
if (-not (Test-Path $godot)) { $godot = "C:\Users\Graham\Desktop\godotgames\_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe" }
$project = Join-Path $root "cockpit"
$logs = Join-Path $env:TEMP "testfield_stress"
New-Item -ItemType Directory -Force $logs | Out-Null
# THE GPU SLOT IS `tools/gpu_slot.ps1`'s BUSINESS AND NOT THIS TOOL'S. Three lanes hand-rolled this release on
# 2026-09-19 and all three got it wrong differently -- a kill filter that matched its own shell, a `Set-Content` with an
# empty pipeline that is a no-op, and (here) a line stamped before the wait rather than at the take, which reports a
# lane as holding the slot through minutes it was only queueing for. That tool owns all of it and has a self-test that
# reproduces every one of them.
#
# UNGUARDED ON PURPOSE. `take` says so and carries on where there is no `C:\gg-wt`, and `release` of nothing is a
# no-op, so this probe keeps working on a plain checkout with no lane infrastructure -- which is how anybody outside
# the team runs it, the user included. There is nothing here to test for and nothing for a `finally` to guard.
$slot = Join-Path $PSScriptRoot "gpu_slot.ps1"
$mine = & $slot take -Kind MEASUREMENT -Lane "testfield-stress" -Note "$($scaleList -join ',') scales"
# IMPORT FIRST, ALWAYS. This tool launches the scene directly, and a class added with `class_name` anywhere in the
# project is not in the global script class cache until an editor import has run: every script that mentions one
# parse-errors, the scene never reaches `RESULT=`, and each scale comes back "NO RESULT" with nothing to say why.
# After merging main -- which is exactly when a measurement is wanted -- that is the normal state of a lane. It cost a
# validation run to find, and `run_all.ps1` has imported first since long before this tool existed (lane/pilotcost,
# 2026-09-19; testfield's learnings, "a class added with class_name is not in the cache until an import").
Write-Host "importing $project first (a new class_name elsewhere parse-errors a direct launch)"
$import = Start-Process -FilePath $godot -PassThru -WindowStyle Minimized -ArgumentList @("--headless",
    "--xr-mode", "off", "--desktop-only", "--import", "--path", $project)
if (-not $import.WaitForExit(420 * 1000)) {
    Stop-Process -Id $import.Id -Force -ErrorAction SilentlyContinue
    Write-Host "import timed out; the scales below may parse-error" -ForegroundColor Yellow
}
$rows = @()
try {
    foreach ($scale in $scaleList) {
        $log = Join-Path $logs "scale-$scale.log"
        Remove-Item $log -ErrorAction SilentlyContinue
        $p = Start-Process -FilePath $godot -PassThru -WindowStyle Minimized -ArgumentList @("--headless", "--fixed-fps", "120",
            "--xr-mode", "off", "--path", $project, "res://tests/testfield_stress.tscn", "--log-file", $log, "--",
            "--traffic=stress", "--traffic-scale=$scale")
        $until = (Get-Date).AddSeconds($Deadline)
        while ((Get-Date) -lt $until) {
            Start-Sleep 5
            if ((Test-Path $log) -and (Select-String -Path $log -Pattern "RESULT=" -Quiet)) { break }
        }
        # GODOT ONLY, AND NEVER THIS SCRIPT: its own command line names the project and testfield_stress too, and the first
        # version killed itself after the first scale and left its MEASUREMENT line up.
        Get-CimInstance Win32_Process | Where-Object { $_.Name -like "godot*" -and $_.ProcessId -ne $PID `
                -and $_.CommandLine -like "*$project*" -and $_.CommandLine -like "*testfield_stress*" } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        $line = Select-String -Path $log -Pattern "^STRESS scale=" | Select-Object -First 1
        $rows += if ($line) { $line.Line } else { "STRESS scale=$scale NO RESULT (see $log)" }
        Write-Host $rows[-1]
        # EVERY LINE THE PROBE PRINTS, not a chosen few: how the traffic flew, what each chore kind cost and where a
        # look's time went are all in the log, and a filter of (held|conflicts|losses) left them there unread while the
        # table above them looked complete. They go to the console AND into the table file, so a run can be read later.
        $rest = Select-String -Path $log -Pattern "^STRESS " | Where-Object { $_.Line -notmatch "^STRESS scale=" }
        $rest | ForEach-Object { Write-Host "  $($_.Line)" }
        $rows += $rest | ForEach-Object { "  " + $_.Line }
        $rows += "  (full log: $log)"
    }
} finally {
    # `release` of nothing is a no-op, so no guard here either.
    & $slot release -Line $mine
}
$rows | Set-Content (Join-Path $logs "testfield_stress.txt")
