@echo off
rem A FORWARD STARTUP VIEW FROM EVERY SEAT: cockpit\station_gallery.bat [--out=C:\somewhere].
rem This renders the real VehicleView and CockpitStation path. Pictures land in
rem screenshots\<today>\cockpit-station-<craft>-seat<N>.png; inspect them beside the exterior gallery.
setlocal
set "GODOT=%~dp0..\_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
if not exist "%GODOT%" set "GODOT=%~dp0..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
    echo No Godot editor under %~dp0..\_tools. Run tools\bootstrap first.
    pause
    exit /b 1
)
echo Godot: %GODOT%
"%GODOT%" --xr-mode off --desktop-only --path "%~dp0." --resolution 1600x900 res://tests/station_gallery_shot.tscn -- %*
if "%~1"=="" pause
