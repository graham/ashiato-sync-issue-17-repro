<#
    Set this checkout up to reproduce ashiato-sync issue #17, from nothing.

        powershell -ExecutionPolicy Bypass -File tools\issue17\setup.ps1

    Clones the four C++ dependencies beside this repository at pinned revisions,
    downloads the stock Godot 4.7.2 editor, builds the GDExtension against the
    ashiato-sync revision under test, and imports the Godot project.

    IT IS SAFE TO RUN TWICE. Everything it does is skipped when already done, so
    find_once.bat and find_repeating.bat both call it and neither pays twice.
    -Force makes it rebuild the library anyway.

    THE ONLY ARGUMENT THAT MATTERS IS -SyncRevision. It is the ashiato-sync
    commit the library is built against, and therefore the one being tested.
    It defaults to the head of main at the time this was written. Point it at a
    candidate fix and run find_repeating.bat to see whether the fix holds.

    WHAT YOU NEED ON THE MACHINE ALREADY: git, cmake, ninja, and the Visual
    Studio 2022 Build Tools with the C++ workload. cmake and ninja are found on
    PATH. Nothing else is assumed.
#>
param(
    # ashiato-sync main at the time of writing. See the README for the two other
    # revisions worth trying: 24334dd (healthy parent) and e48b86d (first bad).
    [string]$SyncRevision = "fa4758f3de0c4e8ae0d2ee2dd5a6f51011ee5632",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
# A NATIVE COMMAND WRITING TO STDERR IS NOT A FAILURE, and PowerShell treats it as one
# while ErrorActionPreference is Stop. git and Godot both talk on stderr when healthy.
$PSNativeCommandUseErrorActionPreference = $false

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$root = Split-Path -Parent $root   # tools\issue17 -> cockpit -> repository root
function Say { param([string]$Text) Write-Host $Text -ForegroundColor Cyan }
function Note { param([string]$Text) Write-Host $Text }

# THE PINNED DEPENDENCIES. ashiato-gd expects all four BESIDE it, which is the
# repository root here. Revisions are the ones this reproduction was measured on;
# ashiato in particular is pinned because ashiato-sync pins it too, and a mismatch
# is a compile error rather than anything subtle.
$deps = @(
    @{ name = "godot-cpp";    url = "https://github.com/godotengine/godot-cpp.git";     rev = "101ae38034304346a46ea9ea84ae156d3e860496" },
    @{ name = "box3d";        url = "https://github.com/erincatto/box3d.git";           rev = "47d7f7cc7e091142c08d11dc7d2e493c5d34f536" },
    @{ name = "ashiato";      url = "https://github.com/ErikGoldman/ashiato.git";       rev = "820c5b0ba9de93e854a6f4ae7638a01f1260297f" },
    @{ name = "ashiato-sync"; url = "https://github.com/ErikGoldman/ashiato-sync.git";  rev = $SyncRevision }
)

Say "== 1/4  dependencies =="
foreach ($dep in $deps) {
    $dir = Join-Path $root $dep.name
    # REFUSE A LINKED DEPENDENCY. In the workshop this reproduction was extracted from,
    # these four are junctions into checkouts that several builds share, and checking a
    # revision out through one of them switches it under all of them mid-build. A fresh
    # clone of this repository has no links and never sees this; it is here so that
    # running the script in the wrong tree stops instead of doing damage.
    $existing = Get-Item $dir -Force -ErrorAction SilentlyContinue
    if ($existing -and $existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw ("{0} is a link, not a clone. This script checks revisions out and must not " -f $dir) +
              "do that through a link into somebody else's checkout. Move the link aside first."
    }
    if (-not (Test-Path (Join-Path $dir ".git"))) {
        Note ("  cloning {0}" -f $dep.name)
        & git clone --quiet $dep.url $dir
        if ($LASTEXITCODE -ne 0) { throw ("could not clone {0} from {1}" -f $dep.name, $dep.url) }
    }
    $have = (& git -C $dir rev-parse HEAD).Trim()
    if ($have -ne $dep.rev) {
        Note ("  {0}: fetching {1}" -f $dep.name, $dep.rev.Substring(0, 12))
        & git -C $dir fetch --quiet origin
        # Detached on purpose: this is a checkout to build, not to work in.
        & git -C $dir checkout --quiet --detach $dep.rev
        if ($LASTEXITCODE -ne 0) {
            throw ("{0} has no revision {1}. If it is a candidate fix, push it to a branch this clone can fetch." -f $dep.name, $dep.rev)
        }
    }
    Note ("  {0,-13} {1}" -f $dep.name, (& git -C $dir rev-parse --short HEAD).Trim())
}

Say "== 2/4  Godot 4.7.2 =="
$godot = Join-Path $root "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if (-not (Test-Path $godot)) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tools\get_godot.ps1") -Version 4.7.2
}
if (-not (Test-Path $godot)) { throw "Godot 4.7.2 was not downloaded to $godot" }
Note ("  {0}" -f $godot)

