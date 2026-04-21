$ErrorActionPreference = 'Stop'
$logPath = 'C:\Temp\opdg-rr2.log'
$markerPath = 'C:\Temp\opdg-rr2.done'
Remove-Item $logPath, $markerPath -ErrorAction SilentlyContinue
'' | Out-File -FilePath $logPath -Encoding utf8

$pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
# Inner script writes everything (including Console.Out) to the file
$inner = @"
`$ErrorActionPreference='Continue'
# Redirect both stdout and stderr stream to file
`$ws = [System.IO.StreamWriter]::new('$logPath', `$true)
`$ws.AutoFlush = `$true
[System.Console]::SetOut(`$ws)
[System.Console]::SetError(`$ws)
try {
  Import-Module DataGateway -Force *>&1 | Out-File -FilePath '$logPath' -Append -Encoding utf8
  Connect-DataGatewayServiceAccount -ForceDeviceCodeAuthentication:`$true *>&1 | Out-File -FilePath '$logPath' -Append -Encoding utf8
  Add-DataGatewayCluster -Name 'sqlmirror-gw' -RegionKey 'westus3' -OverwriteExistingGateway -RecoveryKey (ConvertTo-SecureString 'Recover_Key_2026!' -AsPlainText -Force) *>&1 | Out-File -FilePath '$logPath' -Append -Encoding utf8
  Get-DataGatewayCluster | ConvertTo-Json -Depth 5 | Out-File -FilePath '$logPath' -Append -Encoding utf8
} catch {
  "ERROR: `$(`$_.Exception.Message)" | Out-File -FilePath '$logPath' -Append -Encoding utf8
}
New-Item -Path '$markerPath' -ItemType File -Force | Out-Null
"@
$encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($inner))
Start-Process -FilePath $pwsh -ArgumentList @('-NoProfile','-EncodedCommand', $encoded) -WindowStyle Hidden

$deadline = (Get-Date).AddSeconds(120)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 3
  if (Test-Path $logPath) {
    $content = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
    if ($content -match 'code\s+([A-Z0-9]{8,12})') {
      Write-Output "DEVICE_CODE: $($matches[1])"
      Write-Output "URL: https://login.microsoft.com/device"
      Write-Output "--- log tail ---"
      Get-Content $logPath -Tail 30
      exit 0
    }
  }
}
Write-Output "TIMEOUT"
if (Test-Path $logPath) { Get-Content $logPath -Tail 50 }
