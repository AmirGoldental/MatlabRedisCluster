@echo off
SETLOCAL EnableDelayedExpansion

if "%1"=="taskkill" (
    call :taskkill_timeout %2 %3
)

set name=unix_timeout-%RANDOM%
title %name%

for /f "tokens=2" %%f in ('tasklist /NH /FI "WINDOWTITLE eq %name%*"') do set PID=%%f

start "killme" /B /D "%~dp0" %~f0 taskkill %1 %PID%

for /f "tokens=1,* delims= " %%a in ("%*") do set ALL_BUT_FIRST=%%b

%ALL_BUT_FIRST%
exit /s

:taskkill_timeout
ping -n %1 127.0.0.1 >NUL
echo Could not connect to Redis
taskkill /f /PID %2 >NUL
exit /s