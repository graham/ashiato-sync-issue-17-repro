<#
Everything needed to build and test the cockpit game on Windows, from a fresh clone.

    powershell -ExecutionPolicy Bypass -File ashiato-gd\tools\bootstrap-windows.ps1
    powershell -ExecutionPolicy Bypass -File ashiato-gd\tools\bootstrap-windows.ps1 -Clean
    powershell -ExecutionPolicy Bypass -File ashiato-gd\tools\bootstrap-windows.ps1 -FetchOnly
    powershell -ExecutionPolicy Bypass -File ashiato-gd\tools\bootstrap-windows.ps1 -BuildOnly

The Windows counterpart of bootstrap-linux.sh, and the half that build.ps1 is not.

build.ps1 BUILDS. It assumes the four upstream checkouts are already beside ashiato-gd,
that a Godot is already under _tools, and that the patches upstream needs have already
been applied -- because on the machine it was written for, all three were true. On a
fresh clone none of them are, and working out WHICH four repositories at WHICH four
revisions is most of the work. So this does that part, then hands over to build.ps1
rather than owning a second copy of the MSVC and CMake plumbing.

WHAT IT IS NOT: a double-precision build. The game ships against a Godot compiled with
`precision=double` -- see cockpit/agents.md -- and that binary is not something you can
download. This builds against the stock 4.7.2, which is what tests\run_all.ps1 already
falls back to when the double editor is absent. It is the right tool for anything that is
not about float width, and the wrong one for anything that is.

THE REVISIONS COME FROM upstream.lock and are not written down here. That file is what
tools\update_upstream.ps1 maintains, and a second copy of three hashes is a second copy to
forget to update -- at which point this silently builds a different library from the one
the lock file claims produced the binary.
#>

[CmdletBinding()]
param(
    [switch]$FetchOnly,
    [switch]$BuildOnly,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

# PowerShell 7.4+ turns a non-zero exit from a native command into a terminating error
# while ErrorActionPreference is Stop. Several git calls below are QUESTIONS whose "no" is
# a non-zero exit -- `git apply --check`, `git config --get` -- so that is turned off here
# and exit codes are checked explicitly instead.
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "Needs Windows PowerShell 5.1 or later (Expand-Archive). Found $($PSVersionTable.PSVersion)."
}

$here   = $PSScriptRoot
$gdRoot = Split-Path -Parent $here
$root   = Split-Path -Parent $gdRoot

function Say  { param([string]$Text) Write-Host $Text }
function Step { param([string]$Text) Write-Host $Text -ForegroundColor White }

$godotVersion = "4.7.2"
# The exe names and the download URL are NOT here: tools\get_godot.ps1 owns those, and this
# script only needs to know where it put them.
$godotDir     = Join-Path $root "_tools\godot-$godotVersion"
$apiFile      = Join-Path $godotDir "extension_api.json"

# ---- what has to be on the machine already -----------------------------------
#
# Every missing thing is reported AT ONCE, with the command that installs it. Told one at
# a time this is four rounds of install-and-rerun, and the fourth is the one that tells
# you the C++ workload was never part of the Visual Studio you already had.
#
# curl and unzip are not in the list on purpose: Invoke-WebRequest and Expand-Archive are
# in the box, so the Linux script's two extra dependencies are not dependencies here.
# Neither is python, which on Linux exists only to relax GCC's -Werror -- both upstreams
# already build clean against MSVC, which is what they are developed on.

function Find-Tool {
    param([string]$Name, [string]$Glob)
    $onPath = Get-Command $Name -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    # winget's per-user package root. A shell that was already open when winget installed
    # something does not have it on PATH, and telling someone to reopen their terminal
    # when the executable is right there is not help.
    $hit = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" `
        -Recurse -Filter $Glob -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}

$wanted = @(
    @{ name = "git";   glob = "git.exe";   install = "winget install --id Git.Git" }
    @{ name = "cmake"; glob = "cmake.exe"; install = "winget install --id Kitware.CMake" }
    @{ name = "ninja"; glob = "ninja.exe"; install = "winget install --id Ninja-build.Ninja" }
)

