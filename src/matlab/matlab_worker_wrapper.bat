@echo off
SETLOCAL EnableDelayedExpansion

set params_path=%~dp0%mrr_client.conf
if "%1" == "" goto fill_params_path
set params_path=%1
:fill_params_path

call :logger INFO load parameters from %params_path%
for /f "tokens=1,* delims==" %%x in (%params_path%) do call :run_and_set %%x %%y

set cur_dir=%~dp0
set cur_dir=!cur_dir:~0,-1!

call :logger INFO check that matlab path exists 
if not exist !matlab_path! (echo !matlab_path! does not exists & exit /b) 

start "%random%_matlab_worker" "%matlab_path%" -sd "%cur_dir%" -batch "mrr.join_as_worker"
exit

:run_and_set
for /f "tokens=1,* delims= " %%a in ("%*") do set %1=%%b
exit /b

:logger
for /f "tokens=1,* delims= " %%a in ("%*") do set ALL_BUT_FIRST=%%b
echo [%1] %date%T%time% %ALL_BUT_FIRST%
exit /b