@echo off
cd /d "%~dp0"

:loop
    timeout /t 15 /nobreak >nul

    :: ----------------------------------------------------
    :: Check tb_FolderGuard.ps1
    :: ----------------------------------------------------
    powershell -NoProfile -WindowStyle Hidden -Command ^
        "$running = Get-CimInstance Win32_Process -Filter \"Name = 'powershell.exe'\" | Where-Object { $_.CommandLine -like '*tb_FolderGuard.ps1*' };"^
        "if (-not $running) {"^
        "    Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -WindowStyle Hidden -File tb_FolderGuard.ps1' -WorkingDirectory '%~dp0';"^
        "}"

    :: ----------------------------------------------------
    :: Check tb_AutoShutdown.ps1
    :: ----------------------------------------------------
    powershell -NoProfile -WindowStyle Hidden -Command ^
        "$running = Get-CimInstance Win32_Process -Filter \"Name = 'powershell.exe'\" | Where-Object { $_.CommandLine -like '*tb_AutoShutdown.ps1*' };"^
        "if (-not $running) {"^
        "    Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -WindowStyle Hidden -File tb_AutoShutdown.ps1' -WorkingDirectory '%~dp0';"^
        "}"

goto loop
