@echo off
SETLOCAL EnableDelayedExpansion

call :basedir test_dir "%~0"
call :basedir main_dir "%test_dir%"
call :logger INFO main dir at !main_dir!

set "params_path=!main_dir!\src\matlab\mrr_client.conf"
call :logger INFO load parameters from %params_path%
for /f "tokens=1,* delims==" %%x in (%params_path%) do call :run_and_set %%x %%y

set "redis_cmd=%redis_cli_path% -h %redis_hostname% -p %redis_port% -a %redis_password% -n %redis_db%"

:: start redis
call :logger INFO start redis 
start "redis_server" "!main_dir!\src\redis_server\redis-server.bat"

call :logger INFO start worker
start "matlab_worker" "!main_dir!\src\matlab\matlab_worker_wrapper.bat"

exit

:basedir
set "dirWithBackSlash=%~dp2"
set "%~1=%dirWithBackSlash:~0,-1%"
exit /b

:logger
for /f "tokens=1,* delims= " %%a in ("%*") do set ALL_BUT_FIRST=%%b
echo [%1] %date%T%time% %ALL_BUT_FIRST%
exit /b

:run_and_set
for /f "tokens=1,* delims= " %%a in ("%*") do set %1=%%b
exit /b