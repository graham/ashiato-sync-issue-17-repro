# BUILD GODOTSTEAM FOR THIS COCKPIT, IN BOTH PRECISIONS, and put the libraries in addons/godotsteam/win64.
#
#   powershell -ExecutionPolicy Bypass -File cockpit\tools\build_godotsteam.ps1 -Sdk <steamworks_sdk_165.zip or its folder>
#   ... -GodotSteam <checkout at v4.21-gde> -GodotCpp <godot-cpp checkout> -Work <build folder> -Install
#
# WHY THIS EXISTS. The GodotSteam release ships single-precision libraries only, and cockpit's suites run on a
# precision=double editor. Measured 2026-09-14 (tests/steam_probe.gd): untagged, the double editor dies inside
# libgodotsteam during class registration and cockpit's lint exits 0xC0000374; tagged `single`, it skips the library and
# prints three ERROR lines on every run, which fail every suite the runner's error gate covers. Upstream has no double
# build at 4.21, 4.22 or 4.22.1. So it is built here, the way ashiato_gd.double.dll is.
#
# WHAT IT BUILDS: GodotSteam at exactly v4.21-gde (807b7c97), the version racer and topdowntest commit, as
#   libgodotsteam.windows.template_debug.x86_64.dll            and .template_release.  (single)
#   libgodotsteam.windows.template_debug.double.x86_64.dll     and .template_release.  (double)
# The `.double` is godot-cpp's own suffix, and addons/godotsteam/godotsteam.gdextension names both sides by precision.
#
# AGAINST THE ENGINE'S OWN API FILES, _tools/godot-4.7.2/extension_api.json and _tools/godot-4.7.2-double/, for the
# reason tools/build.ps1 in ashiato-gd gives: godot-cpp has no 4.7 branch, and a double build bound to a single API file
# disagrees about every real_t. GodotSteam pins godot-cpp 6388e26 (4.4); this takes whatever checkout it is handed and
# was first run against 101ae38, the godot-cpp ashiato builds against 4.7 with.
#
# THE STEAMWORKS SDK IS NOT IN THE REPOSITORY and never goes in it: its headers and libraries are Valve's, downloaded
# from partner.steamgames.com/downloads. Only the redistributable steam_api64.dll is committed, beside the libraries,
# and it is the SDK's own -- the one the libraries were compiled against.
#
# EACH PRECISION IN ITS OWN COPY of the source and of godot-cpp, because godot-cpp generates its bindings into its own
# tree from the API file, and one tree built single then double would regenerate and rebuild everything on every switch.
#
# MSVC through vcvars64, found with vswhere `-products *` (a BuildTools-only install is invisible without it), and SCons
# run as `py -3 -m SCons` inside that environment so godot-cpp takes the compiler it finds there.

param(
    [Parameter(Mandatory = $true)][string]$Sdk,
    [Parameter(Mandatory = $true)][string]$GodotSteam,
    [Parameter(Mandatory = $true)][string]$GodotCpp,
    [string]$Work = (Join-Path $env:TEMP "godotsteam_build"),
    [int]$Jobs = [Math]::Max(2, [Environment]::ProcessorCount - 2),
    [switch]$Install
)

$ErrorActionPreference = "Stop"
$cockpit = Split-Path -Parent $PSScriptRoot
$root = Split-Path -Parent $cockpit
$pinned = "807b7c97b9fa35e33406e38977dd6681725a7b4b"
function Say($text) { Write-Host "[build_godotsteam] $text" }

# THE SOURCE, AT THE PINNED COMMIT AND NO OTHER. A newer GodotSteam changes the API the probe measured.
$head = (& git -C $GodotSteam rev-parse HEAD).Trim()
if ($head -ne $pinned) { throw "GodotSteam at $head, wanted v4.21-gde $pinned" }
Say "godotsteam $head (v4.21-gde)"
Say ("godot-cpp  {0}" -f (& git -C $GodotCpp rev-parse --short HEAD).Trim())

# THE SDK, from the zip or an unzipped folder, checked for the two things the build reads.
$sdkRoot = $Sdk
if ($Sdk.EndsWith(".zip")) {
    Say ("sdk zip    {0} sha256 {1}" -f $Sdk, (Get-FileHash $Sdk -Algorithm SHA256).Hash.ToLower())
    $sdkRoot = Join-Path $Work "steamworks_sdk"
    if (-not (Test-Path (Join-Path $sdkRoot "sdk"))) { Expand-Archive -Path $Sdk -DestinationPath $sdkRoot -Force }
}
$sdkFolder = Join-Path $sdkRoot "sdk"
foreach ($needed in @("public\steam\steam_api.h", "redistributable_bin\win64\steam_api64.dll", "redistributable_bin\win64\steam_api64.lib")) {
    if (-not (Test-Path (Join-Path $sdkFolder $needed))) { throw "Steamworks SDK has no sdk\$needed under $sdkRoot" }
}
$version = (Select-String -Path (Join-Path $sdkFolder "Readme.txt") -Pattern "^v1\.\d+" | Select-Object -First 1).Line
Say "sdk        $version"
# THE REDISTRIBUTABLE IS THE ONE THE LIBRARIES ARE COMPILED AGAINST, and it is not the one GodotSteam's 4.21 release
# ships (8de54d32..., in racer and topdowntest), although that release says it is for SDK 1.65. Measured 2026-09-14:
# the SDK 1.65 zip downloaded that day (SHA-256 8c42792e...) holds steam_api64.dll e6d9bafb... So this is checked
# rather than trusted, and a different SDK is a question to answer before its library ships beside these.
$wantedApi = "e6d9bafb9a41e42fba7b21553db49f8719027af3f0deb23ff86cfc44d60e776d"
$api64 = (Get-FileHash (Join-Path $sdkFolder "redistributable_bin\win64\steam_api64.dll") -Algorithm SHA256).Hash.ToLower()
if ($api64 -ne $wantedApi) { throw "the SDK's steam_api64.dll is $api64, wanted SDK 1.65's $wantedApi" }
Say "steam_api64.dll $api64"

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$vcvars = Join-Path $vs "VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path $vcvars)) { throw "vcvars64.bat not found; install Visual Studio Build Tools." }

