@echo off
SETLOCAL EnableDelayedExpansion
ping -n %1 127.0.0.1 >NUL
taskkill /f /PID %2 >NUL
exit /s