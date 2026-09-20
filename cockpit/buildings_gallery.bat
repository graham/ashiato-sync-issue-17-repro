@echo off
rem ONE PICTURE OF EVERY BUILDING THE GAME DRAWS: double-click, or `buildings_gallery.bat --finish=fine --out=C:\somewhere`.
rem Runs tests\buildings_gallery_shot.tscn in a window on the double-precision editor, or the stock one if that is not built.
rem Pictures land in <repo>\screenshots\<today>\cockpit-building-<id>.png. Judge the run by its RESULT= line.
setlocal
set "GODOT=%~dp0..\_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
if not exist "%GODOT%" set "GODOT=%~dp0..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
    echo No Godot editor under %~dp0..\_tools. Run tools\bootstrap first.
    pause
    exit /b 1
)
echo Godot: %GODOT%
"%GODOT%" --xr-mode off --desktop-only --path "%~dp0." --resolution 1600x900 res://tests/buildings_gallery_shot.tscn -- --level=watch %*
if "%~1"=="" pause
