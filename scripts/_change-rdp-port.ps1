# Change RDP port from 3389 to 13389 to bypass ISP blocking of standard RDP
$ErrorActionPreference = 'Stop'
$newPort = 13389
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name PortNumber -Value $newPort
New-NetFirewallRule -DisplayName "RDP-$newPort" -Direction Inbound -Protocol TCP -LocalPort $newPort -Action Allow -ErrorAction SilentlyContinue | Out-Null
Restart-Service TermService -Force
Start-Sleep -Seconds 3
Get-NetTCPConnection -LocalPort $newPort -State Listen -EA SilentlyContinue | Select-Object LocalAddress, LocalPort, State | Format-Table | Out-String | Write-Host
Write-Host "RDP_PORT_CHANGED=$newPort"
