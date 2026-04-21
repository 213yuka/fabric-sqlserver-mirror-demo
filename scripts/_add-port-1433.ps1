# Add TCP 1433 to SQL Server's listening ports (in addition to 11433)
$ErrorActionPreference = 'Stop'

# Update IPAll TcpPort via registry (SQL2022 default instance)
$base = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
Set-ItemProperty -Path $base -Name TcpPort -Value '1433,11433'
Set-ItemProperty -Path $base -Name TcpDynamicPorts -Value ''

Write-Host "Registry updated. Restarting MSSQLSERVER..."
Restart-Service -Name MSSQLSERVER -Force
Start-Sleep -Seconds 5
Restart-Service -Name SQLSERVERAGENT -Force -ErrorAction SilentlyContinue

# Add Windows Firewall rule for 1433
New-NetFirewallRule -DisplayName 'SQL-1433' -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -ErrorAction SilentlyContinue | Out-Null

# Verify both ports are listening
Get-NetTCPConnection -LocalPort 1433,11433 -State Listen -ErrorAction SilentlyContinue |
    Select-Object LocalAddress, LocalPort, State |
    Format-Table | Out-String | Write-Host

Write-Host "DONE"
