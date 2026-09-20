@echo off
REM Builds the flight-model prototype with the MSVC the addon uses (/O2 /fp:precise). Run surfaces.exe and fleet.exe.
REM Not part of the game or any suite: see cockpit/research/flight_model_plan.md, "The prototype".
cd /d %~dp0
for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do set VS=%%i
call "%VS%\VC\Auxiliary\Build\vcvars64.bat" >nul
cl /nologo /O2 /EHsc /std:c++17 /fp:precise surfaces.cpp /Fe:surfaces.exe && cl /nologo /O2 /EHsc /std:c++17 /fp:precise fleet.cpp /Fe:fleet.exe