$built = @()
foreach ($precision in @("single", "double")) {
    $api = if ($precision -eq "double") { Join-Path $root "_tools\godot-4.7.2-double\extension_api.json" } `
           else { Join-Path $root "_tools\godot-4.7.2\extension_api.json" }
    $said = (Get-Content $api -TotalCount 12 | Select-String '"precision"').Line.Trim()
    if ($said -notmatch $precision) { throw "$api says $said, wanted $precision" }

    # A COPY OF EACH TREE PER PRECISION, the SDK laid in where GodotSteam's SConstruct reads it.
    $tree = Join-Path $Work $precision
    & robocopy $GodotSteam $tree /E /XD .git godot-cpp sdk /NFL /NDL /NJH /NJS /NP | Out-Null
    & robocopy $GodotCpp (Join-Path $tree "godot-cpp") /E /XD .git /NFL /NDL /NJH /NJS /NP | Out-Null
    & robocopy (Join-Path $sdkFolder "public") (Join-Path $tree "godotsteam\sdk\public") /E /NFL /NDL /NJH /NJS /NP | Out-Null
    & robocopy (Join-Path $sdkFolder "redistributable_bin") (Join-Path $tree "godotsteam\sdk\redistributable_bin") /E /NFL /NDL /NJH /NJS /NP | Out-Null

    # GODOTSTEAM 4.21'S OWN SCONSTRUCT DOES NOT PARSE. Its doc-data block is a `try:` indented with tabs whose
    # `except AttributeError:` and `print` are indented with spaces, and Python 3 stops at line 79 with "IndentationError:
    # unindent does not match any outer indentation level" before anything is compiled (measured 2026-09-14). Mended in
    # this COPY only, to tabs, and the checkout is left as upstream shipped it.
    $sconstruct = Join-Path $tree "SConstruct"
    $mended = (Get-Content $sconstruct -Raw) -replace "\n    except AttributeError:\r?\n        print", "`n`texcept AttributeError:`n`t`tprint"
    [System.IO.File]::WriteAllText($sconstruct, $mended)

    foreach ($target in @("template_debug", "template_release")) {
        Say "$precision $target, $Jobs jobs, api $api"
        $bat = Join-Path $env:TEMP ("godotsteam_build_{0}.bat" -f [Guid]::NewGuid().ToString("N"))
        @"
@echo off
call "$vcvars" >nul 2>&1
if errorlevel 1 exit /b 1
cd /d "$tree"
py -3 -m SCons platform=windows arch=x86_64 target=$target precision=$precision custom_api_file="$api" -j$Jobs
exit /b %errorlevel%
"@ | Set-Content $bat -Encoding ascii
        $clock = [System.Diagnostics.Stopwatch]::StartNew()
        & cmd /c $bat
        $code = $LASTEXITCODE
        Remove-Item $bat -ErrorAction SilentlyContinue
        if ($code -ne 0) { throw "scons failed for $precision $target (exit $code)" }
        $suffix = if ($precision -eq "double") { ".double" } else { "" }
        $dll = Join-Path $tree "bin\libgodotsteam.windows.$target$suffix.x86_64.dll"
        if (-not (Test-Path $dll)) { throw "scons said OK and there is no $dll" }
        Say ("built      {0} in {1:n0} s, sha256 {2}" -f (Split-Path -Leaf $dll), $clock.Elapsed.TotalSeconds,
            (Get-FileHash $dll -Algorithm SHA256).Hash.ToLower().Substring(0, 16))
        $built += $dll
    }
}

if ($Install) {
    $into = Join-Path $cockpit "addons\godotsteam\win64"
    New-Item -ItemType Directory -Force $into | Out-Null
    foreach ($dll in $built) { Copy-Item $dll $into -Force }
    Copy-Item (Join-Path $sdkFolder "redistributable_bin\win64\steam_api64.dll") $into -Force
    Say "installed into $into"
    Get-ChildItem $into | ForEach-Object {
        Say ("  {0,-58} {1,9:n0} bytes  {2}" -f $_.Name, $_.Length, (Get-FileHash $_.FullName).Hash.ToLower().Substring(0, 16))
    }
}
