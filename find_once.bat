@echo off
REM ---------------------------------------------------------------------------
REM  ashiato-sync issue #17 -- run the reproduction ONCE and stop.
REM
REM  Sets the checkout up on first use (clones the pinned dependencies, downloads
REM  Godot 4.7.2, builds the extension, imports the project), then runs the
REM  two-process scenario a single time and prints a verdict.
REM
REM  IT DOES NOT FAIL EVERY RUN -- about four runs in five here. If this says
REM  "healthy this run", that is not the bug being absent, it is the bug being
REM  intermittent. Use find_repeating.bat.
REM
REM  EXIT CODE 0 MEANS THE BUG APPEARED. 1 means it did not, 2 means the run
REM  could not be judged.
REM
REM  Build against a different ashiato-sync revision -- a candidate fix, say --
REM  by passing it through:  find_once.bat <40-character-revision>
REM ---------------------------------------------------------------------------
setlocal

set "REV_ARG="
if not "%~1"=="" set "REV_ARG=-SyncRevision %~1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cockpit\tools\issue17\setup.ps1" %REV_ARG%
if errorlevel 1 (
    echo.
    echo Setup failed. Nothing was run. See the output above.
    exit /b 2
)

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cockpit\tools\issue17\run_repro.ps1" -Repeat 1
exit /b %errorlevel%
