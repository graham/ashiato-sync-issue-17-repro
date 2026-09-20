@echo off
rem OPEN COCKPIT IN THE DOUBLE-PRECISION EDITOR: double-click. `edit.bat -Stock` opens the stock float32 editor instead.
rem Opening it in the stock editor by mistake runs the game on float32 from the editor's Play button; tools\play.ps1
rem picks the binary so this can't.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play.ps1" -Editor %*
if errorlevel 1 pause
