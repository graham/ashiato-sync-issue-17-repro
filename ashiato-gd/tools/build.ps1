<#
Builds the ashiato GDExtension into addon/addons/ashiato/bin/.

    powershell -File tools\build.ps1
    powershell -File tools\build.ps1 -WithSync
    powershell -File tools\build.ps1 -Clean

THIS BUILDS; IT DOES NOT FETCH. It assumes the four upstream checkouts are already
beside ashiato-gd, at the revisions upstream.lock names, with the patches in
tools\patches applied. From a fresh clone none of that is true yet, and
tools\bootstrap-windows.ps1 is what makes it true -- it ends by calling this.

Exists because three things have to be found before CMake can run, and none of them
are reliably on PATH:

1. MSVC. cl.exe is only usable inside a vcvars64 environment, so the whole build runs
   through a generated .bat that calls it first. vswhere needs `-products *` or it
   returns NOTHING for a BuildTools-only install (no Visual Studio IDE).
2. cmake and ninja, which winget installs into per-user WinGet\Packages paths that
   the current shell does not pick up until it restarts.
3. The upstream checkouts, whose revision is stamped into the binary so a running
   game can report which ashiato it was built against.
#>

[CmdletBinding()]
param(
    [switch]$WithSync,
    [switch]$WithPhysics,
    [switch]$WithDriving,
    [switch]$WithVr,
    [switch]$WithCockpit,
    [switch]$Clean,
    # BUILD AGAINST A DOUBLE-PRECISION GODOT, which is a different binary and not a
    # setting: the method hashes of anything taking a real_t differ between the two, so a
    # library bound against the wrong extension_api.json loads and then calls the wrong
    # functions. The API file has to be dumped from the very editor it will run in:
    #
    #   godot.windows.editor.x86_64.double.exe --headless --dump-extension-api
    #
    # The result is installed as ashiato_gd.double.dll ALONGSIDE the single-precision one,
    # and the feature tags in a project's .gdextension decide which an editor loads -- so
    # a project still on the stock Godot is untouched by a double build.
    [switch]$Double,
    [string]$GodotApi = "",
    [string]$BuildType = "Release",
    # Where the object tree goes. Defaults to a per-checkout directory on the local disk;
    # see the comment beside $buildDir for why it is both of those things.
    [string]$BuildDir = "",
    # Where the dependencies live, if not beside ashiato-gd. Only needed when the tree is
    # laid out differently from the one this was developed in.
    [string]$GodotCpp = "",
    [string]$Ashiato = "",
    [string]$AshiatoSync = "",
    [string]$Box3d = "",
    # THE PACKET LIFECYCLE TRACE, for reporting a sync fault upstream. Turns on
    # ASHIATO_SYNC_TRACE_PACKET_LOGS and turns component data off, which is the pair
    # ashiato-sync issue #17 asks for. See the option in CMakeLists.txt.
    [switch]$TracePacketLogs,
    # BUILD AGAINST AN ASHIATO-SYNC REVISION upstream.lock DOES NOT NAME, on purpose.
    #
    # The lock check below is what stops a library built from a stray checkout reaching
    # the other games, and it stays. This is the one sanctioned way past it: you say which
    # revision you meant, in full, and the build says loudly that what it produced is not
    # the locked library. It exists because running a maintainer's instrumented branch is
    # a real errand, and the alternative -- editing upstream.lock -- leaves a lie on disk
    # that outlives the errand and can be committed by accident.
    [string]$SyncRevision = ""
)

$ErrorActionPreference = "Stop"
# A NATIVE COMMAND WRITING TO STDERR IS NOT A FAILURE, and PowerShell 7 treats it as
# one while ErrorActionPreference is Stop. The patch check below asks git QUESTIONS
# whose "no" is an answer -- the same reason bootstrap-windows.ps1 turns this off.
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}
$root = Split-Path -Parent $PSScriptRoot

function Say { param([string]$Text) Write-Host $Text }

