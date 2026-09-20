## EXPORT A DEV BUILD OF COCKPIT: a thin wrapper over `release_beta.ps1 -Dev`, so there is one export path and one bake.
##
##   powershell -File cockpit\tools\export.ps1                          into cockpit\build
##   ... -OutDir C:\somewhere -HostVoice                               with the ATC voice model beside the exe
##
## THE DECISION (2026-09-18, lane/buildtag): this was a second export of its own, on the STOCK editor, baking nothing.
## Its builds said "dev . unknown" in the lower right, because an exported game has no .git to read, and the stock
## template cannot load the double-precision library the project ships with. It now asks release_beta.ps1 for a -Dev
## build: the double editor and template, the commit, branch and time baked in, BUILD_INFO.txt, music and, with
## -HostVoice, the voice. The game says "dev . <commit> . <when built>". Nothing is named, versioned, zipped, posted or
## committed, and project.godot is put back byte for byte.
##
## -Godot, -MusicSource, -VoiceModels, -VoiceBin and -Debug went with the old body: the editor is the double one, the
## music and voice come from where release_beta.ps1 takes them, and a debug export is not a build anybody is handed.
param(
    [string]$OutDir = "",
    [switch]$HostVoice
)
$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $project "build" }
$release = Join-Path $PSScriptRoot "release_beta.ps1"
if ($HostVoice) { & $release -Dev -OutDir $OutDir -HostVoice } else { & $release -Dev -OutDir $OutDir }
