@echo off
SETLOCAL EnableDelayedExpansion

set params_path=%~dp0%mrc.conf
if "%1" == "" goto fill_params_path
set params_path=%1
:fill_params_path

call :logger INFO load parameters from %params_path%
for /f "tokens=1,* delims==" %%x in ('type "%params_path%"') do call :run_and_set %%x %%y


%python_path% "%~dp0server.py" "%~dp0mrc.conf"
timeout /t 30
exit /s

:run_and_set
for /f "tokens=1,* delims= " %%a in ("%*") do set %1=%%b
exit /b

:logger
for /f "tokens=1,* delims= " %%a in ("%*") do set ALL_BUT_FIRST=%%b
echo [%1] %date%T%time% %ALL_BUT_FIRST%
exit /b