function Find-Tool {
    param([string]$Name, [string]$Glob)
    $onPath = Get-Command $Name -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    # winget's per-user package root, which a shell started before the install misses.
    $found = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter $Glob `
        -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.FullName }
    throw "$Name not found. winget install it, or put it on PATH."
}

# -products * matters: without it vswhere ignores a BuildTools-only install.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { throw "vswhere not found; install Visual Studio Build Tools." }
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
if (-not $vs) { throw "No MSVC C++ toolset found. Install the 'Desktop development with C++' workload." }
$vcvars = Join-Path $vs "VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path $vcvars)) { throw "vcvars64.bat missing under '$vs'." }

$cmake = Find-Tool -Name "cmake" -Glob "cmake.exe"
$ninja = Find-Tool -Name "ninja" -Glob "ninja.exe"

Say ("MSVC:  {0}" -f $vs)
Say ("cmake: {0}" -f $cmake)
Say ("ninja: {0}" -f $ninja)

# The build tree lives on the LOCAL disk, not next to the source.
#
# This repo is on an SMB share, and CMake's FetchContent writes a swarm of small temp
# files ("Labels.txt.tmpdce14") into _deps subbuild directories. The share drops those
# writes and the configure step dies with "Cannot open file for write / No such file or
# directory". Only the finished .dll is written back across, by the output-directory in
# CMakeLists.txt.
#
# AND IT IS PER CHECKOUT, which it was not: the name was a bare "ashiato-gd-build", one
# per user, and CMakeCache.txt stores the ABSOLUTE source path it was generated from. So a
# second clone of this repository could not build at all. It got as far as configure and
# stopped:
#
#   CMake Error: The source "Z:/godotgames-clean/ashiato-gd/CMakeLists.txt" does not
#   match the source "Z:/godotgames/ashiato-gd/CMakeLists.txt" used to generate cache.
#
# which names both paths and still does not say that the cache belongs to somebody else's
# working tree. Two checkouts cannot share one build tree even in principle -- that is what
# the cache check is for -- so the path carries a digest of the source directory and they
# get one each. The cost is one full rebuild the first time this lands, because the old
# shared tree no longer matches any name.
#
# $env:ASHIATO_GD_BUILD_DIR overrides, which is what bootstrap-linux.sh has always offered.
if ($BuildDir -eq "" -and $env:ASHIATO_GD_BUILD_DIR) { $BuildDir = $env:ASHIATO_GD_BUILD_DIR }
if ($BuildDir -eq "") {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $key = ([BitConverter]::ToString(
            $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($root.ToLowerInvariant()))
        ) -replace '-', '').Substring(0, 8).ToLowerInvariant()
    } finally { $sha.Dispose() }
    $BuildDir = Join-Path $env:LOCALAPPDATA "ashiato-gd-build-$key"
}
# A SEPARATE BUILD DIRECTORY for double, because the two differ in every object file and
# sharing one would relink whichever was built last over the other on every switch. It is
# chosen HERE, before -Clean, because until 2026-09-15 the suffix was added after the clean:
# `-Clean -Double` emptied the single directory and compiled the double incrementally in 10 s.
$buildDir = if ($Double) { "$BuildDir-double" } else { $BuildDir }
Say ("build: {0}" -f $buildDir)
if ($Clean -and (Test-Path $buildDir)) {
    Remove-Item $buildDir -Recurse -Force
    Say "Cleaned build directory."
}

# Stamp the revision actually being compiled, so upstream_revision() is not a guess.
$ashiatoDir = Join-Path (Split-Path -Parent $root) "ashiato"
$rev = "unknown"
if (Test-Path (Join-Path $ashiatoDir ".git")) {
    $rev = (& git -C $ashiatoDir rev-parse --short HEAD).Trim()
}
Say ("ashiato revision: {0}" -f $rev)

# EVERY PATCH UPSTREAM NEEDS, CHECKED BEFORE A SINGLE OBJECT IS COMPILED.
#
# The bootstrap scripts APPLY these. Nothing checked they were still applied by the time
# somebody ran this, and this is the documented way to rebuild -- so it would compile
# against an unpatched checkout and hand back a library that loads, runs, and is quietly
# wrong. No build error, no load error, no crash; the game just misbehaves.
#
# Not hypothetical. The Windows checkout was missing
# ashiato-sync-baseline-on-mask-open.patch, which is what lets a client that boards an
# aircraft go on receiving that vehicle's Seats. Without it eleven checks in
# cockpit_loopback fail and a crew in one aeroplane cannot see each other. Linux had the
# patch and Windows did not, and the two platforms disagreed for as long as nobody rebuilt
# on Windows -- which was a fortnight, because the DLL is committed and nobody had to.
#
# A HARD ERROR, as the bootstraps make it. See the header of any patch for why the thing it
# fixes is not optional.
#
# MATCHED BY LONGEST PREFIX, not by globbing "$name-*". `ashiato-sync` starts with
# `ashiato`, so the obvious glob hands ashiato-sync's patches to the ashiato checkout and
# reports every one of them as missing from a repo they were never meant for.
$repos = [ordered]@{}
$beside = Split-Path -Parent $root
$repos["ashiato-sync"] = $AshiatoSync
if (-not $repos["ashiato-sync"]) { $repos["ashiato-sync"] = Join-Path $beside "ashiato-sync" }
$repos["ashiato"] = $Ashiato
if (-not $repos["ashiato"]) { $repos["ashiato"] = $ashiatoDir }
$repos["box3d"] = $Box3d
if (-not $repos["box3d"]) { $repos["box3d"] = Join-Path $beside "box3d" }

# --reverse --check succeeds only where the patch is ALREADY in the tree, which is the same
# test the bootstraps use to decide there is nothing to do.
#
# WRAPPED, because this is a QUESTION and git answers "no" the only way it can: a message on
# stderr and a non-zero exit. Windows PowerShell turns a redirected native stderr into a
# terminating NativeCommandError, so `2>$null` under ErrorActionPreference Stop kills the
# script on precisely the case this check exists to catch -- and the operator sees a stack
# trace about git.exe rather than the sentence below telling them what to do.
function Test-PatchApplied {
    param([string]$Dir, [string]$File)
    $prior = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git -C $Dir apply --reverse --check $File *>$null
        return ($LASTEXITCODE -eq 0)
    } finally {
        $ErrorActionPreference = $prior
    }
}

Say "patches:"
$patchDir = Join-Path $PSScriptRoot "patches"
$found = @(Get-ChildItem $patchDir -Filter "*.patch" -ErrorAction SilentlyContinue |
    Sort-Object Name)
if ($found.Count -eq 0) { Say "  none" }
foreach ($patch in $found) {
    # Longest name first, so ashiato-sync wins over ashiato for its own patches.
    $owner = $null
    foreach ($name in ($repos.Keys | Sort-Object -Property Length -Descending)) {
        if ($patch.Name.StartsWith("$name-")) { $owner = $name; break }
    }
    if (-not $owner) {
        throw ("{0} names no known checkout. Patches are <repo>-<what>.patch, for one of: {1}." `
            -f $patch.Name, ($repos.Keys -join ", "))
    }
    $dir = $repos[$owner]
    if (-not (Test-Path (Join-Path $dir ".git"))) {
        Say ("  {0}: cannot verify -- {1} at {2} is not a git checkout" -f $patch.Name, $owner, $dir)
        continue
    }
    if (Test-PatchApplied -Dir $dir -File $patch.FullName) {
        Say ("  {0}: applied" -f $patch.Name)
        continue
    }
    $at = (& git -C $dir rev-parse --short HEAD).Trim()
    throw ("{0} is NOT applied to {1} at {2}." -f $patch.Name, $owner, $at) + "`n" +
          "  A library built without it loads and is silently wrong; see the patch header." + "`n" +
          ("  Apply it:  git -C '{0}' apply '{1}'" -f $dir, $patch.FullName) + "`n" +
          "  Or re-run tools\bootstrap-windows.ps1, which applies every patch."
}

