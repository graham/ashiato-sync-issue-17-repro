@echo off
rem THE COOLING TOWERS, PHOTOGRAPHED WHERE THEY STAND: double-click, or `cooling_towers.bat --out=C:\somewhere`.
rem Runs tests\cooling_shot.tscn in a window on the double-precision editor, or the stock one if that is not built.
rem Two pictures: the station and its steam whole, and the towers close enough to judge the waist.
rem Judge the run by its RESULT= line, never the exit code.
setlocal
set "GODOT=%~dp0..\_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
if not exist "%GODOT%" set "GODOT=%~dp0..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
    echo No Godot editor under %~dp0..\_tools. Run tools\bootstrap first.
    pause
    exit /b 1
)
echo Godot: %GODOT%
"%GODOT%" --xr-mode off --desktop-only --path "%~dp0." --resolution 1600x900 res://tests/cooling_shot.tscn -- --level=watch %*
if "%~1"=="" pause
