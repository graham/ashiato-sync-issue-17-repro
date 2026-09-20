@echo off
rem THE DEDICATED SERVER: double-click, or `server.bat -Headless`, or `server.bat -Port 7788`,
rem or `server.bat -World lobby`, or `server.bat -SteamHost`, or `server.bat -Players 16`.
rem
rem The world, served and not played: no headset, no cockpit, no camera, nobody flying. A 2D console says who is
rem connected and what is in the air; with -Headless there is no window and the same facts go to stdout once a second
rem as SERVER_CONSOLE lines. Which Godot binary is the right one is decided in tools\server.ps1, not here.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\server.ps1" %*
if errorlevel 1 pause