# AND ASHIATO-SYNC AT THE REVISION upstream.lock NAMES, WITH NOTHING EDITED IN IT.
#
# The patch check above was the guard until 2026-09-18, when upstream took all three of our
# ashiato-sync fixes (8fa08cf) and tools\patches went empty. An empty folder guards nothing, so
# this does the job instead: a checkout at another revision, or one still carrying the old
# patches as uncommitted edits, is refused before a single object is compiled. The shared
# checkout beside the main repo was dirty ON PURPOSE for two days; this is what says it must
# not be any more. A checkout that is not git (a tarball) is reported and not checked.
$lockFile = Join-Path $root "upstream.lock"
$syncDir = $repos["ashiato-sync"]
$syncWant = ""
foreach ($line in (Get-Content $lockFile)) {
    if ($line -match '^\s*ashiato-sync\s*=\s*([0-9a-f]{40})') { $syncWant = $Matches[1] }
}
if ($syncWant -eq "") { throw "upstream.lock names no ashiato-sync revision" }
if ($SyncRevision -ne "") {
    if ($SyncRevision -notmatch '^[0-9a-f]{40}$') {
        throw "-SyncRevision wants the full 40-character revision, so the build says exactly what it built."
    }
    Write-Host ("  !!  NOT THE LOCKED LIBRARY: -SyncRevision {0} was given, so this build is against that" -f $SyncRevision.Substring(0, 12)) -ForegroundColor Yellow
    Write-Host ("      instead of upstream.lock's {0}. It is for measuring, not for merging." -f $syncWant.Substring(0, 12)) -ForegroundColor Yellow
    $syncWant = $SyncRevision
}
if (Test-Path (Join-Path $syncDir ".git")) {
    $syncHave = (& git -C $syncDir rev-parse HEAD).Trim()
    if ($syncHave -ne $syncWant) {
        throw ("ashiato-sync at {0} is {1}, but upstream.lock wants {2}." -f $syncDir, $syncHave.Substring(0, 12),
            $syncWant.Substring(0, 12)) + "`n" +
            "  Check it out at the locked revision, or re-run tools\bootstrap-windows.ps1."
    }
    $syncEdits = @(& git -C $syncDir status --porcelain --untracked-files=no)
    if ($syncEdits.Count -ne 0) {
        throw ("ashiato-sync at {0} has uncommitted edits to {1} file(s), for example {2}." -f $syncDir,
            $syncEdits.Count, $syncEdits[0].Trim()) + "`n" +
            "  A library built from it is not the one upstream.lock names. If they are the old patches," + "`n" +
            ("  undo them with git -C '{0}' apply --reverse <patch> (they are in git history)." -f $syncDir)
    }
    Say ("ashiato-sync: {0}, clean, as upstream.lock names" -f $syncHave.Substring(0, 12))
} else {
    Say ("ashiato-sync: cannot verify -- {0} is not a git checkout" -f $syncDir)
}

