## THE SELF-TEST FOR tools\gpu_slot.ps1, AND IT IS BUILT OUT OF THE THREE FAILURES THAT CAUSED THE TOOL.
## Each of the first three checks sets up exactly the file state that defeated a hand-rolled release on 2026-09-19
## and requires the tool to survive it. None of those three bugs was found by a test; all three were found by a
## lane sitting idle behind a slot that its holder believed was free.
##
## Runs against a scratch file, never C:\gg-wt\GPU_SLOT_HOLD, so it is safe with lanes live.
## Judge it by the printed RESULT= line, as with every suite here.
$ErrorActionPreference = "Stop"
$tool = Join-Path (Split-Path -Parent $PSScriptRoot) "tools\gpu_slot.ps1"
$scratch = Join-Path $env:TEMP "gpu_slot_test_$PID.txt"
$fails = @()

$script:ran = 0
function Check([string]$name, [bool]$ok, [string]$saw) {
    $script:ran++
    if ($ok) { Write-Host ("  ok   {0}" -f $name) -ForegroundColor DarkGray }
    else { Write-Host ("  FAIL {0} -- {1}" -f $name, $saw) -ForegroundColor Red; $script:fails += $name }
}
function TheLines { if (Test-Path $scratch) { @([System.IO.File]::ReadAllText($scratch) -replace "^\uFEFF", "" -split "`r?`n" | Where-Object { $_ -match '\S' }) } else { @() } }

