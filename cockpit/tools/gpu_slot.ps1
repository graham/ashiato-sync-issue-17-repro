## TAKE AND RELEASE THE GPU SLOT. One tool, because on 2026-09-19 three lanes hand-rolled the release three
## different ways and ALL THREE FAILED SILENTLY IN ONE NIGHT, each printing success and leaving the line in place:
##
##   lane/ridges      (Get-Content $h) | Where-Object { $_ -ne $mine } | Set-Content $h
##                    `Set-Content` with an EMPTY PIPELINE IS A NO-OP. When your line is the only line the filter
##                    yields nothing, and Set-Content with no input does not empty a file -- it does nothing at all.
##                    It works perfectly whenever somebody else also holds a line, which is most of the time, which
##                    is exactly why nobody had seen it. Held the slot twenty minutes with a lane queued behind it.
##   lane/harrier     grep -v harrier $h > new && mv new $h
##                    `grep -v` EXITS 1 WHEN IT FILTERS OUT EVERY LINE, so the && chain stops and the mv never runs.
##                    Bit the same lane twice; both times the file was printed afterwards and the leftover line was
##                    read as "not removed yet" rather than "the command never ran".
##   lane/twin310     grep "^MEASUREMENT" $h
##                    THE FILE CARRIES A BYTE-ORDER MARK, so an anchored match never sees its first line. And the
##                    mark belongs to the FILE, not to a line: it MIGRATES to whichever line happens to be first, so
##                    a filter that has been working starts failing when another lane releases above you.
##
## Three lanes, three mechanisms, one night, every one of them quiet. That is not three unlucky teammates; it is a
## missing tool. The reading half has been shared and well documented in `tests/run_all.ps1` for weeks and has cost
## nothing in the same period. This is the writing half.
##
## THE ONE RULE THAT MATTERS: a release READS THE FILE BACK and shouts if its line survived. Every failure above was
## survivable; what made them expensive was that each one reported success, so the holder walked away believing it.
##
## Usage, from any lane. `take` prints the line it wrote; hand that back to `release`:
##
##   $line = & tools\gpu_slot.ps1 take -Kind CAPTURE -Note "six island views"
##   try   { ...shoot... }
##   finally { & tools\gpu_slot.ps1 release -Line $line }
##
## NEVER WRAP `run_all.ps1` IN A MANUAL `take -Kind MEASUREMENT`. THE RUNNER TAKES AND WAITS ON THIS SLOT ITSELF,
## so you deadlock against your own hold: it sits printing `waiting: a GPU measurement slot is on (MEASUREMENT
## <you> ...)` and waits for you until the deadline. `lane/syncfix` did exactly this on 2026-09-20, following the
## usage block above, and it cost two minutes only because it read the suite log rather than the wall clock -- the
## full cost is a silent thirty-minute stall. **Take the slot by hand for a CAPTURE, or for a bespoke measurement
## OUTSIDE the runner. Never around the runner.**
##
## AND A HOLD DOES NOT DRAIN WHAT IS ALREADY RUNNING, so taking MEASUREMENT does not give you a quiet machine at
## once -- it gives you one after the in-flight suites finish, which for `smoke` is two to three minutes. That is
## deliberate (`run_all.ps1`: a run BLOCKS before it starts while a measurement holds, but a hold arriving mid-batch
## "stops starting suites and keeps judging the ones it has", so it costs the suites not yet started rather than the
## deadlines of the ones already running). On 2026-09-20 team-lead read the process list, saw two other lanes'
## Godot beside a hold, and wrongly accused both of ignoring the protocol -- they were the tail of batches the
## runner was correctly letting finish. **If you need silence, take the slot and then WAIT FOR THE PROCESS LIST TO
## EMPTY before you measure.** The hold is a request; the process list is the fact.
##
##   while ((Get-CimInstance Win32_Process -Filter "Name like '%godot%'" |
##           Where-Object { $_.CommandLine -match 'gg-wt' -and $_.CommandLine -notmatch $me }).Count) { Start-Sleep 5 }
##
## CAPTURE waits only for a MEASUREMENT and then shares. MEASUREMENT waits for everything, including a hold in a
## format this tool has never seen -- the unknown case blocks, because the cost of waiting for a capture is a queue
## and the cost of not waiting for a measurement is a wrong number nobody can tell is wrong. That direction is
## `run_all.ps1`'s and is not re-litigated here.
##
## THE LANE NAME IS DERIVED, NEVER TYPED. It comes from the worktree this script is running out of, so a lane cannot
## label its line as somebody else by copying a command out of a brief. `lane/stamps` made the same choice for the
## picture stamp on the same night and for the same reason.
##
## THE TIMESTAMP IS THE ACQUISITION, NOT THE START. lane/pilotcost found its line read 20:33:38 while the recorder
## showed it appearing after 20:35:58, because the line was built before the wait loop -- so a run that queued for
## twenty minutes claimed a start twenty minutes before its window opened. That breaks the obvious reconstruction of
## who held the machine when: it shows a lane holding the slot during a period it was only WAITING for it.
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet("take", "release", "show")][string]$Action,
    [ValidateSet("CAPTURE", "MEASUREMENT")][string]$Kind = "CAPTURE",
    [string]$Note = "",
    [string]$Lane = "",
    [string]$Line = "",
    [int]$WaitSeconds = 1800,
    ## AFTER TAKING THE SLOT, WAIT FOR THE MACHINE TO ACTUALLY GO QUIET. Off by default, because it is only right
    ## for a bespoke measurement and would deadlock a gate.
    ##
    ## TAKING THE SLOT IS NOT THE SAME AS HAVING THE MACHINE, and the gap cost lane/detailshaders most of its
    ## measurements on 2026-09-20. `run_all.ps1` blocks a run from STARTING while a MEASUREMENT hold is up, but a
    ## hold arriving mid-batch "stops starting suites and keeps judging the ones it has" (run_all.ps1:412-427) --
    ## deliberately, because otherwise every hold would blow another lane's deadlines. So the hold is honoured with
    ## a DRAIN TIME, and `smoke` alone runs two to three minutes. A lane that took the slot and measured
    ## immediately measured whatever was still finishing, and the symptom is the one thing a frame-time lane cannot
    ## afford: the worst frame is wrong while the median looks fine.
    ##
    ## SO THIS POLLS THE PROCESS LIST RATHER THAN TRUSTING THE FILE. "The machine is quiet" is a claim about what is
    ## running, and the file is a claim about what people intend; only one of those can be verified.
    [switch]$WaitForQuiet,
    ## How long to wait for the drain before giving up and saying so. A drain is a couple of minutes; ten is a
    ## lane that is not going to finish, and being told beats waiting silently.
    [int]$QuietSeconds = 600,
    ## FOR THE SELF-TEST ONLY. `tests/gpu_slot_test.ps1` points this at a scratch file and reproduces all three of
    ## the 2026-09-19 failures against it. A release path that has never been run is the thing that caused this.
    [string]$HoldFile = ""
)

