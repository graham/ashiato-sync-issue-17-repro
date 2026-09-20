@echo off
rem PLAY COCKPIT ON THE DOUBLE-PRECISION ENGINE: double-click, or `play.bat --level=menu`, or `play.bat -Stock`.
rem Which Godot binary is the right one is decided in tools\play.ps1, not here; this only saves typing its command line.
rem For the headset: start Virtual Desktop's PC VR first, then press V in the game window.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play.ps1" %*
if errorlevel 1 pause
