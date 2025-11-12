@echo off
setlocal

set "SCRIPT=%~dp0usb_miner_cleanup.ps1"

:: Проверяем, есть ли права администратора
net session >nul 2>&1
if %errorlevel%==0 goto RunScript

echo Требуются права администратора. Запрашиваю их...
PowerShell -Command ^
  "Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT%\"' -Verb RunAs"
exit /b

:RunScript
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
endlocal