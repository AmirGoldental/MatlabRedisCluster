@echo off
SETLOCAL EnableDelayedExpansion

set params_path=%~dp0%mrc_client.conf
if "%1" == "" goto fill_params_path
set params_path=%1
:fill_params_path

call :logger INFO load parameters from %params_path%
for /f "tokens=1,* delims==" %%x in ('type "%params_path%"') do call :run_and_set %%x %%y

for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i

set cur_dir=%~dp0
set cur_dir=!cur_dir:~0,-1!

:: call :logger INFO check that matlab path exists
:: !matlab_path! -help
:: if %errorlevel%==-1 goto matlab_ok
:: echo could not find matlab in !matlab_path!
:: pause
:: exit /s
:: :matlab_ok

call :send_redis incr workers_count
if "!res!" == "failed" (
    call :logger ERROR could not communicate with redis server failed on incr workers_count
) else (
    set worker_id=!res!
    call :send_redis hmset worker:!worker_id! status initializing current_task None last_command None computer %hostname% key !worker_id!
    start "%random%_matlab_worker" "%matlab_path%" -sd "%cur_dir%" -r "mrc.join_as_worker('!worker_id!')"
)
timeout /t 30
exit /s

:run_and_set
for /f "tokens=1,* delims= " %%a in ("%*") do set %1=%%b
exit /b

:logger
for /f "tokens=1,* delims= " %%a in ("%*") do set ALL_BUT_FIRST=%%b
echo [%1] %date%T%time% %ALL_BUT_FIRST%
exit /b

:send_redis
set res=failed
set "redis_cmd=%redis_cli_path% -h %redis_hostname% -p %redis_port% -a %redis_password% -n %redis_db%"
for /f "tokens=*" %%g in ('!redis_cmd! %*') do (set res=%%g)
exit /b