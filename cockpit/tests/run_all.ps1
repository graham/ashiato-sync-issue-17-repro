# Every test suite, once each, with a deadline -- several at a time.
#
#   powershell -File tests\run_all.ps1                          # everything (the sweeper, on main)
#   powershell -File tests\run_all.ps1 -Only lint,docs,apache,apache_flight,helmet_*   # a lane's gate
#   powershell -File tests\run_all.ps1 -Tier core -Only apache   # a change drawn on every craft
#   powershell -File tests\run_all.ps1 -Tier core,net -List     # what would run, and nothing else
#   powershell -File tests\run_all.ps1 -Only smoke -Jobs 1      # one at a time, as it used to be
#
# WHICH SUITES. `-Only` is a comma list of names; a name with `*` or `?` in it is a wildcard, a
# name that is exactly a suite's is that suite, and anything else matches every suite with it
# in its name (which is what `-Only water` always meant). `-Tier` is a comma list of the tags in
# suites.txt's fifth column: `core`, `net`, `solo`. Given both, the run is the UNION of the two,
# so a broad change's gate is one command: the tier it touches plus its own suites. A name or a tier that matches
# nothing stops the run with a red line. Until 2026-09-19 `-Only lint,docs` matched nothing and
# ran nothing, silently, and team-lead's own briefs said to do exactly that.
#
# SEVERAL AT A TIME, AND THE LOAD-SENSITIVE ONES ALONE AFTERWARDS. Up to `-Jobs` suites run at
# once, the longest first (by how long each took in this checkout's last run), each with its own
# deadline, and a line is printed as each one finishes. Then every suite tagged `solo` runs by
# itself: those are the ones whose own checks time the wall clock (`hitch`, `link_ms`) or wait on
# a joiner's engine to come up inside a window (`notices`, `lamp_peers`). A solo suite that fails
# is run alone ONCE more, and so is any suite that TIMED OUT in the parallel batch; a pass the
# second time is printed `PASS on retry (load)` and named again in the summary. It is never
# silent, and a real hang still fails, because it hangs twice. See "THE GATE WAS FORTY MINUTES"
# below for what this bought.
#
# THREE THINGS THIS DOES THAT RUNNING THEM BY HAND DOES NOT.
#
#
# --fixed-fps, which is the difference between twelve seconds and two minutes. Headless
# still paces its main loop to real time otherwise, so a suite that waits 4400 physics
# frames for the formations to settle spends thirty-seven seconds of wall clock doing about
# two seconds of work.
#
# And a DEADLINE. A GDScript parse error does not fail, it HANGS: the scene never loads, so
# `_ready` never runs, so nothing ever calls `quit()`, and the run sits there until somebody
# notices. Every suite that ever appeared to take minutes was this. A suite that outstays
# its deadline is killed and reported as TIMEOUT, and the log is scanned for the parse error
# that usually caused it. `lint` runs first now and catches that class in one second.
#
# AND A SUITE THAT PRINTS ENGINE ERRORS FAILS, even if every one of its own checks passed.
# See "the error gate" below. The whole of the lift-zone shading had been silently dead and
# the only evidence was two million lines of stderr that nothing was reading.
#
# BUT A SUITE THAT FAILS ITS OWN CHECKS IS NEVER SCANNED FOR ENGINE ERRORS AT ALL, and that
# is the half this note used to leave out (lane/boatcrew, 2026-09-20). The gate runs only
# after RESULT=PASS, so a red hides everything behind it: `crew_sync` failed on "no view of
# kind 37" while 279 SCRIPT ERRORs from ExhaustYard.lay sat in the same log unread, and they
# appeared only when the FAIL was fixed. The runs most likely to be concealing engine errors
# are therefore the runs already showing you a failure -- exactly when somebody is reading
# one line and not the log. FIX THE FAIL AND RE-RUN BEFORE BELIEVING A CLEAN LOG.

