@echo off
cd /d "%~dp0"

:loop
timeout /t 15 /nobreak >nul

:: ----------------------------------------------------
:: Check & Restart tb_FolderGuard.ps1 via PID & Heartbeat
:: ----------------------------------------------------
powershell -NoProfile -Command ^
    "$scriptDir = '%~dp0';"^
    "$pidFile = Join-Path $scriptDir 'guard.pid';"^
    "$hbFile = Join-Path $scriptDir 'guard_hb.tmp';"^
    "$restart = $false;"^
    "if (-not (Test-Path $pidFile)) { $restart = $true }"^
    "else {"^
    "    $pIdNum = Get-Content $pidFile -ErrorAction SilentlyContinue;"^
    "    $proc = Get-Process -Id $pIdNum -ErrorAction SilentlyContinue;"^
    "    if (-not $proc) { $restart = $true }"^
    "}"^
    "if (-not $restart -and (Test-Path $hbFile)) {"^
    "    if (((Get-Date) - (Get-Item $hbFile).LastWriteTime).TotalSeconds -gt 35) { $restart = $true }"^
    "}"^
    "if ($restart) {"^
    "    Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -WindowStyle Hidden -File tb_FolderGuard.ps1' -WorkingDirectory $scriptDir;"^
    "}"

:: ----------------------------------------------------
:: Check & Restart tb_AutoShutdown.ps1 via PID & Heartbeat
:: ----------------------------------------------------
powershell -NoProfile -Command ^
    "$scriptDir = '%~dp0';"^
    "$pidFile = Join-Path $scriptDir 'shutdown.pid';"^
    "$hbFile = Join-Path $scriptDir 'shutdown_hb.tmp';"^
    "$restart = $false;"^
    "if (-not (Test-Path $pidFile)) { $restart = $true }"^
    "else {"^
    "    $pIdNum = Get-Content $pidFile -ErrorAction SilentlyContinue;"^
    "    $proc = Get-Process -Id $pIdNum -ErrorAction SilentlyContinue;"^
    "    if (-not $proc) { $restart = $true }"^
    "}"^
    "if (-not $restart -and (Test-Path $hbFile)) {"^
    "    if (((Get-Date) - (Get-Item $hbFile).LastWriteTime).TotalSeconds -gt 35) { $restart = $true }"^
    "}"^
    "if ($restart) {"^
    "    Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -WindowStyle Hidden -File tb_AutoShutdown.ps1' -WorkingDirectory $scriptDir;"^
    "}"

goto loop
