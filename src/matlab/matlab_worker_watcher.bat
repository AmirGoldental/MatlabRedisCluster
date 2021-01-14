@echo off
SETLOCAL EnableDelayedExpansion
:: usage: matlab_wrapper.bat <params_path> <worker-id>
:: main loop:
:: - check in redis to see status
:: - if matlab is said to be killed, kill it
::      - search current task (if exists) and move to failed with errormsg of matlab died
:: - if matlab is said to be alive but isn't:
::      - search current task (if exists) and move to failed with errormsg of matlab died
::      - if matlab_restart_on_fail restart matlab with the same worker-id?
set params_path=%1
set worker_id=%2

echo test
for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i

call :logger INFO load parameters from %params_path%
for /f "tokens=1,* delims==" %%x in (%params_path%) do call :run_and_set %%x %%y

call :logger INFO check that redis exists 
if not exist %redis_cli_path% (echo !redis_cli_path! does not exists & exit /b) 

set title=%random%_%worker_id%_matlab_watcher
title %title%
start "%title%" pause
call :get_pid_by_window_name %title%
set dummy_pid=!res!
call :get_parent_pid !dummy_pid!
set my_pid=!res!
call :get_parent_pid !my_pid!
set parent_pid=!res!
echo dummy, my and parent pids: %dummy_pid%, %my_pid%, %parent_pid%
taskkill /PID !dummy_pid!

call :send_redis ping
if "%res%"=="failed" (
    call :logger ERROR failed pinging redis %redis_cli_path% -h %redishost% -p %redisport% -a %redis_password% -n %redis_db%
    exit /b
) else (
    call :logger INFO redis ping ponged
) 

:main_loop
    @timeout %wrapper_loop_wait_seconds% >nul

    :: check if matlab is alive
    call :is_pid_alive !parent_pid!
    set matlab_status=!res!

    :: check redis status
    call :send_redis hget worker:!worker_id! status
    if "!res!"=="failed" (
        call :logger WARNING redis failed with command !redis_cmd!
        call :send_redis ping
        if "!res!"=="failed" (
            call :logger WARNING failed pinging redis, waiting
        ) else (
            call :logger WARNING redis inconsistent, waiting
        ) 
        goto main_loop
    )
    set worker_status=!res!

    call :logger VERBOSE matlab_status:!matlab_status! redis_status:!worker_status!

    :: main logic
    if "!worker_status!"=="kill" if "!matlab_status!"=="on" (
        call :logger INFO kill matlab worker !worker_id! of pid=!parent_pid!
        taskkill /PID !parent_pid!

        :: find and move current task to failed
        call :send_redis hget worker:!worker_id! current_task
        if not "!res!"=="failed" (
            set current_task=!res!
            :: move task from ongoing to error and push error message
            call :send_redis lrem ongoing_matlab_tasks 0 !current_task!
            call :send_redis sadd failed_matlab_tasks !current_task!
            call :send_redis hset !current_task! failed_on "%date% %time%"
            call :send_redis hset !current_task! err_msg "worker killed" 
            call :send_redis hdel worker:!worker_id! current_task
        )
        
        call :send_redis hset worker:!worker_id! status dead
        exit /b
    )

    if "!worker_status!"=="active" if "!matlab_status!"=="off" (     
        call :logger INFO matlab died
        :: find and move current task to failed
        call :send_redis hget worker:!worker_id! current_task
        if not "!res!"=="failed" (
            :: move task from ongoing to error and push error message
            call :send_redis lrem ongoing_matlab_tasks 0 !current_task!
            call :send_redis sadd failed_matlab_tasks !current_task!
            call :send_redis hset !current_task! failed_on "%date% %time%"
            call :send_redis hset !current_task! err_msg "worker died" 
            call :send_redis hdel worker:!worker_id! current_task
        )

        if "%matlab_restart_on_fail%"=="true" (
            call :send_redis hset worker:!worker_id! status restart
            call %~dp0%matlab_worker_wrapper.bat
        ) else (
            call :send_redis hset worker:!worker_id! status dead
        )
        exit /b
    )
goto main_loop

:: =================== helper functions ========================
:logger
for /f "tokens=1,* delims= " %%a in ("%*") do set ALL_BUT_FIRST=%%b
echo [%1] %date%T%time% %ALL_BUT_FIRST%
exit /b

:get_parent_pid
for /f "usebackq tokens=2 delims==" %%a in (`wmic process where ^(processid^=%1^) get parentprocessid /value`) do (
    set res=%%a
)
exit /b

:get_pid_by_window_name
for /f "tokens=2 USEBACKQ" %%f IN (`tasklist /NH /FI "WINDOWTITLE eq %1"`) do (set "res=%%f")
exit /b

:get_pid
@REM for /f "tokens=2 USEBACKQ" %%f IN (`tasklist /NH /FI "WINDOWTITLE eq *%1"`) do (set "res=%%f")
for /f "tokens=2 USEBACKQ" %%f IN (`tasklist /nh /v /fi "IMAGENAME eq matlab.exe" ^| find "%1"`) do (set "res=%%f")
@REM echo pid of %1 is %res%
exit /b

:is_pid_alive
for /f "tokens=2 USEBACKQ" %%f IN (`tasklist /nh /fi "pid eq %1"`) do (
    if "%%f"=="%1" (
        set "res=on"
    ) else (
        set "res=off"
    )
)
exit /b

:start_matlab
@REM echo start matlab process at %matlab_path%
start "%1" "%matlab_path%" -sd "%~dp0" -batch "%matlab_runner_script%"
call :get_pid %1
exit /b

:kill
taskkill /f /t /fi "windowtitle eq %1"
exit /b

:run_and_set
for /f "tokens=1,* delims= " %%a in ("%*") do set %1=%%b
exit /b

:send_redis
set res=failed
set "redis_cmd=%redis_cli_path% -h %redis_host% -p %redis_port% -a %redis_password% -n %redis_db%"
for /f "tokens=*" %%g in ('!redis_cmd! %*') do (set res=%%g)
exit /b