$missing = @()
$found = @{}
foreach ($tool in $wanted) {
    $path = Find-Tool -Name $tool.name -Glob $tool.glob
    if ($path) { $found[$tool.name] = $path } else { $missing += $tool }
}

# MSVC, which is not a file on PATH but a workload inside an installation.
#
# -products * matters: without it vswhere ignores a BuildTools-only install and reports
# nothing at all, which reads as "no compiler" on a machine that has one.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = $null
if (Test-Path $vswhere) {
    $vs = & $vswhere -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath
}
if (-not $vs) {
    $missing += @{
        name    = "MSVC C++ toolset (Desktop development with C++)"
        install = 'winget install --id Microsoft.VisualStudio.2022.BuildTools --override ' +
                  '"--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"'
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "Not installed:" -ForegroundColor Red
    foreach ($tool in $missing) {
        Write-Host ("  {0}" -f $tool.name) -ForegroundColor Red
        Write-Host ("      {0}" -f $tool.install)
    }
    Write-Host ""
    Write-Host "Then run this script again. It does not need a new terminal: it looks in"
    Write-Host "winget's package directory as well as on PATH."
    exit 1
}

Say ("git:   {0}" -f $found["git"])
Say ("cmake: {0}" -f $found["cmake"])
Say ("ninja: {0}" -f $found["ninja"])
Say ("MSVC:  {0}" -f $vs)

$git = $found["git"]

# ---- asking a native command a question ---------------------------------------
#
# Windows PowerShell 5.1 -- which the header says this supports, and which is still what
# `powershell.exe` gets you -- turns a REDIRECTED native stderr into a terminating
# NativeCommandError. Under ErrorActionPreference Stop that kills the script, so a bare
# `2>$null` on a command that is expected to complain is a trap rather than a silencer.
#
# The $PSNativeCommandUseErrorActionPreference switch at the top of this file does not
# help: that variable is a PowerShell 7.4 feature and does not exist in 5.1, so the guard
# around it silently does nothing on the very edition that needs it. build.ps1 met this
# first, in Test-PatchApplied, and solved it the same way.
#
# So both helpers drop ErrorActionPreference for the duration of the call and the exit
# code is checked explicitly afterwards, which is what the caller wanted in the first
# place.
function Invoke-Quiet {
    param([string]$Exe, [string[]]$ExeArgs)
    $prior = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Exe @ExeArgs 2>&1 | Out-Null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prior
    }
}

# The same, but handing back stdout. stderr is dropped rather than merged so a warning on
# it cannot be mistaken for the answer.
function Get-Quiet {
    param([string]$Exe, [string[]]$ExeArgs)
    $prior = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $err = New-TemporaryFile
        try { return (& $Exe @ExeArgs 2>$err.FullName) } finally {
            Remove-Item $err.FullName -Force -ErrorAction SilentlyContinue
        }
    } finally {
        $ErrorActionPreference = $prior
    }
}

# LONG PATHS, which is a warning rather than an error because it only bites some trees.
#
# godot-cpp generates about 2100 files, and CMake's _deps subbuild directories nest
# deeply on top of wherever this was cloned. Past 260 characters git and CMake start
# failing in ways that name a file and not the cause.
$longPaths = Get-Quiet -Exe $git -ExeArgs @("config", "--get", "core.longpaths")
if ($LASTEXITCODE -ne 0 -or $longPaths -ne "true") {
    Say ""
    Write-Host "core.longpaths is not enabled. If a checkout or the build fails on a path" -ForegroundColor Yellow
    Write-Host "that looks truncated, this is why:" -ForegroundColor Yellow
    Write-Host "      git config --global core.longpaths true"
}

# ---- the pinned revisions ----------------------------------------------------
$lock = Join-Path $gdRoot "upstream.lock"
if (-not (Test-Path $lock)) { throw "upstream.lock not found at $lock" }

