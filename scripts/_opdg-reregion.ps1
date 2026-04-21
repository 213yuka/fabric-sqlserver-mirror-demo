$ErrorActionPreference = 'Stop'
$logPath = 'C:\Temp\opdg-reregion.log'
$markerPath = 'C:\Temp\opdg-reregion.done'
Remove-Item $logPath, $markerPath -ErrorAction SilentlyContinue

$pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
$inner = @"
`$ErrorActionPreference='Continue'
Start-Transcript -Path '$logPath' -Force | Out-Null
try {
  Import-Module DataGateway -Force
  Connect-DataGatewayServiceAccount -ForceDeviceCodeAuthentication:`$true
  # Try to remove old (best-effort) and re-create in westus3
  try {
    `$g = Get-DataGatewayCluster | Where-Object { `$_.Name -eq 'sqlmirror-gw' }
    if (`$g) {
      Write-Host "Existing gateway found: `$(`$g.Id) region=`$(`$g.Region)"
    }
  } catch { Write-Host "List error: `$(`$_.Exception.Message)" }
  Add-DataGatewayCluster -Name 'sqlmirror-gw' -RegionKey 'westus3' -OverwriteExistingGateway -RecoveryKey (ConvertTo-SecureString 'Recover_Key_2026!' -AsPlainText -Force)
  Get-DataGatewayCluster | ConvertTo-Json -Depth 5
} catch {
  Write-Host "ERROR: `$(`$_.Exception.Message)"
} finally {
  New-Item -Path '$markerPath' -ItemType File -Force | Out-Null
  Stop-Transcript | Out-Null
}
"@
$encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($inner))
Start-Process -FilePath $pwsh -ArgumentList @('-NoProfile','-EncodedCommand', $encoded) -WindowStyle Hidden

# Wait for device code
$deadline = (Get-Date).AddSeconds(120)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 3
  if (Test-Path $logPath) {
    $code = (Select-String -Path $logPath -Pattern 'code\s+([A-Z0-9]{8,12})' -AllMatches).Matches | Select-Object -First 1
    if ($code) {
      Write-Output "DEVICE_CODE: $($code.Groups[1].Value)"
      Get-Content $logPath -Tail 30
      exit 0
    }
  }
}
Write-Output "TIMEOUT waiting for device code"
if (Test-Path $logPath) { Get-Content $logPath -Tail 50 }
