@echo off
SETLOCAL EnableDelayedExpansion
:: usage: matlab_worker.bat <params_path>
:: main loop:
:: - check in redis to see status
:: - if current matlab is on and status off, kill matlab
:: - if current matlab is off and status on, run matlab
:: - if status is restart, kill matlab and set status to on

for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i

set params_path=%~dp0%main.conf
if "%1" == "" goto fill_params_path
set params_path=%1
:fill_params_path

echo load parameters from %params_path%
for /f "tokens=1,* delims==" %%x in (%params_path%) do call :run_and_set %%x %%y

echo check that redis exists 
if not exist %redis_cli_path% (echo %redis_cli_path% does not exists & exit /b) 
if not exist %redis_server_path% (echo %redis_server_path% does not exists & exit /b) 

echo load host conf file at %redis_host_file%
for /f "tokens=1*delims==" %%x in (%redis_host_file%) do call :run_and_set %%x %%y

call :send_redis ping
if "%res%"=="failed" (
    echo failed pinging redis %redis_cli_path% -h %redishost% -p %redisport% -a %redis_password% -n %redis_db%
    exit /b
) else (
    echo redis ping ponged
) 

call :send_redis incr workers:ind
set wid=%res%
set matlab_name=mrr_worker_%wid%
echo got worker id: %wid%

call :send_redis set worker:%wid%:status on
call :start_matlab %matlab_name%
set matlab_pid=%res%

echo check alive
call :is_pid_alive %matlab_pid%
echo is pid alive: %res%
call :is_pid_alive 100
echo is pid alive: %res%

:main_loop

:: get my status
call :send_redis get worker:%wid%:status
set current_redis_status=%res%

:: check if matlab is alive
call :is_pid_alive %matlab_pid%
set current_matlab_status=%res%

:: main logic
if "%current_redis_status%"=="on" if "%current_matlab_status%"=="on" if 

timeout 10
@REM taskkill /PID %res%

goto exit_loop
goto main_loop

:exit_loop
call :send_redis set handler:%hostname%:alive 0
exit /b

:get_pid
for /f "tokens=2 USEBACKQ" %%f IN (`tasklist /NH /FI "WINDOWTITLE eq %1"`) Do set "res=%%f"
exit /b

:is_pid_alive
for /f "tokens=2 USEBACKQ" %%f IN (`tasklist /NH /FI "pid eq %1"`) do (
    if "%%f"=="%1" (
        set "res=on"
    ) else (
        set "res=off"
    )
)
exit /b

:start_matlab
echo start matlab process at %matlab_path%
start "%1" "%matlab_path%" -sd "%CD%" -batch "%matlab_runner_script%"
call :get_pid %matlab_name%
exit /b

:kill
taskkill /f /t /fi "windowtitle eq %1"
exit /b

:run_and_set
for /f "tokens=1,* delims= " %%a in ("%*") do set %1=%%b
exit /b

:send_redis
set res=failed
FOR /F "tokens=*" %%g IN ('%redis_cli_path% -h %redis_host% -p %redis_port% -a %redis_password% -n %redis_db% %*') do (
    set res=%%g
)
exit /b