# A DEADLINE IS A GUARD AGAINST A HANG, NOT A PERFORMANCE BUDGET. This is the one every suite
# gets unless its row in suites.txt names its own in a fourth column. Two suites do, because
# they are structurally slower than the rest: `ship_legs` and `level_swap` both walk EVERY
# usable level, so each level anyone adds lengthens them and nothing else. Raising this number
# for everybody instead would have hidden that the gate grows with the game (lane/stress,
# 2026-09-17, when a sixth level took ship_legs from 125.7 s to 197.9 s and past 180).
# `smoke` joined them on 2026-09-19: it walks every craft kind, and with the Prowler, the CB90 and the Apache
# (kinds 29 to 31) and 13 Godots live on the machine it wrote RESULT=PASS on all 215 checks just after 180 s,
# twice, on main and in lane/mountains. It was 106-150 s a day earlier. Its row names 300.
#
# THE GATE WAS FORTY MINUTES, AND SEVENTY WHEN THE LANES WERE BUSY (lane/gate, 2026-09-19). Two
# hundred and ten suites ran one after another, one Godot each, and the median times of 52 full
# runs found in the lanes' logs add up to 2,388 s. Most of that is not the work: a suite is about
# 3 s of Godot starting before its first line, and the machine has 32 threads. The numbers from
# before and after are in running_a_team_here.md, "Running the gate".
param(
    # [string[]] and not [string]: `-Only a,b` typed inside PowerShell arrives as an ARRAY, and
    # a [string] parameter would join it with a space. Through `-File` it arrives as "a,b". Both
    # are split on commas and spaces below, so both mean the same.
    [string[]]$Only = @(),
    [string[]]$Tier = @(),
    # 0 means "decide": a quarter of the logical processors, at most 8. A quarter and not a half,
    # because this machine is rarely running one gate, and each suite with peers is three Godots.
    [int]$Jobs = 0,
    # Print what would run, in which phase, and stop. Imports nothing and starts nothing.
    [switch]$List,
    [int]$Deadline = 180,
    # Another list than tests\suites.txt, for tests\run_all_test.ps1. Its project column may name
    # a folder, relative to the list, as well as `cockpit` or `addon`.
    [string]$SuitesFile = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
# THE DOUBLE-PRECISION EDITOR IF THERE IS ONE, and the stock one if there is not.
#
# The world is ten kilometres across and float32 draws its far corner on a half-millimetre
# grid, so this project is built against a Godot compiled with `precision=double`. That
# binary is not something you can download -- see agents.md -- so the suite runs on
# whichever is present rather than insisting, and says which it used.
#
# It matters that the tests run on the SAME build the game does: the extension is bound to
# one precision or the other and the two disagree about the width of every real_t crossing
# the boundary.
$godot = Join-Path $root "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
if (-not (Test-Path $godot)) {
    $godot = Join-Path $root "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
}
$cockpit = Join-Path $root "cockpit"
$addon = Join-Path $root "ashiato-gd\addon"

# THE SUITES COME FROM tests\suites.txt, which run_all.sh reads too. Two lists went out of
# step -- this one had been missing `water` and `air` for as long as they had existed, so a
# Windows run reported all-green over two suites it had never heard of.
$listFile = if ($SuitesFile) { (Resolve-Path $SuitesFile).Path } else { Join-Path $PSScriptRoot "suites.txt" }
# THE TIERS THERE ARE. A tag suites.txt spells any other way stops the run: `cor` on a row would
# otherwise quietly drop that suite out of every lane's gate.
$tiers = @("core", "net", "solo")
$suites = @(
    Get-Content $listFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $parts = @($line -split "\s+")
        $where = switch ($parts[1]) {
            "cockpit" { $cockpit }
            "addon"   { $addon }
            default   {
                $folder = Join-Path (Split-Path -Parent $listFile) $parts[1]
                if (-not $SuitesFile -or -not (Test-Path (Join-Path $folder "project.godot"))) {
                    throw "suites.txt: unknown project '$($parts[1])' for $($parts[0])"
                }
                (Resolve-Path $folder).Path
            }
        }
        # AFTER THE SCENE, A NUMBER IS THIS SUITE'S OWN DEADLINE IN SECONDS and a word is its
        # tiers, comma-separated, and almost no row has either. See the note on $Deadline above
        # for why a slow suite says so here rather than everybody's deadline being raised to
        # suit it, and suites.txt's header for what each tier is for.
        $its = 0
        $tags = @()
        foreach ($extra in @($parts | Select-Object -Skip 3)) {
            if ($extra -match "^[0-9]+$") { $its = [int]$extra; continue }
            foreach ($tag in ($extra -split ",")) {
                if ($tiers -notcontains $tag) {
                    throw "suites.txt: '$extra' is neither a deadline in seconds nor tiers ($($tiers -join ', ')) for $($parts[0])"
                }
                $tags += $tag
            }
        }
        @{ name = $parts[0]; path = $where; scene = $parts[2]; deadline = $its; tiers = $tags }
    }
)

# WHAT WAS ASKED FOR. Split on commas and spaces, because `-File` delivers "a,b" and an in-process
# call delivers @("a", "b"); see the param block.
$askedNames = @(($Only -join ",") -split "[,\s]+" | Where-Object { $_ -ne "" })
$askedTiers = @(($Tier -join ",") -split "[,\s]+" | Where-Object { $_ -ne "" })
foreach ($tag in $askedTiers) {
    if ($tiers -notcontains $tag) {
        Write-Host "No tier '$tag'. The tiers are: $($tiers -join ', ')." -ForegroundColor Red
        exit 1
    }
}

function Test-TheNameMatches {
    param([string]$Name, [string]$Asked, [string[]]$AllNames)
    if ($Asked -match "[\*\?\[]") { return $Name -like $Asked }
    if ($AllNames -contains $Asked) { return $Name -eq $Asked }
    return $Name -like "*$Asked*"
}

if ($askedNames.Count -gt 0 -or $askedTiers.Count -gt 0) {
    $allNames = @($suites | ForEach-Object { $_.name })
    # EVERY ASKED NAME MUST MATCH SOMETHING. One that matches nothing is a typo in a gate, and a
    # gate that quietly runs one suite fewer than it was told reads exactly like a green one.
    foreach ($asked in $askedNames) {
        if (-not @($suites | Where-Object { Test-TheNameMatches $_.name $asked $allNames }).Count) {
            Write-Host "No suite matches '$asked'." -ForegroundColor Red
            exit 1
        }
    }
    # @() forces an array. A lone hashtable answers .Count with the number of KEYS it has,
    # so filtering down to one suite cheerfully reported "all 3 suites pass".
    $suites = @($suites | Where-Object {
        $suite = $_
        (@($askedTiers | Where-Object { $suite.tiers -contains $_ }).Count -gt 0) -or
            (@($askedNames | Where-Object { Test-TheNameMatches $suite.name $_ $allNames }).Count -gt 0)
    })
}
if ($suites.Count -eq 0) {
    Write-Host "No suite matches -Only '$($askedNames -join ',')' -Tier '$($askedTiers -join ',')'." -ForegroundColor Red
    exit 1
}

if ($Jobs -le 0) { $Jobs = [math]::Max(1, [math]::Min(8, [int]([Environment]::ProcessorCount / 4))) }
# THE TWO PHASES. Everything not tagged `solo` shares the machine; the solo ones follow, one at a
# time. With -Jobs 1 the first phase is simply the old serial run in file order.
$together = @($suites | Where-Object { $_.tiers -notcontains "solo" })
$alone = @($suites | Where-Object { $_.tiers -contains "solo" })


