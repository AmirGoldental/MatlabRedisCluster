@echo off

for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i
echo hostname is: %hostname%

"%~dp0redis-server.exe" "%~dp0redis.conf"