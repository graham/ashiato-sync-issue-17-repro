@echo off
rem ONE PICTURE OF EVERY DEVICE IN THE COCKPIT BUILDER'S PARTS BIN.
rem Pictures land in <repo>\screenshots\<today> unless --out=C:\somewhere is supplied.
rem Use --device=GuardedToggleSwitch to render one part. Judge the run by its RESULT= line.
setlocal
set "GODOT=%~dp0..\_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
if not exist "%GODOT%" set "GODOT=%~dp0..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
    echo No Godot editor under %~dp0..\_tools. Run tools\bootstrap first.
    pause
    exit /b 1
)
echo Godot: %GODOT%
"%GODOT%" --xr-mode off --path "%~dp0." --resolution 1600x900 res://tests/device_gallery_shot.tscn -- --desktop-only %*
if "%~1"=="" pause
