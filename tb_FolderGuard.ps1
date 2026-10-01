# Save current Process ID for the watchdog
$PID | Out-File -FilePath (Join-Path $PSScriptRoot "guard.pid") -Force

# Dynamically target the parent folder
$TargetFolder = Split-Path -Parent $PSScriptRoot
$targetUri = ([uri]$TargetFolder).AbsoluteUri
$hbFile = Join-Path $PSScriptRoot "guard_hb.tmp"

while ($true) {
    try {
        Get-Date | Out-File -FilePath $hbFile -Force

        $shell = New-Object -ComObject Shell.Application
        $windows = $shell.Windows()

        foreach ($window in $windows) {
            if ($window.LocationURL -and $window.LocationURL.StartsWith($targetUri, [System.StringComparison]::OrdinalIgnoreCase)) {
                $window.Quit()
            }
        }
    }
    catch {
        # Suppress transient errors
    }

    Start-Sleep -Milliseconds 300
}