# THE LOG DIRECTORY IS PER WORKTREE, NOT PER USER, AND THAT IS A CORRECTNESS MATTER RATHER
# THAN TIDINESS. This was `$env:TEMP\cockpit_tests` until 2026-09-17: one directory for the
# whole account, while eight lanes ran against it from eight worktrees.
#
# The runner redirects each suite's stdout to `<log>\<suite name>.log` and then JUDGES THE RUN
# BY THE `RESULT=` LINE IT READS BACK FROM THAT FILE. Two lanes running the same suite name at
# the same time write the same path, so each can read the other's verdict. `lane/fleet3` was
# handed a neighbour's `lint FAIL` on 2026-09-17 while `lint` passed standalone in its own
# tree and the shared log said PASS -- the file had last been written by a different lane's
# run seconds earlier, and three other `run_all.ps1` processes were live at that moment.
#
# A false red costs a rerun. THE REVERSE COSTS A BAD MERGE: a lane can read a neighbour's
# `RESULT=PASS` and report itself green, and nothing in the output says so. It also quietly
# voids CLAUDE.md's first rule, which assumes the printed line came from your own run.
#
# Keyed by the full path of the checkout, so two worktrees can share a leaf name and still get
# their own directory. `tools/gate_run.ps1` already writes inside the worktree and was the
# precedent.
$logKey = [System.BitConverter]::ToString(
    [System.Security.Cryptography.MD5]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($root.ToLowerInvariant()))).Replace("-", "").Substring(0, 8)
$log = Join-Path $env:TEMP ("cockpit_tests_" + (Split-Path $root -Leaf) + "_" + $logKey)
# A LIST OF ITS OWN KEEPS ITS OWN LOGS, beside it: tests/run_all_test.ps1 runs throwaway suites and
# they have no business in this checkout's durations.
if ($SuitesFile) { $log = Join-Path (Split-Path -Parent $listFile) "logs" }
if (-not (Test-Path $log)) { New-Item -ItemType Directory -Path $log | Out-Null }

# THE LONGEST FIRST. With N at a time, a run lasts at least as long as its longest suite PLUS
# whatever was still queued when that one started, so `ship_legs` (200 s) starting last in a
# queue of 200 is a run that ends three minutes after everything else. How long each suite took
# is kept per checkout, in the log directory, from the last run that passed it. A suite never
# timed here is guessed from its own deadline (the slow ones have one) or else as ten seconds.
# `lint` goes first whatever the numbers say: it compiles every script in one pass, and when it
# fails, every other red in the run is probably the same parse error.
$durationsFile = Join-Path $log "durations.txt"
$durations = @{}
if (Test-Path $durationsFile) {
    foreach ($row in Get-Content $durationsFile) {
        $cells = $row -split "\s+"
        if ($cells.Count -eq 2 -and $cells[1] -match "^[0-9.]+$") { $durations[$cells[0]] = [double]$cells[1] }
    }
}
function Get-TheGuess {
    param($Suite)
    if ($Suite.name -eq "lint") { return [double]::MaxValue }
    if ($durations.ContainsKey($Suite.name)) { return $durations[$Suite.name] }
    if ($Suite.deadline -gt 0) { return $Suite.deadline / 2.0 }
    return 10.0
}
if ($Jobs -gt 1) {
    # Sort-Object is not stable on 5.1, so the file position breaks ties and the order repeats.
    $position = @{}
    for ($i = 0; $i -lt $together.Count; $i++) { $position[$together[$i].name] = $i }
    $together = @($together | Sort-Object -Property @{ Expression = { - (Get-TheGuess $_) } },
        @{ Expression = { $position[$_.name] } })
}

if ($List) {
    Write-Host ("{0} suites: {1} on {2} job(s), then {3} alone" -f $suites.Count, $together.Count, $Jobs, $alone.Count)
    foreach ($suite in $together) {
        Write-Host ("  together  {0,-26} {1,-8} {2}" -f $suite.name, ($suite.tiers -join ","),
            $(if ($suite.deadline -gt 0) { "$($suite.deadline)s" } else { "" }))
    }
    foreach ($suite in $alone) {
        Write-Host ("  alone     {0,-26} {1,-8} {2}" -f $suite.name, ($suite.tiers -join ","),
            $(if ($suite.deadline -gt 0) { "$($suite.deadline)s" } else { "" }))
    }
    exit 0
}

# Errors a test provokes on purpose. Kept identical to the list in run_all.sh.
$allowedErrors = "\[ashiato\] field .* has an unknown type|" +
    "\[ashiato\] add\(\): component was not registered|" +
    "\[CockpitWorld\] that formation is a circle"

$failed = @()
# Suites started a second time, and the one exit that earns it: 0xC06D007F as a signed Int32. See the suite loop.
$retried = @()
$windowsKilledItAtStart = -1066598273

# THE PLAYER'S COCKPITS, AS THEY WERE BEFORE ANY SUITE RAN. `user://` is the same folder for a suite as for the game on
# this machine, and on 2026-09-13 a full gate deleted the plane cockpit the user had saved an hour earlier (see
# CockpitLayout, TEST_FOLDER). Suites now keep their own elsewhere; this is what says so after every run, by the
# name, size and hash of every file there, and fails the run by name if one changed, appeared or went.
$playerCockpits = Join-Path $env:APPDATA "Godot\app_userdata\cockpit\cockpits"
function Get-PlayerCockpits {
    $seen = @{}
    if (Test-Path $playerCockpits) {
        foreach ($file in Get-ChildItem $playerCockpits -File -Recurse) {
            $seen[$file.FullName.Substring($playerCockpits.Length)] = (Get-FileHash $file.FullName).Hash
        }
    }
    $seen
}
$playerCockpitsBefore = Get-PlayerCockpits
$total = [System.Diagnostics.Stopwatch]::StartNew()

