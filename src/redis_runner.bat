@echo off

for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i

set params_path=%~dp0%main.conf
if "%1" == "" goto fill_params_path
set params_path=%1
:fill_params_path

echo Load parameters from %params_path%
for /f "delims=" %%x in (%params_path%) do set %%x

echo Check that redis exists 
if not exist %redis_cli_path% (echo %redis_cli_path% does not exists) 
if not exist %redis_server_path% (echo %redis_server_path% does not exists) 

echo Write host conf file at %redis_host_file%
echo redis_host=%hostname% > %redis_host_file%
echo redis_port=6379 >> %redis_host_file%

%redis_server_path% %redis_conf_path%