@echo off

set check=false
if "%1%"=="--help" set check=true
if "%1%"=="-h" set check=true
if "%1%"=="-?" set check=true
if "%1%"=="/h" set check=true
if "%1%"=="/?" set check=true
if "%check%"=="true" (
	echo "start_mrc_server.bat [-h|--help|-?] [--service] [--remove-service] [--check-if-exists] [--restart]"
	exit /b
)

if "%1%"=="--service" (
	echo "install as a service at MatlabRedisCluster\RedisServer [do not remove current folder]"
	schtasks /create /SC MINUTE /TN "MatlabRedisCluster\RedisServer" /TR "%~dpnx0"
	exit /b
)

rem if "%1"=="--remove-service" (
rem 	echo remove service from MatlabRedisCluster\RedisServer
rem 	schtasks /delete /tn "MatlabRedisCluster\RedisServer"
rem 	exit /b
rem )
rem 
rem if "%1"=="--check-if-exists" (
rem 
rem )

for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i
echo hostname is: %hostname%

"%~dp0redis-server.exe" "%~dp0redis.conf"