# THE RUNNER'S OWN TEST: does run_all.ps1 pick the suites it was asked for, and does a hung
# suite in a parallel batch still end at its deadline?
#
#   powershell -File tests\run_all_test.ps1
#
# Prints RESULT=PASS or RESULT=FAIL <names>, like every suite, and takes about a minute. It is
# not a row in suites.txt because it is not a Godot scene: it runs the runner, which runs Godot.
# Run it after touching run_all.ps1 or suites.txt's columns.
#
# TWO HALVES.
#
# WHAT WOULD RUN, asked with -List against the real suites.txt, which starts nothing. This is
# the half that would have caught `-Only lint,docs` matching nothing and running nothing
# (2026-09-18), and a tier typo dropping a suite from every lane's gate.
#
# A PARSE ERROR IN A PARALLEL BATCH. A GDScript parse error does not fail, it HANGS (see
# run_all.ps1), and with several Godots running at once the obvious way to get the deadline
# wrong is to wait on one process while another outstays its welcome. So a throwaway project in
# TEMP holds three suites that pass and one whose script does not parse, all started together
# at -Jobs 4 with a 20 s deadline. The broken one must TIMEOUT, run alone once more, TIMEOUT
# again and fail by name; the three must pass beside it; the whole run must end in well under
# two deadlines' worth of waiting per go; and no Godot started on that project may outlive it.
# That last check is the tree kill: the console launcher starts the editor as its child. With
# the kill cut back to Stop-Process on the launcher alone this still passed (2026-09-19), because
# the launcher's job object takes the child down too; the check guards the outcome either way.
param([int]$Deadline = 20)

$ErrorActionPreference = "Stop"
$runner = Join-Path $PSScriptRoot "run_all.ps1"
$failures = @()
function Check {
    param([string]$Name, [bool]$Held, [string]$Detail = "")
    if ($Held) { Write-Host "  ok    $Name" -ForegroundColor Green; return }
    Write-Host "  FAIL  $Name  $Detail" -ForegroundColor Red
    $script:failures += $Name
}
# One run of the runner in its own PowerShell, the way a lane runs it: its lines and exit code.
function Invoke-TheRunner {
    param([string[]]$Arguments)
    $lines = @(& powershell.exe -NoProfile -File $runner @Arguments 2>&1 | ForEach-Object { "$_" })
    @{ lines = $lines; code = $LASTEXITCODE }
}
function Get-TheListed {
    param($Run)
    @($Run.lines | Where-Object { $_ -match "^\s+(together|alone)\s+(\S+)" } | ForEach-Object { $matches[2] })
}

