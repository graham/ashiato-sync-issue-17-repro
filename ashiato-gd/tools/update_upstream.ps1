<#
Pulls both upstreams, rebuilds, and re-runs conformance plus the three replication
loopbacks (driving, vr, cockpit), the cockpit's on the double editor when it is here.

    powershell -File tools\update_upstream.ps1            # report; rebuilds and verifies
    powershell -File tools\update_upstream.ps1 -Pull      # actually pull, then verify

It REBUILDS whether or not you pass -Pull, because a report that the revisions
are unchanged is not the same as a report that they still work. That rebuild
lands in every sibling game -- build.ps1 copies the fresh binary into each one --
so it is built with the full feature set by default. Without that, running this
quietly replaced the racer's driving-enabled binary with one that has no
DrivingWorld in it, and the only symptom was the game saying the extension was
not loaded. -Bare opts out if you genuinely want the core-only build.

This is the answer to "the library keeps growing". After an upstream pull the
question is not "does it still compile" -- it is "does it still BEHAVE" -- so this
always finishes by running the conformance test against the freshly built binary.

It also reports the thing most likely to bite: ashiato-sync pins its own ashiato
revision, and that pin lags the ECS. Building sync against a newer ECS is a
combination upstream has never tested, so the gap is printed rather than hidden.
#>

[CmdletBinding()]
param(
    [switch]$Pull,
    [switch]$WithSync,
    # Build the core only. The default is everything, because the binary produced here
    # is the one every sibling game gets.
    [switch]$Bare
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$parent = Split-Path -Parent $root
$ashiato = Join-Path $parent "ashiato"
$sync = Join-Path $parent "ashiato-sync"
$lock = Join-Path $root "upstream.lock"

function Say { param([string]$Text) Write-Host $Text }

function Rev { param([string]$Dir) return (& git -C $Dir rev-parse HEAD).Trim() }

function Sync-Pinned-Ashiato {
    $file = Join-Path $sync "cmake\AshiatoSyncDependencies.cmake"
    if (-not (Test-Path $file)) { return "unknown" }
    $match = Select-String -Path $file -Pattern '"([0-9a-f]{40})"' | Select-Object -First 1
    if ($match) { return $match.Matches[0].Groups[1].Value }
    return "unknown"
}

foreach ($dir in @($ashiato, $sync)) {
    if (-not (Test-Path (Join-Path $dir ".git"))) { throw "Not a checkout: $dir" }
}

$before_ashiato = Rev $ashiato
$before_sync = Rev $sync

if ($Pull) {
    Say "Pulling upstreams..."
    & git -C $ashiato pull --ff-only
    & git -C $sync pull --ff-only
}

$after_ashiato = Rev $ashiato
$after_sync = Rev $sync
$pinned = Sync-Pinned-Ashiato

Say ""
Say ("ashiato       {0}{1}" -f $after_ashiato.Substring(0,12),
    $(if ($after_ashiato -ne $before_ashiato) { "   (was $($before_ashiato.Substring(0,12)))" } else { "" }))
Say ("ashiato-sync  {0}{1}" -f $after_sync.Substring(0,12),
    $(if ($after_sync -ne $before_sync) { "   (was $($before_sync.Substring(0,12)))" } else { "" }))
Say ("sync pins     {0}" -f $pinned.Substring(0, [Math]::Min(12, $pinned.Length)))

if ($pinned -ne "unknown" -and $pinned -ne $after_ashiato) {
    $behind = (& git -C $ashiato rev-list --count "$pinned..$after_ashiato" 2>$null)
    Say ""
    Say ("NOTE: the ECS is {0} commit(s) ahead of what ashiato-sync pins." -f $behind)
    Say "      Sync is built against OUR checkout, not its pin, so this combination"
    Say "      is untested upstream. The conformance run below is the check."
    if ($behind -and [int]$behind -gt 0) {
        Say ""
        Say "Commits sync has not seen:"
        & git -C $ashiato log --oneline "$pinned..$after_ashiato" | Select-Object -First 10 |
            ForEach-Object { Say ("  {0}" -f $_) }
    }
}

# ---- rebuild and verify -----------------------------------------------------

Say ""
Say "Rebuilding..."
$buildArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "build.ps1"), "-Clean")
if ($Bare) {
    if ($WithSync) { $buildArgs += "-WithSync" }
} else {
    # ALL THREE GAME MODULES, each of which brings sync and physics with it. This used to
    # be -WithDriving alone, which was the whole feature set when racer was the only game.
    # build.ps1 copies the result into every game whose .gdextension names it, and today
    # that is cockpit, racer and vrplayground-2, so a driving-only build would take
    # CockpitWorld out of the cockpit and VrWorld out of vrplayground-2, silently.
    # bootstrap-windows.ps1 builds the same set, for the same reason.
    $buildArgs += @("-WithDriving", "-WithVr", "-WithCockpit")
}
Say ("  build: {0}" -f $(if ($Bare) { "core only (-Bare)" } else { "driving, vr and cockpit" }))
# THE WHOLE BUILD GOES TO A LOG, and only its tail to the console. The tail alone used to be
# all there was, and six lines is not enough to hold build.ps1's install decisions: a refused
# game prints its reason over several lines, and a refusal cut in half is worse than none.
# stdout only, not 2>&1: in Windows PowerShell a native program's stderr redirected here
# turns into error records, which $ErrorActionPreference = "Stop" makes fatal.
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$buildLog = Join-Path $env:TEMP ("ashiato_gd_update_build_{0}.log" -f $stamp)
& powershell @buildArgs | Tee-Object -FilePath $buildLog | Select-Object -Last 6
Say ("  full build output: {0}" -f $buildLog)
if ($LASTEXITCODE -ne 0) {
    Say ""
    Say "BUILD FAILED against the new revisions. upstream.lock is NOT updated."
    exit 1
}

