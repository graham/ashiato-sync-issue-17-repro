@echo off
rem RENDER THE TWO DEVICE-YARD ROOMS at 100, 250 and 500 endpoints per room.
rem Pictures land in <repo>\screenshots\<today> unless --out=C:\somewhere is supplied.
rem This is a visual probe; use tests\room_transport.tscn for the authoritative input/replication path.
setlocal
set "GODOT=%~dp0..\_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
if not exist "%GODOT%" set "GODOT=%~dp0..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
    echo No Godot editor under %~dp0..\_tools. Run tools\bootstrap first.
    pause
    exit /b 1
)
echo Godot: %GODOT%
"%GODOT%" --xr-mode off --path "%~dp0." --resolution 1600x900 res://tests/device_yard_gallery_shot.tscn -- %*
if "%~1"=="" pause