# ---- what would run ----------------------------------------------------------------------------
$core = Invoke-TheRunner @("-Tier", "core", "-List")
$named = Get-TheListed $core
Check "core_lists_the_cross_craft_geometry_suites" (
    $core.code -eq 0 -and @("lint", "pilot_seat", "water", "fit", "smoke" | Where-Object { $named -notcontains $_ }).Count -eq 0) `
    ($named -join ",")
$pair = Invoke-TheRunner @("-Only", "lint,docs", "-List")
Check "a_comma_list_runs_exactly_those_names" (
    $pair.code -eq 0 -and ((Get-TheListed $pair) -join ",") -eq "lint,docs") ((Get-TheListed $pair) -join ",")
$wild = Invoke-TheRunner @("-Only", "helmet_*", "-List", "-Jobs", "1")
Check "a_wildcard_in_the_list_is_a_wildcard" (
    ((Get-TheListed $wild) -join ",") -eq "helmet_gun,helmet_lock") ((Get-TheListed $wild) -join ",")
$typo = Invoke-TheRunner @("-Only", "lint,no_such_suite", "-List")
Check "a_name_that_matches_nothing_stops_the_run" ($typo.code -ne 0 -and ($typo.lines -join " ") -match "no_such_suite")
$badTier = Invoke-TheRunner @("-Tier", "cor", "-List")
Check "a_tier_that_does_not_exist_stops_the_run" ($badTier.code -ne 0)
$union = Invoke-TheRunner @("-Tier", "solo", "-Only", "lint", "-List")
$unionNamed = Get-TheListed $union
Check "tier_and_names_together_are_the_union_and_solo_runs_alone" (
    $unionNamed -contains "lint" -and $unionNamed -contains "hitch" -and
    @($union.lines | Where-Object { $_ -match "^\s+alone\s+hitch\b" }).Count -eq 1 -and
    @($union.lines | Where-Object { $_ -match "^\s+together\s+lint\b" }).Count -eq 1) ($union.lines -join " | ")

# ---- a parse error in a parallel batch ---------------------------------------------------------
$scratch = Join-Path $env:TEMP ("run_all_test_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$project = Join-Path $scratch "throwaway"
New-Item -ItemType Directory -Path $project | Out-Null
function Write-Text { param([string]$Path, [string]$Text) [System.IO.File]::WriteAllText($Path, $Text.Replace("`r`n", "`n")) }
Write-Text (Join-Path $project "project.godot") "config_version=5`n`n[application]`n`nconfig/name=`"run_all_test`"`n"
Write-Text (Join-Path $project "pass.gd") "extends Node`n`nfunc _ready() -> void:`n`tprint(`"RESULT=PASS`")`n`tget_tree().quit()`n"
Write-Text (Join-Path $project "broken.gd") "extends Node`n`nfunc _ready() -> void:`n`tvar never: int = `n"
foreach ($name in @("pass", "broken")) {
    Write-Text (Join-Path $project "$name.tscn") ("[gd_scene load_steps=2 format=3]`n`n" +
        "[ext_resource type=`"Script`" path=`"res://$name.gd`" id=`"1`"]`n`n" +
        "[node name=`"Root`" type=`"Node`"]`nscript = ExtResource(`"1`")`n")
}
Write-Text (Join-Path $scratch "suites.txt") ("first     throwaway  res://pass.tscn`n" +
    "hangs     throwaway  res://broken.tscn`n" +
    "second    throwaway  res://pass.tscn   core`n" +
    "third     throwaway  res://pass.tscn   solo`n")

$clock = [System.Diagnostics.Stopwatch]::StartNew()
$batch = Invoke-TheRunner @("-SuitesFile", (Join-Path $scratch "suites.txt"), "-Jobs", "4", "-Deadline", "$Deadline")
$clock.Stop()
$text = $batch.lines -join "`n"
Write-Host ($batch.lines | ForEach-Object { "      | $_" } | Out-String).TrimEnd()
Check "the_hung_suite_times_out_twice_and_fails_by_name" (
    @($batch.lines | Where-Object { $_ -match "^\s+hangs\s+TIMEOUT after $Deadline" }).Count -eq 2 -and
    $batch.code -ne 0 -and $text -match "failed in .*: .*hangs")
Check "the_passing_suites_beside_it_pass" (
    @("first", "second", "third" | Where-Object { $text -notmatch "(?m)^\s+$_\s+PASS\b" }).Count -eq 0)
Check "and_only_it_fails" ($text -notmatch "failed in [^:]*: .*(first|second|third)")
# Two goes of $Deadline, the import and three quick suites: generous, and far short of a hang.
Check "the_run_ends_at_its_deadlines" ($clock.Elapsed.TotalSeconds -lt (2 * $Deadline + 90)) (
    "{0:N1} s" -f $clock.Elapsed.TotalSeconds)
Start-Sleep -Seconds 2
$left = @(Get-CimInstance Win32_Process -Filter "Name LIKE '%odot%'" -ErrorAction SilentlyContinue |
    Where-Object { "$($_.CommandLine)" -like "*$project*" })
Check "no_godot_outlives_its_deadline" ($left.Count -eq 0) ("{0} still running" -f $left.Count)
foreach ($orphan in $left) { Stop-Process -Id $orphan.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue

if ($failures.Count -eq 0) { Write-Host "RESULT=PASS"; exit 0 }
Write-Host ("RESULT=FAIL " + ($failures -join ", "))
exit 1
