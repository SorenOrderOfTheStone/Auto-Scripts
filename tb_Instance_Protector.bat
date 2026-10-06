@echo off
setlocal enabledelayedexpansion

:: Ensure the script runs from its own directory
cd /d "%~dp0"

:: Give all scripts a 5-second grace period to spin up on boot
timeout /t 5 /nobreak >nul

:loop
    set activeCount=0

    :: 1. Check svhost.exe
    set count=0
    for /f "tokens=2" %%a in ('tasklist /fi "imagename eq svhost.exe" /nh 2^>nul') do (
        set /a count+=1
        if !count! gtr 1 (
            taskkill /pid %%a /f >nul 2>&1
        )
    )
    set /a activeCount+=count

    :: 2. Check tb_Watchdog.bat
    set count=0
    for /f %%a in ('powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='cmd.exe'\" | Where-Object { $_.CommandLine -like '*tb_Watchdog.bat*' } | Select-Object -ExpandProperty ProcessId" 2^>nul') do (
        set /a count+=1
        if !count! gtr 1 (
            taskkill /pid %%a /f >nul 2>&1
        )
    )
    set /a activeCount+=count

    :: 3. Check tb_AutoShutdown.ps1
    set count=0
    for /f %%a in ('powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*tb_AutoShutdown.ps1*' } | Select-Object -ExpandProperty ProcessId" 2^>nul') do (
        set /a count+=1
        if !count! gtr 1 (
            taskkill /pid %%a /f >nul 2>&1
        )
    )
    set /a activeCount+=count

    :: 4. Check tb_FolderGuard.ps1
    set count=0
    for /f %%a in ('powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*tb_FolderGuard.ps1*' } | Select-Object -ExpandProperty ProcessId" 2^>nul') do (
        set /a count+=1
        if !count! gtr 1 (
            taskkill /pid %%a /f >nul 2>&1
        )
    )
    set /a activeCount+=count

    :: If zero tracked processes are running, wait 3 seconds to be sure, then exit
    if !activeCount! equ 0 (
        timeout /t 3 /nobreak >nul
        if !activeCount! equ 0 exit
    )

    :: Wait for 5 seconds before checking again
    timeout /t 5 /nobreak >nul
goto loop
