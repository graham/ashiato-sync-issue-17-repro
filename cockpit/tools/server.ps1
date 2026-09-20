## THE DEDICATED SERVER: the world, served and not played, in a 2D console or in a log.
##
##   powershell -File cockpit\tools\server.ps1                      # host the island on the usual port, 2D console
##   powershell -File cockpit\tools\server.ps1 -Port 7788           # on that port
##   powershell -File cockpit\tools\server.ps1 -World lobby         # serving a different level
##   powershell -File cockpit\tools\server.ps1 -Headless            # no window at all: SERVER_CONSOLE lines on stdout
##   powershell -File cockpit\tools\server.ps1 -SteamHost           # host over Steam and print the join code
##   powershell -File cockpit\tools\server.ps1 -Players 16          # take at most sixteen
##
## `cockpit\server.bat` is this for a double-click, and passes anything you give it straight through.
##
## WHY IT IS ITS OWN ENTRY POINT. The user, 2026-09-19: *"i want to make sure i make room to run the game as a server in
## 2d (just better for resources), or headless"*. Both halves of that sentence are one flag apart here, which is the
## point: `-Headless` or not.
##
## SOUND IS OFF AND NOT ASKED FOR. A server has nobody at it to listen, and no microphone is opened -- see
## `voice_lobby.ps1` for why that is a per-process decision here and not a project setting.
##
## XR IS OFF, `--xr-mode off --desktop-only`, and on a server that is not tidiness but one of the three things that make
## this cheaper than hosting from the game: a machine with a headset runtime installed otherwise ATTACHES to it even
## under `--headless`. Measured: a headless host printed "OpenXR: Created instance ... VirtualDesktopXR", failed to get
## a form factor, and fell back -- having paid for the attempt. See `world/server_console.gd` for the table.
##
## THERE IS NO DEADLINE AND NO `--report=1`. A server runs until it is stopped, and `SERVER_CONSOLE` is printed once a
## second whether or not anybody asked for a report, because that line IS the headless server's face.
param(
    [switch]$Stock,
    [switch]$Headless,
    [int]$Port = 0,
    [string]$World = "island",
    [switch]$SteamHost,
    [int]$Players = 0,
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
# ONE SESSION FLAG AT MOST, as `voice_lobby.ps1` does it and for the same reason: two would be a command line that says
# host over ENet and host over Steam, which `LaunchOrder` refuses with BOOT_ERROR= -- better to say so where it was typed.
if ($SteamHost -and $Port -ne 0) {
    Write-Host "Ask for one session at a time: -SteamHost and -Port $Port are two." -ForegroundColor Red
    exit 1
}
$flags = @("--level=server", "--world=$World")
if ($SteamHost) { $flags += "--steam-host" } elseif ($Port -ne 0) { $flags += "--host=$Port" } else { $flags += "--host" }
if ($Players -ne 0) { $flags += "--players=$Players" }
$flags += @($Rest | Where-Object { $_ })

$engine = @("--xr-mode", "off", "--desktop-only")
if ($Headless) { $engine = @("--headless", "--xr-mode", "off") }

Write-Host "cockpit server: $($flags -join ' ')"
& $godot --path $cockpit @engine -- @flags
exit $LASTEXITCODE
