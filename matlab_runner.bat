@echo off
SETLOCAL EnableDelayedExpansion
:: design:
:: - check in redis to see running status global and local 
:: - if one of workers need to be killed kill it
:: - check in redis to see how many matlabs should I open
::
::
::

for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i

set params_path=%~dp0%main.conf
if "%1" == "" goto fill_params_path
set params_path=%1
:fill_params_path

echo Load parameters from %params_path%
for /f "tokens=1,* delims==" %%x in (%params_path%) do call :run_and_set %%x %%y

echo Check that redis exists 
if not exist %redis_cli_path% (echo %redis_cli_path% does not exists) 
if not exist %redis_server_path% (echo %redis_server_path% does not exists) 

echo Load host conf file at %redis_host_file%
for /f "tokens=1*delims==" %%x in (%redis_host_file%) do call :run_and_set %%x %%y

@REM TODO: Check that there are no similar processes

call :send_redis ping
if "%res%"=="failed" (
    echo failed pinging redis %redis_cli_path% -h %redishost% -p %redisport% -a %redis_password% -n %redis_db%
    exit /b
) else (
    echo redis ping ponged
) 

set random_prefix=%random%_matlab_worker
set ind=0

:main_loop

call :send_redis set handler:%hostname%:alive 1

:: get conf
call :send_redis get handler:%hostname%:status
if "%res%"=="failed" (
    call :send_redis get handler:global:status    
)
if "%res%"=="failed" (
    echo bad redis configuration
    goto exit_loop
)
set status=%res%

call :send_redis get handler:%hostname%:workersnum
if "%res%"=="failed" (
    call :send_redis get handler:global:workersnum
)
if "%res%"=="failed" (
    echo bad redis configuration
    goto exit_loop
)
set workersnum=%res%

if %status% GTR 0 (
    if %ind% LSS %workersnum% (
        set new_matlab_name=%random_prefix%_%ind%
        call :start_matlab %new_matlab_name%
        set "matlab_names[%ind%]=%new_matlab_name%"
        set /a ind=%ind%+1
        echo new matlab named !matlab_names[%ind%]!
    )

    if %ind% GTR %workersnum% (
        @REM TODO: kill the last process
    )
) else (
    if %ind% GTR 0 (
        @REM TODO: kill the last process
    )
)

timeout 10


goto exit_loop
goto main_loop

:exit_loop
call :send_redis set handler:%hostname%:alive 0
exit /b


:start_matlab
echo start matlab process at %matlab_path%
start "%1" "%matlab_path%" -sd "%CD%" -batch "%matlab_runner_script%"
exit /b

:kill
taskkill /f /t /fi "windowtitle eq %1"

:run_and_set
for /f "tokens=1,* delims= " %%a in ("%*") do set %1=%%b
exit /b

:send_redis
set res=failed
FOR /F "tokens=*" %%g IN ('%redis_cli_path% -h %redishost% -p %redisport% -a %redis_password% -n %redis_db% %*') do (
    set res=%%g
)
exit /b