$ErrorActionPreference = "Stop"
$hold = if ($HoldFile -ne "") { $HoldFile } else { "C:\gg-wt\GPU_SLOT_HOLD" }
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

## A BOM BELONGS TO THE FILE AND LANDS ON WHOEVER IS FIRST, so every read strips it rather than every caller
## remembering to. Returns an array of real lines, never $null, so a caller can always count it.
## EVERY MESSAGE THIS SCRIPT PRINTS GOES TO STDERR, NOT TO THE HOST, and that is load-bearing rather than tidy.
## `lane/pilotcost` invoked this with `powershell -File` instead of `&`, which CAPTURES the host output INTO THE
## RETURN VALUE: `$line` came back as "  GPU slot taken: MEASUREMENT ..." with the progress message welded to the
## front, so the later `release -Line $line` matched nothing -- and `-File` also splits an unquoted multi-word
## argument, so the release failed outright. The take succeeded, the release did not, and the slot was stranded by
## exactly the failure this tool exists to eliminate, ten minutes after it landed.
## The cheap answer was a line in the doc block saying "call it with `&`". That is a RULE, and this file exists
## because rules about this file keep being forgotten at the moment of temptation. Writing to stderr is a
## MECHANISM: the returned line is the only thing on stdout, so `&` and `powershell -File` both hand it back clean.
function Say { param([string]$Text) [Console]::Error.WriteLine($Text) }