function Get-Pin {
    param([string]$Name)
    # `name = hash`, ignoring the comment lines that make up most of that file. Anchored
    # and followed by `=` so that `ashiato` does not also match `ashiato-sync`.
    $pattern = "^$([regex]::Escape($Name))\s*=\s*([0-9a-f]{7,})"
    foreach ($line in Get-Content $lock) {
        if ($line -match $pattern) { return $Matches[1] }
    }
    throw "no '$Name' revision in upstream.lock"
}

# godot-cpp is NOT in upstream.lock, and that is not an oversight: it is pinned by API
# version rather than by revision -- GODOTCPP_API_VERSION in CMakeLists.txt, against the
# extension_api.json below. There is no godot-cpp branch for 4.7; the newest is 4.5, and
# the custom API file is what makes it bind to 4.7 anyway.
$godotCppBranch = "4.5"

# ---- fetch -------------------------------------------------------------------

# Clone if absent, and in both cases end up ON the pinned revision. An existing checkout
# left on the wrong revision is the failure mode worth catching: it builds, it runs, and
# it is not the library upstream.lock says it is.
function Sync-Checkout {
    param([string]$Dir, [string]$Url, [string]$Want)
    $name = Split-Path -Leaf $Dir
    if (-not (Test-Path (Join-Path $Dir ".git"))) {
        Say ("  cloning {0}" -f $name)
        & $git clone --quiet $Url $Dir
        if ($LASTEXITCODE -ne 0) { throw "git clone $Url failed" }
    }
    $at = (& $git -C $Dir rev-parse --short HEAD).Trim()
    if ($at.Substring(0, 7) -ne $Want.Substring(0, 7)) {
        Say ("  {0}: {1} -> {2}" -f $name, $at, $Want.Substring(0, 7))
        & $git -C $Dir fetch --quiet --all --tags
        & $git -C $Dir checkout --quiet $Want
        if ($LASTEXITCODE -ne 0) { throw "$name has no revision $Want" }
    } else {
        Say ("  {0}: {1}" -f $name, $at)
    }
}

# FIXES TO UPSTREAM THAT WE DEPEND ON, kept as patches in tools\patches and applied on
# every fetch -- the same set, from the same directory, as bootstrap-linux.sh applies.
#
# These checkouts are gitignored and pinned by upstream.lock, so anything edited in place
# is lost on a re-clone and on the next revision bump, which would silently take a
# behaviour the game relies on with it. A patch that fails to apply is a HARD ERROR for
# the same reason: building against an upstream that no longer has the fix, without
# saying so, is the failure this whole arrangement exists to prevent.
#
# THE TWO --check CALLS ARE QUESTIONS, so they go through Invoke-Quiet: git answers "no"
# the only way it can, with a message on stderr and a non-zero exit, and a bare `2>$null`
# would turn that answer into a crash. See Invoke-Quiet above.
function Apply-Patches {
    param([string]$Dir, [string]$Name)
    $patches = Get-ChildItem (Join-Path $here "patches") -Filter "$Name-*.patch" `
        -ErrorAction SilentlyContinue | Sort-Object Name
    foreach ($patch in $patches) {
        # Already applied -- a re-run over an unchanged checkout, the normal case.
        if ((Invoke-Quiet -Exe $git -ExeArgs @("-C", $Dir, "apply", "--reverse", "--check", $patch.FullName)) -eq 0) {
            Say ("  {0}: already applied" -f $patch.Name)
            continue
        }
        if ((Invoke-Quiet -Exe $git -ExeArgs @("-C", $Dir, "apply", "--check", $patch.FullName)) -ne 0) {
            $at = (& $git -C $Dir rev-parse --short HEAD).Trim()
            throw ("{0} does not apply to {1} at {2}.`n" -f $patch.Name, $Name, $at) +
                  "  Upstream has moved under it. Rework the patch, or drop it if the fix has`n" +
                  "  landed upstream -- but do not build without it: see the patch header for`n" +
                  "  what it fixes."
        }
        & $git -C $Dir apply $patch.FullName
        if ($LASTEXITCODE -ne 0) { throw "applying $($patch.Name) failed" }
        Say ("  {0}: applied" -f $patch.Name)
    }
}

