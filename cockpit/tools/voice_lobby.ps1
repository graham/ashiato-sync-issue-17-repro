## THE FLAT 2D VOICE LOBBY, ON THE DOUBLE-PRECISION ENGINE THIS PROJECT IS WRITTEN AGAINST.
##
##   powershell -File cockpit\tools\voice_lobby.ps1                      # the lobby; press HOST or JOIN in it
##   powershell -File cockpit\tools\voice_lobby.ps1 -Host                # host over ENet straight away
##   powershell -File cockpit\tools\voice_lobby.ps1 -Join 192.168.1.20   # join that machine over ENet
##   powershell -File cockpit\tools\voice_lobby.ps1 -SteamHost           # host over Steam and print the join code
##   powershell -File cockpit\tools\voice_lobby.ps1 -SteamJoin ABC123    # join a Steam game by its code
##   powershell -File cockpit\tools\voice_lobby.ps1 -Name GRAHAM         # and be called that
##
## `cockpit\voicelobby.bat` is this for a double-click, and passes anything you give it straight through.
##
## WHY IT IS ITS OWN ENTRY POINT AND NOT A FLAG ON `play.ps1`. The user asked for one: "we'll need a different entry
## point and .bat so i can test it on other machines" (2026-09-19). The lobby is the thing you run on the second machine
## to find out whether voice works at all, so it should be one thing to double-click on a machine that has never run this
## project -- not a flag somebody has to remember beside four others.
##
## SOUND IS ON, `--audio`, because somebody is here to listen: voice is the whole point of the room. Every suite and
## every agent run leaves it off (agents.md).
##
## XR IS OFF, explicitly, for the same reason the room draws no 3D: `--xr-mode off --desktop-only` means a machine with a
## headset runtime installed does not start a session with it, and the lobby cannot accidentally become a VR test.
##
## THE MICROPHONE IS NOT ASKED FOR HERE, and deliberately not in `project.godot` either. The lobby opens an input device
## itself, in its own process, at the moment it starts listening -- `audio/driver/enable_input` is read by
## `AudioServer::set_input_device_active`, not by the audio driver at start-up (working_with_godot.md, "A microphone opens
## per process"). So running the flight sim, or any suite, opens no microphone.
param(
    [switch]$Stock,
    [switch]$HostGame,
    [string]$Join = "",
    [switch]$SteamHost,
    [string]$SteamJoin = "",
    [string]$Name = "",
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$cockpit = Join-Path $root "cockpit"
$double = Join-Path $root "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
$single = Join-Path $root "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if ($Stock) {
    $godot = $single
    Write-Host "Stock float32 editor, as asked: $godot" -ForegroundColor Yellow
} elseif (Test-Path $double) {
    $godot = $double
    Write-Host "Double-precision editor: $godot"
} else {
    $godot = $single
    Write-Host "NO DOUBLE-PRECISION EDITOR at $double -- running on the stock float32 one. Build it with tools\bootstrap.ps1 -Double." -ForegroundColor Red
}
if (-not (Test-Path $godot)) {
    Write-Host "No editor at $godot. Run tools\bootstrap.ps1 first." -ForegroundColor Red
    exit 1
}
# ONE SESSION FLAG AT MOST. Two would be a command line that says join and host, which `LaunchOrder` refuses with
# BOOT_ERROR= -- better to say so here, where the person typed it.
$asked = @()
if ($HostGame) { $asked += "--host" }
if ($Join -ne "") { $asked += "--join=$Join" }
if ($SteamHost) { $asked += "--steam-host" }
if ($SteamJoin -ne "") { $asked += "--steam-join=$SteamJoin" }
if ($asked.Count -gt 1) {
    Write-Host "Ask for one session at a time: $($asked -join ' ')" -ForegroundColor Red
    exit 1
}
$flags = @("--level=voice", "--audio") + $asked
if ($Name -ne "") { $flags += "--player-name=$Name" }
$flags += @($Rest | Where-Object { $_ })
Write-Host "cockpit voice lobby: $($flags -join ' ')"
& $godot --path $cockpit --xr-mode off --desktop-only -- @flags
exit $LASTEXITCODE