$syncFlag = "OFF"
if ($WithSync) { $syncFlag = "ON" }
$packetLogFlag = "OFF"
if ($TracePacketLogs) { $packetLogFlag = "ON" }
$physicsFlag = "OFF"
if ($WithPhysics) { $physicsFlag = "ON" }
$drivingFlag = "OFF"
if ($WithDriving) { $drivingFlag = "ON" }
$vrFlag = "OFF"
if ($WithVr) { $vrFlag = "ON" }
$cockpitFlag = "OFF"
if ($WithCockpit) { $cockpitFlag = "ON" }

# Only passed when given: left alone, CMake finds the dependencies beside ashiato-gd,
# which is where they belong and where a fresh clone will put them.
$pathArgs = ""
foreach ($pair in @(@("GODOT_CPP_DIR", $GodotCpp), @("ASHIATO_DIR", $Ashiato),
                    @("ASHIATO_SYNC_DIR", $AshiatoSync), @("BOX3D_DIR", $Box3d))) {
    if ($pair[1]) { $pathArgs += " ^`n  -D$($pair[0])=`"$($pair[1])`"" }
}

# The double build's own directory was chosen beside -Clean above.
$doubleArgs = ""
if ($Double) {
    if (-not $GodotApi) {
        $GodotApi = Join-Path $root "..\_tools\godot-4.7.2-double\extension_api.json"
    }
    if (-not (Test-Path $GodotApi)) {
        throw ("Double builds need the API dumped from the double editor. Not found at " +
               "$GodotApi. Run: godot.windows.editor.x86_64.double.exe --headless " +
               "--dump-extension-api")
    }
    $doubleArgs = " ^`n  -DASHIATO_GD_DOUBLE=ON"
}

# THE API FILE IS NOT ONLY A DOUBLE-PRECISION CONCERN, which is what this used to assume.
#
# godot-cpp has no branch for 4.7 -- the newest is 4.5 -- so a build left to godot-cpp's
# own API binds against 4.5 while the editor is 4.7, and the extension then loads and
# calls the wrong methods. CMakeLists.txt asks for GODOTCPP_API_VERSION 4.7, which 4.5's
# checkout cannot satisfy on its own. So the SINGLE-precision build wants a custom API
# file for the same reason the double one does, and gets it from the tracked dump beside
# the stock editor.
#
# Tracked, not fetched: see .gitignore. The editors are 140 MB and re-downloaded in a
# minute, but the API file they were dumped from is the thing that must not silently drift.
if (-not $GodotApi) {
    $stockApi = Join-Path $root "..\_tools\godot-4.7.2\extension_api.json"
    if (Test-Path $stockApi) { $GodotApi = $stockApi }
}
$apiArgs = ""
if ($GodotApi) {
    Say ("api:   {0}" -f $GodotApi)
    $apiArgs = " ^`n  -DGODOTCPP_CUSTOM_API_FILE=`"$GodotApi`""
}

$bat = Join-Path $env:TEMP ("ashiato_gd_build_{0}.bat" -f [Guid]::NewGuid().ToString("N"))
@"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b 1
"$cmake" -S "$root" -B "$buildDir" -G Ninja ^
  -DCMAKE_BUILD_TYPE=$BuildType ^
  -DCMAKE_MAKE_PROGRAM="$ninja" ^
  -DASHIATO_GD_WITH_SYNC=$syncFlag ^
  -DASHIATO_GD_WITH_PHYSICS=$physicsFlag ^
  -DASHIATO_GD_WITH_DRIVING=$drivingFlag ^
  -DASHIATO_GD_WITH_VR=$vrFlag ^
  -DASHIATO_GD_WITH_COCKPIT=$cockpitFlag ^
  -DASHIATO_GD_TRACE_PACKET_LOGS=$packetLogFlag ^
  -DASHIATO_GD_UPSTREAM_REV="$rev"$doubleArgs$apiArgs$pathArgs
if errorlevel 1 exit /b 1
"$cmake" --build "$buildDir" --target ashiato_gd
exit /b %errorlevel%
"@ | Set-Content $bat -Encoding ascii

## WHEN THE BUILD STARTED, so the report below can tell a file this build wrote from one it did not.
$buildStarted = Get-Date

## vcvars64.bat CALLS vswhere FROM PATH, whatever we resolved above. A shell that has never run the VS
## installer's own environment does not have it, and the build dies inside the bat with
## "'vswhere.exe' is not recognized" -- which names neither this script nor the toolchain. Two lanes hit
## it on 2026-09-20. We already know the folder: put it on PATH for the child.
$vsInstaller = Split-Path -Parent $vswhere
if ($env:PATH -notlike "*$vsInstaller*") { $env:PATH = "$vsInstaller;$env:PATH" }

try {
    & cmd /c $bat
    $code = $LASTEXITCODE
} finally {
    Remove-Item $bat -Force -ErrorAction SilentlyContinue
}

if ($code -ne 0) {
    Say "FAILED."
    exit $code
}

Say ""
$bin = Join-Path $root "addon\addons\ashiato\bin"

# REFUSE A LIBRARY THAT IMPORTS THE VC RUNTIME, and refuse it on the OUTPUT rather than on
# the input that produced it.
#
# On 2026-09-20 two lanes independently built against C:\gg-deps\godot-cpp instead of
# Z:\tanagra\godot-cpp. Those are divergent trees, not one behind the other: Z: carries a
# math_funcs_binary.hpp that gg-deps does not have at all, so a different sin and cos go
# into the binary. The double library went 3,536,384 bytes -> 2,823,680 and picked up
# MSVCP140, VCRUNTIME140 and api-ms-win-crt where a correct build imports one DLL. One of
# those builds reached main, and vehicle_gym -- the only suite that compares against
# recorded numbers -- showed craft nobody had touched flying different trajectories.
#
# CHECKING THE INPUT WOULD NOT HAVE CAUGHT IT. learnings/2026-09-19-flightmodel.md blames
# GODOTCPP_USE_STATIC_CPP=OFF, and that is true of cmake/linux.cmake only: on Windows,
# cmake/windows.cmake has it ON in BOTH checkouts. A guard reading the CMake option would
# have passed the bad tree. The import table is the measurement; the flag is a proxy that
# is wrong on this machine.
$dynamicCrt = @("MSVCP140", "VCRUNTIME140", "api-ms-win-crt")
foreach ($lib in @(Get-ChildItem $bin -File -Filter *.dll -ErrorAction SilentlyContinue)) {
    $ascii = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($lib.FullName))
    $found = @($dynamicCrt | Where-Object { $ascii -match $_ })
    if ($found.Count -gt 0) {
        Write-Host ("  !!  REFUSED {0}: it imports {1}, so it was linked against a godot-cpp that does not static-link the C++ runtime." -f $lib.Name, ($found -join ", ")) -ForegroundColor Red
        Write-Host ("      Built with -GodotCpp '{0}'. This machine's correct tree is Z:\tanagra\godot-cpp." -f $GodotCpp) -ForegroundColor Red
        Write-Host  "      A library built this way loads, runs, and flies every aeroplane on different maths." -ForegroundColor Red
        throw "refusing to install a library that imports the VC runtime"
    }
}

## SAY WHICH FILES THIS BUILD ACTUALLY WROTE, because the old report was a lie by omission and it
## voided a lane's gate (lane/rivers, 2026-09-20).
##
## Without -Double this builds only the stock library -- and the report listed EVERY file in bin/, so
## it printed "ok ashiato_gd.double.dll (3,548,160 bytes)" about a file it had not touched, carrying its
## old timestamp and none of the change. The lane then ran five suites on the DOUBLE editor, including
## ground_field, and all five PASSED -- trivially, because the old library did not have the new key in
## it. It was caught only by noticing the double DLL's mtime was the lane's provisioning time.
##
## A build that reports success for work it did not do is the same fault as a check that cannot fail,
## and the fix is the same: say what actually happened. A file older than this build now reads NOT BUILT.
foreach ($f in @(Get-ChildItem $bin -File -ErrorAction SilentlyContinue)) {
    if ($f.LastWriteTime -ge $buildStarted) {
        Say ("  ok         {0}  ({1:N0} bytes)" -f $f.Name, $f.Length)
    } else {
        Write-Host ("  NOT BUILT  {0}  ({1:N0} bytes, from {2}) -- this run did not touch it; rerun with -Double if you need it" `
            -f $f.Name, $f.Length, $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor Yellow
    }
}
# Push the fresh binary into every sibling game that already has the addon installed.
#
# Without this a game keeps whatever DLL was copied in by hand, and there is no sign of
# it: the extension loads, the classes exist, and only the methods whose signatures moved
# misbehave. A Dictionary argument arriving at a two-float binding crashes inside
# argument marshalling with "Index 4294967295 is out of bounds", which names neither the
# method nor the project. Only EXISTING installs are updated -- this copies the addon
# forward, it does not decide which projects should have one.
#
# AND ONLY WHERE THE GAME'S .gdextension NAMES THE FILE, which bootstrap-linux.sh has done
# since cd97e0b and this did not. A -Double build used to land in racer and vrplayground-2
# too: stock single-precision games whose .gdextension has no double entry and whose
# precompiled godotsteam could not load in a double editor anyway. The dead 2.6 MB copy was
# committed beside cockpit work at least three times (c435524, ab6e0f2, 075fe08) before it
# was removed. The match includes the closing quote, so ashiato_gd.dll does not match
# ashiato_gd.double.dll.
#
# AND ONLY IF THE NEW LIBRARY STILL HAS EVERY CLASS THAT GAME USES. A build with fewer
# modules than a game needs used to go in anyway: `build.ps1` with no flags is the ECS
# alone, and copied into the cockpit it removes CockpitWorld, which shows up as "the
# extension is not loaded" at the first script that reaches for it. None of the three
# lists below is typed out, so none can go stale:
#
#   * THE CANDIDATES are the classes src\ registers, read from its GDREGISTER_CLASS lines.
#   * WHAT THE BUILD PROVIDES is read from the library itself, as the C++ type names the
#     compiler writes for every class it compiled: ".?AV<Class>@ashiato_gd@@" from MSVC,
#     "N10ashiato_gd<length><Class>E" from GCC. src\register_types.cpp registers each
#     module under the same ASHIATO_GD_WITH_* flag that compiles it, so a class whose type
#     name is present was also registered. Measured 2026-09-12: the full .dll carries exactly
#     the six names src\ registers.
#   * WHAT A GAME USES is every candidate named in its .gd, .tscn, .tres and .gdextension
#     files, outside .godot\ and the addon itself, with GDScript comments stripped so a
#     sentence about another game's class does not count.
#
# A game that uses a class the build lacks is REFUSED: nothing is copied, its current
# library stays, and the missing classes are named. The script then exits 1.
function Get-AshiatoClassNames {
    param([string]$SourceDir)
    $names = New-Object System.Collections.Generic.SortedSet[string]
    foreach ($file in @(Get-ChildItem $SourceDir -Recurse -File -Include *.cpp, *.h, *.hpp -ErrorAction SilentlyContinue)) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if (-not $text) { continue }
        foreach ($m in [regex]::Matches($text, 'GDREGISTER_(?:RUNTIME_|ABSTRACT_|VIRTUAL_|INTERNAL_)?CLASS\(\s*(?:[A-Za-z_]\w*::)*([A-Za-z_]\w*)\s*\)')) {
            [void]$names.Add($m.Groups[1].Value)
        }
    }
    return @($names)
}

