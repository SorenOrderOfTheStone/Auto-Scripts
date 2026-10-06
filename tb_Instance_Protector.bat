@echo off
setlocal enabledelayedexpansion

:: Ensure the script runs from its own directory
cd /d "%~dp0"

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

    :: 2. Check tb_Watchdog.bat (running under cmd.exe)
    set count=0
    for /f "tokens=2,*" %%a in ('tasklist /fi "imagename eq cmd.exe" /v /fo csv 2^>nul') do (
        echo %%b | findstr /i "tb_Watchdog.bat" >nul
        if not errorlevel 1 (
            set /a count+=1
            if !count! gtr 1 (
                taskkill /pid %%a /f >nul 2>&1
            )
        )
    )
    set /a activeCount+=count

    :: 3. Check tb_AutoShutdown.ps1 (running under powershell.exe)
    set count=0
    for /f "tokens=2,*" %%a in ('tasklist /fi "imagename eq powershell.exe" /v /fo csv 2^>nul') do (
        echo %%b | findstr /i "tb_AutoShutdown.ps1" >nul
        if not errorlevel 1 (
            set /a count+=1
            if !count! gtr 1 (
                taskkill /pid %%a /f >nul 2>&1
            )
        )
    )
    set /a activeCount+=count

    :: 4. Check tb_FolderGuard.ps1 (running under powershell.exe)
    set count=0
    for /f "tokens=2,*" %%a in ('tasklist /fi "imagename eq powershell.exe" /v /fo csv 2^>nul') do (
        echo %%b | findstr /i "tb_FolderGuard.ps1" >nul
        if not errorlevel 1 (
            set /a count+=1
            if !count! gtr 1 (
                taskkill /pid %%a /f >nul 2>&1
            )
        )
    )
    set /a activeCount+=count

    :: If zero tracked processes are running anywhere, exit protector
    if !activeCount! equ 0 (
        exit
    )

    :: Wait for 2 seconds before checking again
    timeout /t 2 /nobreak >nul
goto loop