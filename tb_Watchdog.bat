@echo off
cd /d "%~dp0"

:loop
    timeout /t 15 /nobreak >nul

    :: ----------------------------------------------------
    :: Check & Restart tb_FolderGuard.ps1
    :: ----------------------------------------------------
    powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Select-Object -ExpandProperty CommandLine" 2>nul | findstr /i "tb_FolderGuard.ps1" >nul
    if errorlevel 1 (
        start /min "" powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0tb_FolderGuard.ps1"
    )

    :: ----------------------------------------------------
    :: Check & Restart tb_AutoShutdown.ps1
    :: ----------------------------------------------------
    powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Select-Object -ExpandProperty CommandLine" 2>nul | findstr /i "tb_AutoShutdown.ps1" >nul
    if errorlevel 1 (
        start /min "" powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0tb_AutoShutdown.ps1"
    )

goto loop