function Get-ClassesInLibrary {
    param([string]$Library, [string[]]$Candidates)
    # Latin-1 maps every byte to one char, so the binary can be searched as text.
    $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($Library))
    return @($Candidates | Where-Object {
        $text.Contains(".?AV$_@ashiato_gd@@") -or $text.Contains(("N10ashiato_gd{0}{1}E" -f $_.Length, $_))
    })
}

function Remove-GdScriptComments {
    param([string]$Text)
    # Everything from a # that is not inside a quoted string to the end of its line.
    return [regex]::Replace($Text,
        '(?m)^((?:[^#"''\r\n]|"(?:[^"\\\r\n]|\\.)*"|''(?:[^''\\\r\n]|\\.)*'')*)#[^\r\n]*', '$1')
}

function Get-ClassesUsedByGame {
    param([string]$GameDir, [string[]]$Candidates)
    $used = [ordered]@{}
    $files = @(Get-ChildItem $GameDir -Recurse -File -Include *.gd, *.tscn, *.tres, *.gdextension -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](\.godot|addons[\\/]ashiato)[\\/]' })
    foreach ($file in $files) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if (-not $text) { continue }
        if ($file.Extension -eq '.gd') { $text = Remove-GdScriptComments $text }
        foreach ($name in $Candidates) {
            if ($used.Contains($name)) { continue }
            if ($text -match ('(?<![A-Za-z0-9_])' + [regex]::Escape($name) + '(?![A-Za-z0-9_])')) {
                $used[$name] = $file.FullName.Substring($GameDir.Length).TrimStart('\', '/')
            }
        }
    }
    return $used
}