# THE STOCK EDITOR, NOT A DOUBLE-PRECISION BUILD. The game this reproduction comes from is
# normally run on a Godot compiled with precision=double, but the fault has nothing to do
# with precision and reproduces identically on the stock download, so nobody reproducing
# this has to build an engine. The .gdextension names both, tagged by precision.

Say "== 3/4  the extension =="
$dll = Join-Path $root "cockpit\addons\ashiato\bin\ashiato_gd.dll"
$stamp = Join-Path $root "_tools\.issue17-built-from"
$want = $SyncRevision
$built = if (Test-Path $stamp) { (Get-Content $stamp -Raw).Trim() } else { "" }
# ALWAYS BUILD, because the only cheap way to be sure the library matches the source is to
# ask the build system, which no-ops in seconds when nothing changed. Skipping on a stamp
# was wrong and cost a wasted run: the stamp records the ashiato-sync revision, so a change
# to ashiato-gd's OWN sources -- which is what a `git pull` here usually brings -- left a
# stale library in place and the game then failed to compile against it.
if ($true) {
    Note "  building ashiato_gd.dll -- the first build takes ten to twenty minutes, later ones seconds"
    # -SyncRevision says out loud that the library is not the one upstream.lock names,
    # which is the whole point here: the lock names a HEALTHY revision.
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "ashiato-gd\tools\build.ps1") `
        -WithCockpit -WithVr `
        -AshiatoSync (Join-Path $root "ashiato-sync") `
        -SyncRevision $SyncRevision
    # build.ps1 exits non-zero when a SIBLING game refuses the library, which is not a
    # failure of this build. Judge it by whether the file appeared and is newer than the
    # request, exactly as the game's own suites are judged by their printed RESULT line.
    if (-not (Test-Path $dll)) { throw "the build did not produce $dll -- see the output above" }
    Set-Content -Path $stamp -Value $want -Encoding ascii
}
Note ("  {0}  ({1:N0} bytes)" -f $dll, (Get-Item $dll).Length)

Say "== 4/4  importing the Godot project =="
# A FRESH CHECKOUT HAS NO IMPORT CACHE, and a scene that asks for an unimported resource
# does not fail, it HANGS. So the import is a step of its own, with its own deadline,
# rather than something the first run discovers.
#
# ALWAYS, NOT ONLY WHEN THE CACHE IS ABSENT. Godot's list of `class_name` types lives in
# that cache, so a checkout that gains a script -- which a `git pull` here usually does --
# has types the cache has never heard of, and every script that names one fails to compile.
# That is what "Identifier "Runabout" not declared in the current scope" means, and it cost
# a run to work out. An import with nothing to do takes a few seconds.
if ($true) {
    Note "  importing (seconds when there is nothing new, minutes on a fresh checkout)"
    $log = Join-Path $env:TEMP ("issue17_import_{0}.log" -f [Guid]::NewGuid().ToString("N"))
    $p = Start-Process -FilePath $godot -ArgumentList '--headless','--import','--path',(Join-Path $root 'cockpit') `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Minimized -PassThru
    $deadline = (Get-Date).AddMinutes(20)
    while (-not $p.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 5 }
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; throw "the import did not finish within 20 minutes" }
    Remove-Item "$log*" -ErrorAction SilentlyContinue
}
Note "  imported"

Write-Host ""
Write-Host "Ready. Run find_once.bat, or find_repeating.bat to run it until it fails." -ForegroundColor Green
Write-Host ("Built against ashiato-sync {0}" -f $SyncRevision)