if (-not $BuildOnly) {
    Say ""
    Step "Dependencies, beside ashiato-gd:"
    Sync-Checkout -Dir (Join-Path $root "ashiato") `
        -Url "https://github.com/ErikGoldman/ashiato.git" -Want (Get-Pin "ashiato")
    Sync-Checkout -Dir (Join-Path $root "ashiato-sync") `
        -Url "https://github.com/ErikGoldman/ashiato-sync.git" -Want (Get-Pin "ashiato-sync")
    Sync-Checkout -Dir (Join-Path $root "box3d") `
        -Url "https://github.com/erincatto/box3d.git" -Want (Get-Pin "box3d")
    Apply-Patches -Dir (Join-Path $root "ashiato-sync") -Name "ashiato-sync"

    $godotCppDir = Join-Path $root "godot-cpp"
    if (-not (Test-Path (Join-Path $godotCppDir ".git"))) {
        Say ("  cloning godot-cpp ({0})" -f $godotCppBranch)
        & $git clone --quiet --branch $godotCppBranch `
            "https://github.com/godotengine/godot-cpp.git" $godotCppDir
        if ($LASTEXITCODE -ne 0) { throw "git clone godot-cpp failed" }
    } else {
        Say ("  godot-cpp: {0}" -f (& $git -C $godotCppDir rev-parse --short HEAD).Trim())
    }

    Say ""
    Step ("Godot {0}:" -f $godotVersion)
    # HANDED TO tools\get_godot.ps1, which is the one copy of this step.
    #
    # It used to be spelled out here, and that made this script the only way to get an
    # engine -- so a checkout that wanted nothing but topdowntest's GDScript tests still
    # had to satisfy the cmake/ninja/MSVC gate above before it could download one. The
    # download has nothing to do with the C++ toolchain; it is shared with
    # tools\bootstrap.ps1, and a second copy of it is a second copy to forget.
    #
    # It also dumps extension_api.json if it is somehow absent. That matters here more than
    # anywhere: godot-cpp's 4.5 branch has never heard of 4.7, so left to itself it binds
    # against 4.5's API and the extension loads and then calls the wrong methods -- the
    # same failure the double-precision note in CMakeLists.txt describes, for the same
    # reason.
    & (Join-Path $root "tools\get_godot.ps1") -Version $godotVersion
    if ($LASTEXITCODE -ne 0) { throw "tools\get_godot.ps1 failed" }
    if (-not (Test-Path $apiFile)) { throw "extension_api.json was not produced in $godotDir" }
}

if ($FetchOnly) {
    Say ""
    Say "Fetched. Not building."
    exit 0
}

# ---- build -------------------------------------------------------------------
#
# Handed to build.ps1, which already knows how to find MSVC and run CMake inside a
# vcvars64 environment, and which copies the finished DLL into every sibling game that
# has the addon installed.
#
# EVERY GAME MODULE, not just the cockpit's. tests\run_all.ps1 runs the addon's suites as
# well as the game's, and resim_settles, resim_events, two_clients and predict_all all
# build a DrivingWorld. Against a cockpit-only library that class does not exist, so the
# scene never finishes loading, never calls quit(), and the suite is reported as a TIMEOUT
# three minutes later -- which looks exactly like a hang in the code under test.

if (-not (Test-Path $apiFile)) {
    throw "extension_api.json missing at $apiFile; run without -BuildOnly"
}

Say ""
$buildArgs = @{
    WithCockpit = $true
    WithDriving = $true
    WithVr      = $true
    GodotApi    = $apiFile
}
if ($Clean) { $buildArgs.Clean = $true }

& (Join-Path $here "build.ps1") @buildArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Say ""
Say "Done. Run the suites with:"
Say "  powershell -ExecutionPolicy Bypass -File cockpit\tests\run_all.ps1"
exit 0