function Install-IntoSiblingGames {
    param([string]$From, [string]$Name, [string]$GamesDir, [string]$SourceDir)
    $library = Join-Path $From $Name
    $candidates = @(Get-AshiatoClassNames -SourceDir $SourceDir)
    $provided = @()
    if ($candidates.Count -gt 0) { $provided = @(Get-ClassesInLibrary -Library $library -Candidates $candidates) }
    Say ("  {0} has: {1}" -f $Name, $(if ($provided.Count) { $provided -join ", " } else { "no ashiato classes" }))
    $refused = 0
    foreach ($game in @(Get-ChildItem $GamesDir -Directory -ErrorAction SilentlyContinue)) {
        $install = Join-Path $game.FullName 'addons/ashiato/bin'
        if (-not (Test-Path $install)) { continue }
        $manifests = @(Get-ChildItem (Split-Path -Parent $install) -Filter *.gdextension -File -ErrorAction SilentlyContinue)
        $named = @($manifests | Where-Object {
            Select-String -LiteralPath $_.FullName -SimpleMatch -Pattern ('bin/{0}"' -f $Name) -Quiet
        })
        if ($named.Count -eq 0) {
            Say ("  --  {0}: its .gdextension names no {1}" -f $install, $Name)
            continue
        }
        if ($candidates.Count -eq 0) {
            Write-Host ("  !!  REFUSED {0}: no GDREGISTER_CLASS found under {1}, so there is no way to tell what this build lacks. Its library is left as it was." -f $install, $SourceDir) -ForegroundColor Red
            $refused++
            continue
        }
        $used = Get-ClassesUsedByGame -GameDir $game.FullName -Candidates $candidates
        $missing = @($used.Keys | Where-Object { $provided -notcontains $_ } | Sort-Object)
        if ($missing.Count -gt 0) {
            Write-Host ("  !!  REFUSED {0}: this build has no {1}." -f $install, ($missing -join ", ")) -ForegroundColor Red
            foreach ($class in $missing) {
                Write-Host ("        {0} uses {1} (first in {2})" -f $game.Name, $class, $used[$class]) -ForegroundColor Red
            }
            Write-Host "        Nothing copied; its library is left as it was. Build with -WithDriving -WithVr -WithCockpit." -ForegroundColor Red
            $refused++
            continue
        }
        try {
            Copy-Item (Join-Path $From $Name) $install -Force -ErrorAction Stop
            Say ("  ->  {0}" -f $install)
        } catch {
            # A running GAME (or exported build) loads this file directly and holds it
            # open, so the copy fails. The EDITOR does not block it: it loads a `~`-prefixed
            # copy of the library instead, so the copy succeeds under an open editor, which
            # keeps running the old code until it restarts. Measured 2026-09-12; see
            # working_with_godot.md, "Writing a GDExtension".
            #
            # AND THAT IS A FAILED BUILD, which it was not: this line was printed, then "Build
            # complete.", then exit 0. On 2026-09-13 a -Double build under another session's
            # run left cockpit on the previous library and every suite after it ran green on
            # the old code. Measured the same day with racer's DLL held open by
            # [IO.File]::Open(..., 'None'): the !! line, "Build complete.", EXIT=0.
            Say ("  !!  could not update {0} (is Godot running?)" -f $install)
            $script:FailedCopies++
        }
    }
    # A script variable rather than a return value: anything the function writes to the
    # output stream would be returned with it.
    $script:RefusedInstalls = $refused
}
$built = if ($Double) { "ashiato_gd.double.dll" } else { "ashiato_gd.dll" }
$script:RefusedInstalls = 0
$script:FailedCopies = 0
Install-IntoSiblingGames -From $bin -Name $built -GamesDir (Join-Path $root "..") -SourceDir (Join-Path $root "src")

if ($script:RefusedInstalls -gt 0) {
    Write-Host ("Build complete, but {0} game(s) REFUSED it: see above. Their libraries were not touched." -f $script:RefusedInstalls) -ForegroundColor Red
}
if ($script:FailedCopies -gt 0) {
    Write-Host ("Built, but {0} game(s) could NOT be updated: see the !! lines above. They still hold the PREVIOUS library; close whatever has it open and build again." -f $script:FailedCopies) -ForegroundColor Red
}
if ($script:RefusedInstalls -gt 0 -or $script:FailedCopies -gt 0) {
    exit 1
}
Say "Build complete."
exit 0