try {
    # 1. THE ridges BUG: my line is the ONLY line. A pipeline into Set-Content is a no-op here and leaves it.
    Remove-Item $scratch -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllText($scratch, "")
    $mine = & $tool take -Kind CAPTURE -Lane selftest -Note "only line" -HoldFile $scratch
    Check "a_take_lands_in_the_file" ((TheLines).Count -eq 1) "$((TheLines).Count) lines"
    & $tool release -Line $mine -HoldFile $scratch | Out-Null
    Check "the_only_line_is_really_removed" ((TheLines).Count -eq 0) "left: $((TheLines) -join ' | ')"

    # 2. THE twin310 BUG: a byte-order mark sits in front of the FIRST line, and it migrates -- so the mark can end
    #    up in front of MY line when another lane releases above me. An anchored match never sees it.
    Remove-Item $scratch -ErrorAction SilentlyContinue
    $withBom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($scratch, "CAPTURE selftest 2026-09-19 21:00:00 bom line`r`n", $withBom)
    $before = @(TheLines)[0]
    Check "a_bom_does_not_hide_the_first_line" ($before -eq "CAPTURE selftest 2026-09-19 21:00:00 bom line") "read: [$before]"
    & $tool release -Line "CAPTURE selftest 2026-09-19 21:00:00 bom line" -HoldFile $scratch | Out-Null
    Check "a_line_behind_a_bom_is_removed" ((TheLines).Count -eq 0) "left: $((TheLines) -join ' | ')"

    # 3. THE harrier BUG: every line in the file is mine, so a filter that removes them all must still write.
    Remove-Item $scratch -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllText($scratch, "")
    $a = & $tool take -Kind CAPTURE -Lane selftest -Note "first" -HoldFile $scratch
    Start-Sleep -Seconds 1
    $b = & $tool take -Kind CAPTURE -Lane selftest -Note "second" -HoldFile $scratch
    Check "two_captures_share_the_slot" ((TheLines).Count -eq 2) "$((TheLines).Count) lines"
    & $tool release -Line $a -HoldFile $scratch | Out-Null
    & $tool release -Line $b -HoldFile $scratch | Out-Null
    Check "removing_every_line_empties_the_file" ((TheLines).Count -eq 0) "left: $((TheLines) -join ' | ')"

    # 4. A RELEASE THAT DID NOT WORK MUST THROW, not report success. This is the whole reason the tool exists, so
    #    it is asserted rather than assumed: release a line that is not ours and the real one must survive.
    Remove-Item $scratch -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllText($scratch, "")
    $c = & $tool take -Kind CAPTURE -Lane selftest -Note "kept" -HoldFile $scratch
    & $tool release -Line "CAPTURE someoneelse 2026-09-19 21:00:00 not mine" -HoldFile $scratch | Out-Null
    Check "releasing_somebody_elses_line_leaves_mine" ((TheLines).Count -eq 1 -and @(TheLines)[0] -eq $c) "left: $((TheLines) -join ' | ')"
    & $tool release -Line $c -HoldFile $scratch | Out-Null

    # 5. A MEASUREMENT WAITS FOR A CAPTURE; A CAPTURE SHARES WITH ONE. The direction matters and was got wrong once
    #    before it was written down, so it is held here rather than only in prose.
    Remove-Item $scratch -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllText($scratch, "")
    $cap = & $tool take -Kind CAPTURE -Lane selftest -Note "a picture" -HoldFile $scratch
    $shared = & $tool take -Kind CAPTURE -Lane selftest2 -Note "another picture" -HoldFile $scratch
    Check "a_capture_does_not_wait_for_a_capture" ($null -ne $shared) "got nothing back"
    $waited = $false
    try { & $tool take -Kind MEASUREMENT -Lane selftest3 -Note "timing" -WaitSeconds 2 -HoldFile $scratch | Out-Null }
    catch { $waited = $true }
    Check "a_measurement_waits_for_a_capture" $waited "it took the slot anyway"
    & $tool release -Line $cap -HoldFile $scratch | Out-Null
    & $tool release -Line $shared -HoldFile $scratch | Out-Null

    # 6. THE TIMESTAMP IS THE ACQUISITION, NOT THE START. pilotcost's line claimed a start twenty minutes before its
    #    window opened, which makes a queued lane look like the neighbour that spoiled your run.
    Remove-Item $scratch -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllText($scratch, "")
    $blocker = "MEASUREMENT other 2026-09-19 21:00:00 in the way"
    [System.IO.File]::WriteAllText($scratch, "$blocker`r`n")
    $asked = Get-Date
    Start-Sleep -Seconds 3
    [System.IO.File]::WriteAllText($scratch, "")
    $late = & $tool take -Kind MEASUREMENT -Lane selftest -Note "after a wait" -WaitSeconds 30 -HoldFile $scratch
    $stamp = [datetime]::ParseExact(($late -split ' ')[2] + " " + ($late -split ' ')[3], "yyyy-MM-dd HH:mm:ss", $null)
    Check "the_stamp_is_when_the_slot_was_taken" (($stamp - $asked).TotalSeconds -ge 2) "stamp is $((($stamp - $asked).TotalSeconds)) s after asking"
    & $tool release -Line $late -HoldFile $scratch | Out-Null
    # 7. THE RETURNED LINE IS CLEAN UNDER `powershell -File`, NOT ONLY UNDER `&`. lane/pilotcost stranded the slot
    #    ten minutes after this tool landed by invoking it with -File, which captures host output INTO the return
    #    value: the line came back with "  GPU slot taken: " welded to the front and the later release matched
    #    nothing. Progress output goes to stderr for that reason, and this holds it there.
    Remove-Item $scratch -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllText($scratch, "")
    $viaFile = (& powershell -NoProfile -File $tool take -Kind CAPTURE -Lane selftest -Note "via -File" -HoldFile $scratch) -join "`n"
    Check "the_returned_line_carries_no_progress_text" ($viaFile -notmatch 'GPU slot taken' -and $viaFile -match '^CAPTURE selftest ') "got: [$viaFile]"
    & $tool release -Line $viaFile -HoldFile $scratch | Out-Null
    Check "a_line_taken_via_File_can_be_released" ((TheLines).Count -eq 0) "left: $((TheLines) -join ' | ')"

    # 8. NO LANE LAYOUT IS NOT AN ERROR. A `take` with nowhere to write returns nothing and the caller carries on,
    #    and a `release` of nothing is a no-op -- so a tool that wants the slot still runs on a plain checkout,
    #    which is how anybody outside this team runs it. Throwing here made every caller guard its own finally.
    $nowhere = Join-Path $env:TEMP "gpu_slot_no_such_dir_$PID\hold.txt"
    $none = & $tool take -Kind MEASUREMENT -Lane selftest -Note "no layout" -HoldFile $nowhere
    Check "a_take_with_no_lane_layout_returns_nothing" ([string]::IsNullOrEmpty($none)) "got: [$none]"
    $threw = $false
    try { & $tool release -Line "" -HoldFile $nowhere | Out-Null } catch { $threw = $true }
    Check "releasing_nothing_is_not_an_error" (-not $threw) "it threw"
} finally {
    Remove-Item $scratch -ErrorAction SilentlyContinue
}

if ($fails.Count -eq 0) { Write-Host ("RESULT=PASS gpu_slot {0} checks" -f $script:ran) -ForegroundColor Green }
else { Write-Host ("RESULT=FAIL gpu_slot {0}" -f ($fails -join ", ")) -ForegroundColor Red; exit 1 }
