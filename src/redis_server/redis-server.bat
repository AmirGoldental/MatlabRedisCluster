@echo off

for /f "usebackq" %%i IN (`hostname`) DO SET hostname=%%i
echo hostname is: %hostname%

redis-server.exe redis.conf