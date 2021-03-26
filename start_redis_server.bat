@echo off

set check=false
if "%1%"=="--help" set check=true
if "%1%"=="-h" set check=true
if "%1%"=="-?" set check=true
if "%1%"=="/h" set check=true
if "%1%"=="/?" set check=true
if "%check%"=="true" (
	echo "start_redis_server.bat [-h|--help|-?] [--service] [--remove-service]"
	exit /b
)

if "%1%"=="--service" (
	echo "install as a service at MatlabRedisCluster\RedisServer [do not remove current folder]"
	schtasks /create /SC MINUTE /TN "MatlabRedisCluster\RedisServer" /TR "%~dpnx0"
	exit /b
)

if "%1"=="--remove-service" (
	echo remove service from MatlabRedisCluster\RedisServer
	schtasks /delete /tn "MatlabRedisCluster\RedisServer"
	exit /b
)

for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i
echo hostname is: %hostname%

start "hostname: %hostname%" "%~dp0utils\redis-server.exe" "%~dp0redis.conf"
exit 