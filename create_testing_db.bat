:: init
@echo off
for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i

set params_path=%~dp0%main.conf
if "%1" == "" goto fill_params_path
set params_path=%1
:fill_params_path

echo Load parameters from %params_path%
for /f "tokens=1,* delims==" %%x in (%params_path%) do call :run_and_set %%x %%y

echo Check that redis exists 
if not exist %redis_cli_path% (echo %redis_cli_path% does not exists & exit /b) 
if not exist %redis_server_path% (echo %redis_server_path% does not exists & exit /b) 

echo Load host conf file at %redis_host_file%
for /f "tokens=1*delims==" %%x in (%redis_host_file%) do call :run_and_set %%x %%y

:: create sample db
set "redis_cmd=%redis_cli_path% -h %redishost% -p %redisport% -a %redis_password% -n %redis_db%"
echo My redis command is: %redis_cmd%

%redis_cmd% set global:workersnum 1


%redis_cmd% set worker:%hostname%_w0:status on
%redis_cmd% set worker:%hostname%_w0:host %hostname%

%redis_cmd% incr tasks:num

:: set and push task
%redis_cmd% set task:t0:cmd "disp('hey')"
%redis_cmd% lpush tasks:waiting t0

:: allocate task
%redis_cmd% rpoplpush tasks:waiting tasks:current
%redis_cmd% set task:t0:worker %hostname%_w0

:: finish task
%redis_cmd% lrem tasks:current 0 t0
%redis_cmd% lpush tasks:done t0

exit /b

:run_and_set
for /f "tokens=1,* delims= " %%a in ("%*") do set %1=%%b
exit /b
