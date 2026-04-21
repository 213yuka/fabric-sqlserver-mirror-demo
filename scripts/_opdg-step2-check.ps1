$ErrorActionPreference = 'Continue'
$donFile = 'C:\Temp\opdg-login.done'
$gwFile  = 'C:\Temp\opdg-gw.json'
$logFile = 'C:\Temp\opdg-login.log'

# Wait for the bg job to write the done marker (up to 4 minutes)
for ($i = 0; $i -lt 120; $i++) {
    if (Test-Path $donFile) { break }
    Start-Sleep -Seconds 2
}

Write-Host "===== LOGIN LOG ====="
if (Test-Path $logFile) { Get-Content $logFile | Out-String | Write-Host }
Write-Host "===== GATEWAY RESULT ====="
if (Test-Path $gwFile) { Get-Content $gwFile | Out-String | Write-Host } else { Write-Host "(no gateway file yet)" }
Write-Host "===== /RESULT ====="

# Service status
Get-Service PBIEgwService | Select-Object Name, Status | Format-Table | Out-String | Write-Host
Write-Host "STEP2_DONE"