Say ""
Say "Running conformance and the replication loopbacks..."
$godot = Join-Path $parent "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if (-not (Test-Path $godot)) {
    Say "Godot not found at $godot; skipping conformance (build did succeed)."
    exit 0
}
# THE COCKPIT'S LOOPBACK RUNS ON THE COCKPIT'S ENGINE: the double-precision editor when it is
# here, the stock one when it is not, which is the choice cockpit\tests\run_all.ps1 makes
# for the same suite. That editor loads ashiato_gd.double.dll -- the addon project's
# .gdextension picks a library by precision tag -- and the build above did not touch that
# file. So the double library is rebuilt first, with the same modules. Run against the
# double library left over from some earlier build, a PASS would say nothing about the
# revisions being verified.
$doubleGodot = Join-Path $parent "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
$cockpitGodot = $godot
if (Test-Path $doubleGodot) {
    $doubleArgs = @($buildArgs) + @("-Double")
    Say "  rebuilding ashiato_gd.double.dll for the double editor"
    $doubleLog = Join-Path $env:TEMP ("ashiato_gd_update_build_double_{0}.log" -f $stamp)
    & powershell @doubleArgs | Tee-Object -FilePath $doubleLog | Select-Object -Last 6
    Say ("  full double build output: {0}" -f $doubleLog)
    if ($LASTEXITCODE -ne 0) {
        Say ""
        Say "DOUBLE BUILD FAILED against the new revisions. upstream.lock is NOT updated."
        exit 1
    }
    $cockpitGodot = $doubleGodot
}
# Conformance is the "did upstream break the ECS binding" check. The three loopbacks are
# the "did upstream break REPLICATION" check, one per game module, and they are not the same
# question: the conformance suite runs entirely through AshiatoWorld and would pass with
# prediction, rollback and interpolation all completely broken.
$suite = @(
    @{ test = "conformance";      engine = $godot }
    @{ test = "driving_loopback"; engine = $godot }
    @{ test = "vr_loopback";      engine = $godot }
    @{ test = "cockpit_loopback"; engine = $cockpitGodot }
)
$allPassed = $true
$lines = @()
foreach ($entry in $suite) {
    $test = $entry.test
    Say ("  {0} on {1}" -f $test, (Split-Path -Leaf $entry.engine))
    $log = Join-Path $env:TEMP ("ashiato_{0}_{1}.log" -f $test, [Guid]::NewGuid().ToString("N"))
    & $entry.engine --headless --path (Join-Path $root "addon") "res://tests/$test.tscn" --log-file $log | Out-Null
    $testLines = @(Get-Content $log -ErrorAction SilentlyContinue)
    Remove-Item $log -Force -ErrorAction SilentlyContinue
    $lines += $testLines
    $testLines | Where-Object { $_ -match "FAIL|RESULT=" } | ForEach-Object { Say ("  {0}" -f $_) }
    if (-not ($testLines -match "RESULT=PASS")) {
        $allPassed = $false
        Say ("  {0}: NO PASS" -f $test)
    }
}

if ($allPassed) {
    # Only record revisions that actually passed, so upstream.lock always names a
    # combination known to work rather than merely one that was checked out.
    # ANCHORED to the start of a line, every one of them. Unanchored, 'ashiato\s+= <hex>'
    # also matches the tail of 'sync-pins-ashiato = <hex>' -- the field whose entire job is
    # to differ from the one above it -- so the first replacement quietly overwrote the pin
    # with the ECS revision and the file then claimed there was no gap. -replace changes
    # every occurrence, not the first, so a substring match is not a near miss.
    $content = Get-Content $lock -Raw
    $content = $content -replace '(?m)^ashiato\s+= [0-9a-f]{40}', "ashiato       = $after_ashiato"
    $content = $content -replace '(?m)^ashiato-sync\s+= [0-9a-f]{40}', "ashiato-sync  = $after_sync"
    $content = $content -replace '(?m)^sync-pins-ashiato\s+= [0-9a-f]{40}', "sync-pins-ashiato = $pinned"
    Set-Content $lock $content -Encoding ascii -NoNewline
    Say ""
    Say "PASS. upstream.lock updated."
    exit 0
}

Say ""
Say "CONFORMANCE FAILED. upstream.lock left as it was -- the binding needs a look."
exit 1