function Read-TheHold {
    if (-not (Test-Path $hold)) { return @() }
    $raw = ""
    # Another lane may be rewriting the file this instant. With a dozen lanes that is normal, not an error.
    for ($try = 0; $try -lt 20; $try++) {
        try { $raw = [System.IO.File]::ReadAllText($hold); break }
        catch { Start-Sleep -Milliseconds 100 }
    }
    $raw = $raw -replace "^\uFEFF", ""
    ## THE LEADING COMMA IS LOAD-BEARING. PowerShell unwraps a one-element array on return, so without it a file
    ## holding a single line hands back a STRING -- and then `$lines + $mine` in `take` is string CONCATENATION
    ## rather than an append, which silently welds two hold lines into one. The self-test caught that on its first
    ## run, which is the entire argument for the self-test: this tool exists because three lanes shipped a release
    ## path nobody had ever executed.
    return , @($raw -split "`r?`n" | Where-Object { $_ -match '\S' })
}

## ALWAYS WriteAllText, NEVER a pipeline into Set-Content, and an empty list writes an EMPTY FILE rather than
## silently leaving the old contents. That is the ridges bug and this is the whole of its fix.
function Write-TheHold([string[]]$lines) {
    $body = if ($lines -and $lines.Count -gt 0) { ($lines -join "`r`n") + "`r`n" } else { "" }
    for ($try = 0; $try -lt 20; $try++) {
        try { [System.IO.File]::WriteAllText($hold, $body, $utf8NoBom); return }
        catch { Start-Sleep -Milliseconds 100 }
    }
    throw "could not write $hold after 20 tries"
}

