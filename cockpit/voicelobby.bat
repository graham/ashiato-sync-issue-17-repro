@echo off
rem THE FLAT 2D VOICE LOBBY: double-click, or `voicelobby.bat -HostGame`, or `voicelobby.bat -Join 192.168.1.20`,
rem or `voicelobby.bat -SteamHost`, or `voicelobby.bat -SteamJoin ABC123`, or `voicelobby.bat -Name GRAHAM`.
rem
rem No world, no cockpit, no headset: a player list with names and teams, text chat, and voice. This is the thing to run
rem on a second machine to find out whether talking to each other works at all. Which Godot binary is the right one is
rem decided in tools\voice_lobby.ps1, not here.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\voice_lobby.ps1" %*
if errorlevel 1 pause
