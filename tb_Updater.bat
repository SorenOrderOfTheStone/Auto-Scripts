@echo off
setlocal

:: Automatically gets the folder where this batch script is running from
set "AppFolder=%~dp0"
set "LauncherPath=%AppFolder%run_updater.vbs"

:: Register the silent VBS launcher for Windows startup
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "AppMonitorChain" /t REG_SZ /d "wscript.exe \"%LauncherPath%\"" /f >nul 2>&1

:: PowerShell updater wrapped in a background job with a strict 60-second timeout
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$baseUrl = 'https://raw.githubusercontent.com/DanielSour/Auto-Scripts/main';" ^
    "$appDir = '%AppFolder%';" ^
    "$job = Start-Job -ScriptBlock {" ^
    "   param($baseUrl, $appDir)" ^
    "   try {" ^
    "       $listUrl = '{0}/file_list.txt' -f $baseUrl;" ^
    "       $response = Invoke-WebRequest -Uri $listUrl -UseBasicParsing -TimeoutSec 10;" ^
    "       $files = $response.Content -split '\r?\n' | Where-Object { $_ -match '\S' };" ^
    "       foreach ($f in $files) {" ^
    "           $f = $f.Trim();" ^
    "           $fileUrl = '{0}/{1}' -f $baseUrl, $f;" ^
    "           $destPath = Join-Path $appDir $f;" ^
    "           Invoke-WebRequest -Uri $fileUrl -OutFile $destPath -UseBasicParsing -TimeoutSec 10;" ^
    "       }" ^
    "       return $true;" ^
    "   } catch {" ^
    "       return $false;" ^
    "   }" ^
    "} -ArgumentList $baseUrl, $appDir;" ^
    "$finished = Wait-Job $job -Timeout 60;" ^
    "if ($finished) {" ^
    "   Receive-Job $job;" ^
    "   Remove-Job $job;" ^
    "   Stop-Job $job;" ^
    "} else {" ^
    "   Stop-Job $job;" ^
    "   Remove-Job $job;" ^
    "}"

cd /d "%AppFolder%"

:: Launch the VBS script to start the rest of the application scripts
start "" "tb_h_m.vbs"

endlocal
exit