## ONE WRITER AT A TIME. Two lanes appending in the same instant would otherwise lose a line, and a LOST line is
## worse than a stale one: the loser believes it holds the slot and nobody else can see that it does.
function Use-TheHoldLock([scriptblock]$body) {
    $mutex = New-Object System.Threading.Mutex($false, "godotgames_gpu_slot_hold")
    $held = $false
    try {
        $held = $mutex.WaitOne(30000)
        if (-not $held) { throw "could not get the hold-file lock in 30 s" }
        & $body
    } finally {
        if ($held) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

function Get-TheLane {
    if ($Lane -ne "") { return $Lane }
    # The worktree this script is in: <root>\cockpit\tools\gpu_slot.ps1 -> <root>.
    $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $leaf = Split-Path $root -Leaf
    $parent = Split-Path $root -Parent
    if ($parent -and ((Split-Path $parent -Leaf) -ieq "gg-wt")) { return $leaf }
    return "main"
}

## Only a MEASUREMENT makes anybody wait. See run_all.ps1's long note; the marker is a LEADING TOKEN because free
## text cannot carry this flag -- every probe here is named `*_shot`, so matching "shot" anywhere once classified a
## measurement as shareable.
function Test-IsShareable([string]$line) {
    return ($line -match "^\s*CAPTURE\b" -or $line -match "^\s*gate_run: probe\b")
}

switch ($Action) {

    "show" {
        $lines = Read-TheHold
        if ($lines.Count -eq 0) { Say "the GPU slot is free" }
        else { $lines | ForEach-Object { Say $_ } }
    }

    "take" {
        ## NO LANE LAYOUT, NO SLOT, AND THAT IS NOT AN ERROR. This used to throw when `C:\gg-wt` was absent, which
        ## quietly made **every tool that called it require the lane layout** -- and the tools that want the slot
        ## are exactly the ones that must keep working on a plain checkout, which is how anybody outside this team
        ## runs them, the user included. `lane/pilotcost` had to wrap the call in a directory test when switching
        ## `testfield_stress.ps1` over, and a guard every caller has to remember is a rule rather than a mechanism.
        ## So: say so on stderr, return nothing, and let the caller run. `release` with an empty line is a no-op,
        ## so the `finally` needs no guard either and the ordinary shape keeps working unchanged.
        if (-not (Test-Path (Split-Path -Parent $hold))) {
            Say "  no $((Split-Path -Parent $hold)) on this machine, so there is no GPU slot to take -- carrying on"
            return ""
        }
        $lane = Get-TheLane
        $until = (Get-Date).AddSeconds($WaitSeconds)
        $told = ""

        while ($true) {
            $current = Read-TheHold
            $blockers = @($current | Where-Object {
                if ($Kind -eq "MEASUREMENT") { $true } else { -not (Test-IsShareable $_) }
            })
            if ($blockers.Count -eq 0) { break }
            if ((Get-Date) -ge $until) { throw "waited $WaitSeconds s for the GPU slot; still held by: $($blockers -join ' | ')" }
            $now = $blockers -join ' | '
            if ($now -ne $told) {
                Say ("  waiting for the GPU slot: {0}" -f $now)
                $told = $now
            }
            Start-Sleep -Seconds 5
        }

        # STAMPED HERE, after the wait, because this is the moment the slot was actually taken.
        $mine = "{0} {1} {2}{3}" -f $Kind, $lane, (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $(if ($Note -ne "") { " $Note" } else { "" })

        Use-TheHoldLock {
            $lines = Read-TheHold
            # Re-check under the lock: somebody may have taken an exclusive slot while we were deciding.
            $late = @($lines | Where-Object { if ($Kind -eq "MEASUREMENT") { $true } else { -not (Test-IsShareable $_) } })
            if ($late.Count -gt 0) { throw "the slot was taken while we were writing: $($late -join ' | '); try again" }
            Write-TheHold (@($lines) + $mine)
        }

        # READ IT BACK. A take that did not land is as bad as a release that did not.
        $after = Read-TheHold
        if (-not (@($after) | Where-Object { $_ -eq $mine })) { throw "wrote the hold line and it is not in the file: $mine" }
        Say ("  GPU slot taken: {0}" -f $mine)
        if ($WaitForQuiet) {
            ## OTHER LANES' GODOTS ONLY: this lane's own editor and the probe about to run are not contention, and
            ## matching them would wait forever. Matched on the worktree path in the command line, which is how
            ## run_all.ps1 tells lanes apart too.
            ## THE WORKTREE THIS SCRIPT IS RUNNING OUT OF, which is how a lane's own Godots are told from everybody
            ## else's -- the same derivation `Get-TheLane` uses, and derived rather than typed for the same reason.
            $myTree = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            $began = Get-Date
            while ($true) {
                $others = @(Get-CimInstance Win32_Process -Filter "Name like '%godot%'" -ErrorAction SilentlyContinue |
                    Where-Object { $_.CommandLine -and $_.CommandLine -notmatch [regex]::Escape($myTree) })
                if ($others.Count -eq 0) { break }
                $waited = [int]((Get-Date) - $began).TotalSeconds
                if ($waited -ge $QuietSeconds) {
                    Say ("  the machine did not go quiet in {0}s: {1} other Godot process(es) still up. Measuring anyway -- SAY SO IN THE REPORT." -f $QuietSeconds, $others.Count)
                    break
                }
                Say ("  slot held; waiting out the drain: {0} other Godot process(es) still running ({1}s)" -f $others.Count, $waited)
                Start-Sleep -Seconds 5
            }
            if ((Get-Date) - $began -lt [TimeSpan]::FromSeconds(5)) { Say "  the machine was already quiet" }
        }
        return $mine
    }

    "release" {
        ## AN EMPTY LINE IS A NO-OP, NOT AN ERROR, so a `finally` can call release unconditionally after a take that
        ## found no lane layout and returned nothing. Throwing here would make every caller guard its own `finally`,
        ## and a `finally` that can throw is how a failure during the work gets replaced by a confusing failure
        ## during the cleanup.
        if ($Line -eq "") { Say "  GPU slot: nothing was taken, so there is nothing to release"; return }
        $mine = ($Line -replace "^\uFEFF", "").Trim()
        if (-not (Test-Path $hold)) { Say "  GPU slot: no hold file, nothing to release"; return }

        Use-TheHoldLock {
            $lines = Read-TheHold
            Write-TheHold @($lines | Where-Object { $_.Trim() -ne $mine })
        }

        # THE WHOLE POINT OF THIS FILE. Every one of the three failures above was survivable; what made them cost
        # forty minutes of other lanes' time was that each reported success and the holder believed it.
        $back = Read-TheHold
        $survivors = @($back | Where-Object { $_.Trim() -eq $mine })
        if ($survivors.Count -gt 0) {
            Say ("  GPU SLOT NOT RELEASED -- the line is still in the file: {0}" -f $mine)
            Say ("  do not walk away from this; other lanes are waiting on it")
            throw "failed to release the GPU slot line"
        }
        Say "  GPU slot released, and the file was read back to prove it"
    }
}
