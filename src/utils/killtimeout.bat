@echo off
SETLOCAL EnableDelayedExpansion
set name=killtimeout-%RANDOM%
title %name%

@REM echo %name%
for /f "tokens=2" %%f in ('tasklist /NH /FI "WINDOWTITLE eq %name%*"') do set PID=%%f
@REM echo PID=%PID%

start "killme" /B /D "%~dp0" timeouttaskkill.bat %1 %PID%

for /f "tokens=1,* delims= " %%a in ("%*") do set ALL_BUT_FIRST=%%b

@REM echo %ALL_BUT_FIRST%
%ALL_BUT_FIRST%
exit /s