<#
Puts the stock Godot editor under _tools\godot-<version>\ , and does nothing if it is
already there.

    powershell -ExecutionPolicy Bypass -File tools\get_godot.ps1
    powershell -ExecutionPolicy Bypass -File tools\get_godot.ps1 -Version 4.7.2

THE ONE COPY OF THIS STEP. It used to live inside ashiato-gd\tools\bootstrap-windows.ps1,
which is a fine place for it if the cockpit is what you are here for and a bad one
otherwise: that script will not fetch so much as a byte until cmake, ninja and the MSVC
C++ workload are all installed, because the thing it exists to do is compile a C++
extension. topdowntest and racer need no compiler at all -- every native library they load
is committed -- so gating their engine behind a toolchain asked people to install half a
gigabyte of Visual Studio to run a GDScript test. This is the half both callers share, and
tools\bootstrap.ps1 and that bootstrap now both call it rather than keeping a copy each.

The Linux counterpart is tools/get_godot.sh.

WHY BOTH EXES. The zip is flat and carries the windowed editor and the console one beside
it, and it is the CONSOLE build that everything here runs. The plain one is a GUI-subsystem
binary: it never attaches to the calling console, so from PowerShell its stdout is simply
gone and a failed run looks exactly like a successful one. A tree holding only the windowed
exe is a half-finished download, so it is re-fetched rather than accepted.
#>

[CmdletBinding()]
param(
    [string]$Version = "4.7.2",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$root = Split-Path -Parent $PSScriptRoot

$godotDir     = Join-Path $root "_tools\godot-$Version"
$godotExe     = Join-Path $godotDir "Godot_v$Version-stable_win64.exe"
$godotConsole = Join-Path $godotDir "Godot_v$Version-stable_win64_console.exe"
$godotZipUrl  = "https://github.com/godotengine/godot/releases/download/$Version-stable/Godot_v$Version-stable_win64.exe.zip"
$apiFile      = Join-Path $godotDir "extension_api.json"

function Say { param([string]$Text) Write-Host $Text }

if ($Force -or -not (Test-Path $godotExe) -or -not (Test-Path $godotConsole)) {
    New-Item -ItemType Directory -Force -Path $godotDir | Out-Null
    Say ("  downloading Godot {0}" -f $Version)
    $zip = Join-Path $godotDir "godot.zip"
    # Invoke-WebRequest spends most of a download repainting a progress bar.
    $wasProgress = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        Invoke-WebRequest -Uri $godotZipUrl -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $godotDir -Force
    } finally {
        $ProgressPreference = $wasProgress
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path $godotConsole)) {
    throw ("The zip did not contain {0}. Godot's Windows release layout has changed." -f
           (Split-Path -Leaf $godotConsole))
}

# stderr dropped rather than merged, and ErrorActionPreference stood down for the call:
# Windows PowerShell 5.1 turns a REDIRECTED native stderr into a terminating
# NativeCommandError, so a bare `2>$null` here is a trap and not a silencer.
$prior = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $errFile = New-TemporaryFile
    try { $version = (& $godotConsole --version 2>$errFile.FullName) | Select-Object -Last 1 }
    finally { Remove-Item $errFile.FullName -Force -ErrorAction SilentlyContinue }
} finally { $ErrorActionPreference = $prior }
Say ("  {0}  ({1})" -f $version, $godotDir)

# THE API FILE, dumped from the very editor that is going to run.
#
# Normally it is already here: _tools\godot-<version>\extension_api.json is TRACKED, for
# the reason .gitignore gives -- it is what godot-cpp binds against, and it is the thing
# that must not silently drift. Dumped only if it is somehow absent.
if (-not (Test-Path $apiFile)) {
    Say "  dumping extension_api.json"
    Push-Location $godotDir
    try { & $godotConsole --headless --dump-extension-api | Out-Null } finally { Pop-Location }
    if (-not (Test-Path $apiFile)) { throw "extension_api.json was not produced in $godotDir" }
}

exit 0
