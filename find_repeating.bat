@echo off
REM ---------------------------------------------------------------------------
REM  ashiato-sync issue #17 -- run the reproduction until it fails.
REM
REM  Same scenario as find_once.bat, run up to 40 times, stopping at the first
REM  run that reproduces the bug. Use this one to get a failure in front of a
REM  debugger, and after a candidate fix to see whether the failure is gone.
REM
REM  Each run is about forty seconds, so a failure usually arrives inside two
REM  minutes. Ctrl-C stops it.
REM
REM      find_repeating.bat            40 runs, stop at the first failure
REM      find_repeating.bat 100        100 runs, stop at the first failure
REM      find_repeating.bat 40 all     all 40 runs, and print the rate
REM
REM  "all" is the one to use when checking a fix: a fix is not proved by one
REM  healthy run when the fault only appears in four runs of five. Twenty clean
REM  runs in a row is worth something; one is not.
REM
REM  EXIT CODE 0 MEANS THE BUG APPEARED at least once. 1 means it never did.
REM ---------------------------------------------------------------------------
setlocal

set "RUNS=%~1"
if "%RUNS%"=="" set "RUNS=40"

set "ALL="
if /I "%~2"=="all" set "ALL=-All"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cockpit\tools\issue17\setup.ps1"
if errorlevel 1 (
    echo.
    echo Setup failed. Nothing was run. See the output above.
    exit /b 2
)

echo.
echo Running up to %RUNS% times. Each run is about forty seconds.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cockpit\tools\issue17\run_repro.ps1" -Repeat %RUNS% %ALL%
exit /b %errorlevel%
