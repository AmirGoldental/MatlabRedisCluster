@echo off

for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i

set params_path=%~dp0%main.conf
if "%1" == "" goto fill_params_path
set params_path=%1
:fill_params_path

echo load parameters from %params_path%
for /f "delims=" %%x in (%params_path%) do set %%x

@REM check that redis-cli and redis-server exists 
if not exist %redis_cli_path% (echo %redis_cli_path% does not exists) 
if not exist %redis_server_path% (echo %redis_server_path% does not exists) 

%redis_server_path%

@REM %params_path% 
@REM echo %redis_cli_path%