# CAN THE EDITOR STILL OPEN THE PROJECT? Asked first, because nothing else here asks it.
#
# Every suite below runs the game, and the game is more forgiving than the editor about one
# thing in particular: a cyclic dependency between a script and a scene. At runtime the loop
# comes apart in whatever order the loads happen to arrive in and everything works. In the
# editor, `preload` has to resolve while the script is being COMPILED, so a cycle stops a
# scene loading -- and what it says is not a word about cycles:
#
#   res://marshalling/hand/marshal_rig.tscn:6 - Parse Error: .
#   Failed loading resource: res://marshalling/hand/marshal_rig.tscn.
#
# Sixteen suites passed while that was true of this project. It was found by opening the
# editor, which is a poor last line of defence, and it will happen again the next time
# something near the bottom of the tree reaches for something near the top.
#
# `--import` is also what registers a NEW class_name, so this earns its place twice: without
# it, the first run after adding one fails with "Identifier not found" for a class that is
# sitting right there on disk.
#
# AND IT STANDS ASIDE WHEN AN EDITOR IS ALREADY OPEN. `--import` writes the project's
# `.godot` directory, and so does a running editor; the two racing over it wedged a suite
# for nineteen minutes with an empty log and no deadline that fired. The check is worth
# having and it is not worth having at the cost of the run somebody is watching.
#
# AN EDITOR IS KNOWN BY ITS COMMAND LINE, NOT BY HAVING A WINDOW TITLE. This used to skip the
# import whenever any process named like Godot had a MainWindowTitle -- and a GAME has one too:
# a windowed probe, a watch camera, even a console Godot running another agent's suite. On
# 2026-09-12 that skipped every import for a day while other sessions ran Godot, the class cache
# stayed at 2026-09-11, and six suites failed on "Identifier not declared" for classes that
# were on disk and committed. An editor is a Godot started with `-e`/`--editor`; the project
# manager is `-p`/`--project-manager` or the bare executable, and a project it opens is started
# with `--editor`. A game with `--path` and no `-e` is not an editor, windowed or not.
#
# AND ONLY AN EDITOR ON THIS PROJECT STANDS IN THE WAY. On 2026-09-15 the user had an editor open
# on another project (recharger, `--editor --path .../recharger`), every lane's run skipped its
# import, and lint failed "Identifier NightSkyTuning not declared" in each lane that had just
# rebased onto a new class. An editor writes the `.godot` of the project it has open and no
# other, so with -Project an editor counts only when its --path is that project, or when it
# names no --path and so could be anywhere. The project manager holds no project's `.godot`.
function Get-OpenEditors {
    param([string]$Project = "")
    $want = if ($Project) { [System.IO.Path]::GetFullPath($Project).TrimEnd('\', '/') } else { "" }
    @(Get-CimInstance Win32_Process -Filter "Name LIKE '%odot%'" -ErrorAction SilentlyContinue |
        Where-Object {
            $line = "$($_.CommandLine)".Trim()
            $arguments = $line -replace '^("[^"]*"|\S+)\s*', ''
            $editor = $line -match '(^|\s)(-e|--editor)(\s|$)'
            $manager = ($line -match '(^|\s)(-p|--project-manager)(\s|$)') -or ($arguments -eq "")
            if (-not $want) { return $editor -or $manager }
            if (-not $editor) { return $false }
            if ($line -notmatch '--path\s+("([^"]+)"|(\S+))') { return $true }
            $opened = if ($matches[2]) { $matches[2] } else { $matches[3] }
            [System.IO.Path]::GetFullPath($opened).TrimEnd('\', '/') -ieq $want
        })
}

# A LANE TIMING THE GPU HOLDS EVERY OTHER LANE'S GODOT BY A FILE, NOT A MESSAGE. The timing lane
# writes C:\gg-wt\GPU_SLOT_HOLD at the start of its slot and deletes it at the end. A run is
# checked before EACH launch, because a detached gate reads no messages. On 2026-09-15 six
# launches from one lane's scripts voided mist's slot after three holds had been sent. The wait
# is outside every suite's clock and deadline. See running_a_team_here.md, "A hold sent to an
# agent doesn't stop its detached scripts".
#
# ONLY A PERFORMANCE HOLD MAKES ANYBODY WAIT, and that is the whole of the rule (the user, on
# 2026-09-17: "if you are not doing performance testing, you can do multiple runs on the same
# gpu, you only need to be careful if one of those is testing performance where noise would be
# an issue"). Sharing a GPU costs a picture nothing -- framing, colour and geometry do not
# depend on load -- and costs a functional headless suite nothing either. It costs exactly one
# thing: a number that is a DURATION.
#
# Waiting for every hold was measured to be expensive on 2026-09-17, when eight lanes were
# live: one lane held the slot for fourteen minutes to take a picture, and TWO other lanes had
# nothing they could run at all -- not even a headless lint -- because this function blocked
# before every launch. Both found it independently within ten minutes.
#
# So a hold declares its kind on its first line, and IT DECLARES THE SAFE THING BY DEFAULT.
# A hold whose first line BEGINS with the word CAPTURE is advisory: it says the GPU is busy
# and blocks nobody. EVERY OTHER HOLD IS EXCLUSIVE, including one in a format this function
# has never seen.
#
# THE MARKER IS A LEADING TOKEN, NOT A WORD ANYWHERE IN THE LINE, and that was found by
# testing rather than by thinking. Matching "capture|picture|shot|share" anywhere classified
# `gate_run[123]: measurement of probe ocean_shot` as shareable -- because EVERY probe in this
# project is named `*_shot`, the one word guaranteed to appear in a measurement's hold was the
# word that meant "do not wait for me". Free text cannot carry this flag.
#
# That direction is deliberate and was got wrong once before it was written down. Matching
# "perf" to decide who waits means an unrecognised hold sails through, and the first real hold
# tested against it was `lane/stress`'s "link_ms gate (three processes, wall-clock latency)" --
# a timing run, with no "perf" in it, that would have been trampled. The cost of waiting for a
# capture is a queue; the cost of not waiting for a measurement is a wrong number that nobody
# can tell is wrong. So the unknown case blocks.
$gpuSlotHold = "C:\gg-wt\GPU_SLOT_HOLD"

function Get-TheSlotHolder {
    # Returns the hold's first line, or "" when there is no hold. A hold being deleted between
    # the test and the read is normal with eight lanes and is not an error.
    if (-not (Test-Path $gpuSlotHold)) { return "" }
    $who = Get-Content $gpuSlotHold -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $who) { return "" }
    return [string]$who
}

function Wait-TheGpuSlot {
    $told = $false
    while ($true) {
        $who = Get-TheSlotHolder
        if ($who -eq "") { break }
        # `gate_run: probe <name>` is what the wrapper wrote for one commit, before the marker
        # existed. A lane that rebased in that window still runs that copy, and its captures
        # would block everybody until it rebases again -- which is the cost this whole change
        # removes. Recognising the old spelling is two words and it expires when the lanes do.
        if ($who -match "^\s*CAPTURE\b" -or $who -match "^\s*gate_run: probe\b") {
            # Somebody is drawing a picture. Nothing they are doing can be spoiled by us and
            # nothing we are doing can be spoiled by them. Say so once and carry on.
            if (-not $told) {
                Write-Host ("  sharing the GPU with {0}" -f $who) -ForegroundColor DarkGray
            }
            break
        }
        if (-not $told) {
            Write-Host ("  waiting: a GPU measurement slot is on ({0})" -f $who) -ForegroundColor DarkGray
            $told = $true
        }
        Start-Sleep -Seconds 10
    }
}

# THE SAME QUESTION WITHOUT WAITING, for the parallel batch: true while a measurement holds the
# slot. The batch stops STARTING suites and keeps judging the ones it has, so a hold that arrives
# mid-run costs the suites not yet started and not the deadlines of the ones already running.
$script:toldOfTheHold = ""
function Test-TheGpuIsHeld {
    $who = Get-TheSlotHolder
    if ($who -eq "") { return $false }
    $shared = ($who -match "^\s*CAPTURE\b" -or $who -match "^\s*gate_run: probe\b")
    if ($script:toldOfTheHold -ne $who) {
        $script:toldOfTheHold = $who
        $say = if ($shared) { "sharing the GPU with" } else { "waiting: a GPU measurement slot is on" }
        Write-Host ("  {0} ({1})" -f $say, $who) -ForegroundColor DarkGray
    }
    return (-not $shared)
}


function Test-TheEditorCanOpenIt {
    param([string]$Name, [string]$Path, [switch]$Retried)
    if (-not (Test-Path $Path)) { return $true }
    Wait-TheGpuSlot
    # @() because one match comes back as a bare CimInstance, whose .Count reads empty on 5.1.
    if (@(Get-OpenEditors -Project $Path).Count -gt 0) {
        Write-Host ("  {0,-24} SKIP   (an editor is open; it would fight over .godot)" -f `
            "editor:$Name") -ForegroundColor DarkGray
        return $true
    }
    $out = Join-Path $log "import_$Name.log"
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $run = Start-Process -FilePath $godot -PassThru -NoNewWindow -RedirectStandardOutput $out `
        -RedirectStandardError "$out.err" `
        -ArgumentList @("--headless", "--xr-mode", "off", "--desktop-only", "--import", "--path", $Path)
    if (-not $run.WaitForExit(300 * 1000)) {
        Stop-Process -Id $run.Id -Force -ErrorAction SilentlyContinue
        Write-Host ("  {0,-24} TIMEOUT importing" -f "editor:$Name") -ForegroundColor Red
        return $false
    }
    $clock.Stop()
    # NAMED FAILURES ONLY. A clean import still prints "Plugin is not attached to debugger",
    # so a bare search for "ERROR" reports every run as broken and is quietly turned off by
    # whoever is next in a hurry.
    $broke = Select-String -Path $out, "$out.err" `
        -Pattern "Failed loading resource|Parse Error|SCRIPT ERROR|SHADER ERROR|Compile Error" `
        -ErrorAction SilentlyContinue
    $seconds = [math]::Round($clock.Elapsed.TotalSeconds, 1)
    # THE ONE FAILURE THAT IS NOT THIS PROJECT'S: two imports racing over Godot's own editor
    # settings, which live once per USER in AppData and not once per checkout. Since every
    # single-suite run imports (see the note at the call site), eight lanes now import far more
    # often than they used to, and they collide: "Failed loading resource:
    # .../editor_settings-4.7.tres". It is transient by construction -- the loser reads a file
    # the winner is mid-write -- and the next run passes, which is how it was found.
    #
    # So that ONE pattern, alone, earns a second attempt. Any other named failure is the
    # project's and is reported first time, and a second collision in a row is reported too:
    # a retry that hides a real fault is worse than the flake it papers over.
    if ($broke -and -not $Retried -and
            ($broke | Where-Object { $_.Line -match "editor_settings-[\d.]+\.tres" }) -and
            -not ($broke | Where-Object { $_.Line -notmatch "editor_settings-[\d.]+\.tres" })) {
        Write-Host ("  {0,-24} RETRY  {1,5}s  another import held Godot's shared editor settings" -f `
            "editor:$Name", $seconds) -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        return (Test-TheEditorCanOpenIt -Name $Name -Path $Path -Retried)
    }
    if (-not $broke) {
        Write-Host ("  {0,-24} PASS   {1,5}s" -f "editor:$Name", $seconds) -ForegroundColor Green
        return $true
    }
    Write-Host ("  {0,-24} FAIL   {1,5}s  the editor cannot load this project" -f `
        "editor:$Name", $seconds) -ForegroundColor Red
    foreach ($line in ($broke | Select-Object -First 4)) {
        Write-Host ("      " + $line.Line.Trim()) -ForegroundColor Red
    }
    Write-Host ("      full log: {0}" -f $out) -ForegroundColor Red
    return $false
}

# ALWAYS, NOT ONLY ON A FULL GATE. This was `if ($Only -eq "")`, and that guard is where three
# lanes lost an hour each on 2026-09-17.
#
# `Test-TheEditorCanOpenIt` is what runs `--headless --import`, and the import is what registers
# a NEW `class_name`. A lane checks itself with `-Only <suite>` after a rebase -- which is
# exactly when a new class has just arrived from somebody else's merge -- and under the old
# guard that path never imported. `tools/gate_run.ps1 -Suite` delegates here, so it inherited
# the hole too.
#
# WHAT IT COSTS AND WHAT IT BUYS. A no-op import on a warm cache is 6.0 s, measured by
# `lane/airbase` on a tree where the work had just been done. `lint` alone is 14 s. What it buys
# is that `RESULT=FAIL every_script_compiles` always means what it says: a stale cache reports a
# parse error naming a class that is sitting in the tree, which reads exactly like a real
# regression from whichever lane added it. The gate does not fail honestly, it lies, and
# somebody then reads an innocent diff.
#
# A CONDITION THAT CAN BE WRONG IS HOW THIS BUG EXISTS (`lane/airbase`), so there is no
# cleverer test here -- no "import if HEAD moved". Only the projects the chosen suites actually
# use are imported, which is the one saving that cannot be wrong: a suite that never opens the
# addon project does not need it registered.
$wanted = @()
foreach ($suite in $suites) {
    if ($wanted -notcontains $suite.path) { $wanted += $suite.path }
}
# ONCE PER PROJECT PER RUN, whatever -Only asks for. A lane that looped `-Only <name>` over its
# twelve suites paid twelve imports, about two minutes, before this took a list.
foreach ($path in $wanted) {
    $name = if ($path -eq $cockpit) { "cockpit" } elseif ($path -eq $addon) { "addon" } else { Split-Path $path -Leaf }
    if (-not (Test-TheEditorCanOpenIt -Name $name -Path $path)) {
        $failed += "editor:" + $name
    }
}

# ---- starting a suite, and judging it -------------------------------------------------------
#
# stderr to its own file rather than the console: `conformance` deliberately feeds the
# extension bad input and the errors it prints are the test working.
# BOTH FLAGS ARE REQUIRED. `--xr-mode off` disables the renderer's XR mode, while the
# project's `--desktop-only` flag stops its own OpenXR startup path before it probes the
# runtime. Omitting the latter still opened the runtime during a headless full suite on
# 2026-09-16. The error gate below must be able to say "this suite printed nothing".
#
# ONE MORE START FOR A SUITE WINDOWS KILLED BEFORE IT BEGAN, and for nothing else. Now and then a Godot dies
# while Windows is still loading it, before a line of GDScript runs: exit code 0xC06D007F, nothing printed,
# and "no RESULT line" in whichever suite was starting. The minidumps (%LOCALAPPDATA%\CrashDumps) say dinput8.dll
# could not reach CreateInputHostForProcess in inputhost.dll on one of the loader's own threads. That call is
# made before Godot's first thread, is not Godot's (no SDL hint or flag touches it, measured 2026-09-13), and hit
# trim, missile_cues and others six times in a week. So that exact code with no RESULT is started once more and
# says RETRIED; any other exit, or a second one, is judged as it always was. See agents.md, "THE CRASH THAT WAS
# NOT THE VOICE". Not in run_all.sh: DirectInput is Windows', and bash sees only the low byte of an exit code.
#
# EACH SUITE IN A PARALLEL BATCH GETS A JOB SLOT, 1 to -Jobs, in COCKPIT_TEST_SLOT. A checkout has
# one `user://` and one block of ports, and until suites ran side by side nothing needed more:
# `builder` and `pedals` write a plane's seat layout into `user://test_cockpits` while `fit`,
# `stations` and `smoke` read it, and `craft_peers` and `radio_peers` ask for overlapping ports.
# The slot moves both (`CockpitLayout.test_slot`, `TestPorts`), and a child a suite starts
# inherits it with the rest of the environment. Suites run alone get no slot, so a solo run is
# the same run as one typed by hand.
function Start-TheSuite {
    param($Suite, [int]$Slot, [int]$Starts = 1)
    $out = Join-Path $log "$($Suite.name).log"
    if ($Slot -gt 0) { $env:COCKPIT_TEST_SLOT = "$Slot" }
    try {
        $run = Start-Process -FilePath $godot -PassThru -NoNewWindow -RedirectStandardOutput $out `
            -RedirectStandardError "$out.err" `
            -ArgumentList @("--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120",
                "--path", $Suite.path, $Suite.scene)
    } finally {
        Remove-Item Env:COCKPIT_TEST_SLOT -ErrorAction SilentlyContinue
    }
    # Held, or ExitCode comes back empty once the process is gone.
    $null = $run.Handle
    # THIS SUITE'S DEADLINE: its own from suites.txt, or the one on the command line.
    $its = if ($Suite.deadline -gt 0) { [int]$Suite.deadline } else { $Deadline }
    @{ suite = $Suite; run = $run; out = $out; slot = $Slot; starts = $Starts; deadline = $its
        clock = [System.Diagnostics.Stopwatch]::StartNew() }
}

# A DEADLINE KILLS THE WHOLE TREE. The `.console.exe` is a wrapper that starts the editor `.exe`
# as its child (the process list shows both, the second parented on the first), and CLAUDE.md
# records a killed launcher leaving that child spinning. Measured here on 2026-09-19 with
# tests/run_all_test.ps1, Stop-Process on the wrapper alone DID take the child with it, twice, so
# on this build the wrapper's job object does the work. taskkill /T stays anyway: it costs
# nothing, and an orphan in a parallel batch is a core and a block of ports held until somebody
# notices, and a PORT BUSY in whichever suite asks for those ports next.
function Stop-TheTree {
    param([int]$Id)
    & cmd.exe /c "taskkill /T /F /PID $Id >nul 2>&1"
}

# What a finished (or killed) suite said: PASS, FAIL, ERRORS or TIMEOUT, and the words to print.
function Get-TheVerdict {
    param($Entry, [bool]$TimedOut)
    $out = $Entry.out
    $seconds = [math]::Round($Entry.clock.Elapsed.TotalSeconds, 1)
    if ($TimedOut) {
        $why = Select-String -Path $out, "$out.err" -Pattern "Parse Error|Compile Error" -ErrorAction SilentlyContinue |
            Select-Object -First 1
        $said = if ($why) { $why.Line.Trim() } else { "" }
        return @{ status = "TIMEOUT"; seconds = $seconds; text = ("after {0}s  {1}" -f $Entry.deadline, $said).TrimEnd() }
    }
    $result = Select-String -Path $out, "$out.err" -Pattern "RESULT=" -ErrorAction SilentlyContinue | Select-Object -Last 1
    # THE ERROR GATE. A suite that prints engine errors has failed, whatever its own checks
    # said -- see the note at the top. The allowlist is of MESSAGES and not of suites,
    # because exempting a suite exempts the next real error inside it too; these three are
    # errors a test provokes on purpose to prove the extension rejects what it should.
    # `lint` is the one suite exempt by name, since printing parse errors is its job.
    $noise = @()
    if ($Entry.suite.name -ne "lint") {
        # SHADER ERROR too: on 2026-09-15 a shared shader include redefined another include's
        # `lit`, the engine printed "SHADER ERROR:" and every suite still printed RESULT=PASS.
        $noise = @(Select-String -Path $out, "$out.err" -Pattern "^(ERROR|SCRIPT ERROR|SHADER ERROR):" -ErrorAction SilentlyContinue |
            Where-Object { $_.Line -notmatch $allowedErrors })
    }
    if (-not ($result -and $result.Line -match "RESULT=PASS")) {
        $said = if ($result) { $result.Line.Trim() } else { "no RESULT line -- see $out" }
        return @{ status = "FAIL"; seconds = $seconds; text = $said }
    }
    if ($noise.Count -gt 0) {
        $first = $noise[0].Line.Trim()
        if ($first.Length -gt 100) { $first = $first.Substring(0, 100) }
        return @{ status = "ERRORS"; seconds = $seconds; text = ("{0} engine error(s), first: {1}" -f $noise.Count, $first) }
    }
    return @{ status = "PASS"; seconds = $seconds; text = "" }
}

function Write-TheVerdict {
    param([string]$Name, $Verdict, [string]$Label = "", [string]$After = "")
    $word = if ($Label) { $Label } else { $Verdict.status }
    $colour = switch ($Verdict.status) { "PASS" { if ($Label) { "Yellow" } else { "Green" } } default { "Red" } }
    if ($Verdict.status -eq "TIMEOUT") {
        $line = "  {0,-24} {1} {2}" -f $Name, $word, $Verdict.text
    } else {
        $line = ("  {0,-24} {1,-6} {2,5}s  {3}" -f $Name, $word, $Verdict.seconds, $Verdict.text).TrimEnd()
    }
    if ($After) { $line += "  " + $After }
    Write-Host $line -ForegroundColor $colour
}

# RUN A QUEUE, up to $Width at a time, and hand back each suite's verdict as it finishes. One
# PowerShell process polls the Godots it started, four times a second: no jobs and no runspaces,
# which on 5.1 cost a second or more each to start and lose Write-Host's colours on the way back.
function Invoke-TheQueue {
    param([object[]]$Queue, [int]$Width, [switch]$Slotted)
    $pending = New-Object System.Collections.ArrayList
    foreach ($suite in $Queue) { [void]$pending.Add($suite) }
    $running = @{}
    $verdicts = New-Object System.Collections.ArrayList
    while ($pending.Count -gt 0 -or $running.Count -gt 0) {
        while ($pending.Count -gt 0 -and $running.Count -lt $Width -and -not (Test-TheGpuIsHeld)) {
            $slot = 1
            while ($running.ContainsKey($slot)) { $slot++ }
            $suite = $pending[0]
            $pending.RemoveAt(0)
            $running[$slot] = Start-TheSuite -Suite $suite -Slot $(if ($Slotted) { $slot } else { 0 })
        }
        Start-Sleep -Milliseconds 250
        foreach ($slot in @($running.Keys)) {
            $entry = $running[$slot]
            $name = $entry.suite.name
            if ($entry.run.HasExited) {
                if ($entry.starts -eq 1 -and $entry.run.ExitCode -eq $windowsKilledItAtStart -and
                        -not (Select-String -Path $entry.out, "$($entry.out).err" -Pattern "RESULT=" -Quiet)) {
                    Write-Host ("  {0,-24} RETRIED  Windows killed it while loading (exit 0x{1:X8}, nothing printed)" -f `
                        $name, $entry.run.ExitCode) -ForegroundColor Yellow
                    $script:retried += $name
                    $running[$slot] = Start-TheSuite -Suite $entry.suite -Slot $entry.slot -Starts 2
                    continue
                }
                $entry.clock.Stop()
                $verdict = Get-TheVerdict -Entry $entry -TimedOut $false
            } elseif ($entry.clock.Elapsed.TotalSeconds -gt $entry.deadline) {
                Stop-TheTree -Id $entry.run.Id
                $null = $entry.run.WaitForExit(10000)
                $entry.clock.Stop()
                $verdict = Get-TheVerdict -Entry $entry -TimedOut $true
            } else {
                continue
            }
            $running.Remove($slot)
            $verdict.suite = $entry.suite
            [void]$verdicts.Add($verdict)
            # Printed here, as each finishes, because a forty-minute run that prints nothing until
            # the end is one that gets killed at minute thirty by somebody who thought it had hung.
            Write-TheVerdict -Name $name -Verdict $verdict -After $(
                if ($verdict.status -eq "TIMEOUT" -and $Width -gt 1) { "-- will run alone once more" } else { "" })
        }
    }
    return ,$verdicts
}

# ---- the run --------------------------------------------------------------------------------
$passedOnRetry = @()
$secondChance = @()
$first = Invoke-TheQueue -Queue $together -Width $Jobs -Slotted:($Jobs -gt 1)
foreach ($verdict in $first) {
    if ($verdict.status -eq "PASS") { $durations[$verdict.suite.name] = $verdict.seconds; continue }
    # A TIMEOUT WITH OTHERS RUNNING MAY BE THE OTHERS. A timeout alone is not: -Jobs 1 does not retry.
    if ($verdict.status -eq "TIMEOUT" -and $Jobs -gt 1) { $secondChance += $verdict.suite; continue }
    $failed += $verdict.suite.name
}

if ($alone.Count + $secondChance.Count -gt 0) {
    Write-Host ("  -- {0} alone: {1}" -f ($alone.Count + $secondChance.Count),
        ((@($alone) + @($secondChance) | ForEach-Object { $_.name }) -join ", ")) -ForegroundColor DarkGray
}
# THE SOLO SUITES, ONE AT A TIME, AND ONE MORE GO EACH. What a pass on the second go means is
# "this suite is sensitive to the machine's load", which is true of every suite tagged solo and
# is written down beside each one; it is not "this suite passed", and the summary keeps them apart.
foreach ($suite in @($alone) + @($secondChance)) {
    $wasTimedOut = @($secondChance | Where-Object { $_.name -eq $suite.name }).Count -gt 0
    $verdict = (Invoke-TheQueue -Queue @($suite) -Width 1)[0]
    if ($verdict.status -eq "PASS") {
        if ($wasTimedOut) { $passedOnRetry += $suite.name } else { $durations[$suite.name] = $verdict.seconds }
        continue
    }
    if ($wasTimedOut) { $failed += $suite.name; continue }
    # The first go's log is kept beside the second's, so the red that was load can still be read.
    Copy-Item (Join-Path $log "$($suite.name).log") (Join-Path $log "$($suite.name).first.log") -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $log "$($suite.name).log.err") (Join-Path $log "$($suite.name).first.log.err") -ErrorAction SilentlyContinue
    Write-Host ("  {0,-24} -- running it alone once more" -f $suite.name) -ForegroundColor DarkGray
    $again = (Invoke-TheQueue -Queue @($suite) -Width 1)[0]
    if ($again.status -eq "PASS") { $passedOnRetry += $suite.name } else { $failed += $suite.name }
}
# The second go of a retried suite prints its own PASS line; this says what that PASS was.
foreach ($name in $passedOnRetry) {
    Write-Host ("  {0,-24} PASS on retry (load)" -f $name) -ForegroundColor Yellow
}

# How long each suite took, for the next run's order. Only passes: a timeout's time is its deadline.
try {
    $durations.Keys | Sort-Object | ForEach-Object { "{0} {1}" -f $_, $durations[$_] } |
        Set-Content -Path $durationsFile -Encoding ascii
} catch {
    Write-Host "  (could not keep the durations: $($_.Exception.Message))" -ForegroundColor DarkGray
}

$total.Stop()
Write-Host ""
$playerCockpitsAfter = Get-PlayerCockpits
$touched = @($playerCockpitsBefore.Keys + $playerCockpitsAfter.Keys | Sort-Object -Unique | Where-Object {
    $playerCockpitsBefore[$_] -ne $playerCockpitsAfter[$_] })
if ($touched.Count -gt 0) {
    Write-Host ("  {0,-24} FAIL   a suite changed the player's own cockpits in {1}: {2}" -f "player-files",
        $playerCockpits, ($touched -join ", ")) -ForegroundColor Red
    $failed += "player-files"
}
if ($retried.Count -gt 0) {
    Write-Host ("Started twice because Windows killed the first while loading: " + ($retried -join ", ")) `
        -ForegroundColor Yellow
}
if ($passedOnRetry.Count -gt 0) {
    Write-Host ("Passed only on a second go alone (load): " + ($passedOnRetry -join ", ")) -ForegroundColor Yellow
}
## SAY WHICH COMMIT THIS RAN ON, AND WHETHER IT IS STILL MAIN'S TIP. A lane's gate is green and truthful and can
## still be STALE: on 2026-09-19 lane/harrier gated against a base that did not yet contain the P-47, so the exhaust
## ratchet it had set to the then-correct 28 went red on main within minutes of merging. Nothing was wrong with the
## lane or with its gate; the fleet had changed underneath it. Team-lead cannot see that from a list of PASS lines,
## so the gate now states its own base and, when the checkout can see main, how far behind it is. A number on this
## line is the difference between "green" and "green as of a world that no longer exists".
$base = (git rev-parse --short=8 HEAD 2>$null)
$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
$dirty = if ((git status --porcelain 2>$null)) { " +dirty" } else { "" }
$behind = ""
if ($base) {
    # `main` may not exist in every checkout, and a missing main is not an error worth failing a gate over.
    $count = (git rev-list --count "HEAD..main" 2>$null)
    if ($LASTEXITCODE -eq 0 -and $count -match '^\d+$') {
        if ([int]$count -eq 0) {
            $behind = ", level with main"
        } else {
            ## A COUNT IS A QUESTION; THE THING IT STANDS FOR IS THE ANSWER. lane/harrier hit this within an hour of
            ## the banner landing: its re-gate printed "1 BEHIND MAIN" where the one commit was team-lead's merge OF
            ## ITS OWN WORK, so the trees were identical and re-running would have produced byte-identical results
            ## on a byte-identical tree. **Every lane goes "1 behind" the instant its own merge lands**, which is
            ## exactly the moment it is reading this line -- so without the tree check this warning cries wolf on
            ## the whole team, every time, and a warning people learn to ignore costs you the real catches it is
            ## here for. The count stays, because a count is cheap and honest; the two `rev-parse`s that tell you
            ## whether it MEANS anything are cheaper still. Same shape as the exhaust ratchet printing the set
            ## rather than the size.
            $mineTree = (git rev-parse "HEAD^{tree}" 2>$null)
            $mainTree = (git rev-parse "main^{tree}" 2>$null)
            $behind = if ($mineTree -and $mineTree -eq $mainTree) {
                ", $count behind main but the tree is IDENTICAL -- nothing to re-run"
            } else {
                ", $count BEHIND MAIN -- rebase before you call this green"
            }
        }
    }
}
if ($base) {
    $colour = if ($behind -match "BEHIND") { "Yellow" } else { "DarkGray" }
    Write-Host ("Ran on {0} {1}{2}{3}" -f $branch, $base, $dirty, $behind) -ForegroundColor $colour
}
$how = "{0}s on {1} job(s)" -f [math]::Round($total.Elapsed.TotalSeconds, 1), $Jobs
if ($failed.Count -eq 0) {
    Write-Host ("All $($suites.Count) suites pass in $how.") -ForegroundColor Green
    exit 0
}
Write-Host ("$($failed.Count) of $($suites.Count) failed in ${how}: " + ($failed -join ", ")) `
    -ForegroundColor Red
exit 1
