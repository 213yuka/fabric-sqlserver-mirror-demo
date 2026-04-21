$ErrorActionPreference = 'Stop'
$logPath = 'C:\Temp\opdg-rr3.log'
$markerPath = 'C:\Temp\opdg-rr3.done'
Remove-Item $logPath, $markerPath -ErrorAction SilentlyContinue
Get-Process pwsh -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID } | Stop-Process -Force -ErrorAction SilentlyContinue

$pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'

# Write a script file then invoke pwsh against it with output redirection at the process level
$scriptFile = 'C:\Temp\opdg-rr3-inner.ps1'
@"
`$ErrorActionPreference='Continue'
Import-Module DataGateway -Force
Connect-DataGatewayServiceAccount -ForceDeviceCodeAuthentication:`$true
Add-DataGatewayCluster -Name 'sqlmirror-gw' -RegionKey 'westus3' -OverwriteExistingGateway -RecoveryKey (ConvertTo-SecureString 'Recover_Key_2026!' -AsPlainText -Force)
Get-DataGatewayCluster | ConvertTo-Json -Depth 5
'DONE_MARKER' | Out-File -FilePath '$markerPath'
"@ | Out-File -FilePath $scriptFile -Encoding utf8

# Use cmd /c to redirect pwsh's stdout AND stderr to file
$cmd = "`"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`" > `"$logPath`" 2>&1"
Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $cmd) -WindowStyle Hidden

$deadline = (Get-Date).AddSeconds(120)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 3
  if (Test-Path $logPath) {
    $content = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
    if ($content -match 'code\s+([A-Z0-9]{8,12})') {
      Write-Output "DEVICE_CODE: $($matches[1])"
      Write-Output "URL: https://login.microsoft.com/device"
      Write-Output "--- log ---"
      Write-Output $content
      exit 0
    }
  }
}
Write-Output "TIMEOUT"
if (Test-Path $logPath) { Get-Content $logPath -Raw }
