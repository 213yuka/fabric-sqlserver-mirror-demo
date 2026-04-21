$svc = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
Write-Output "MSSQLSERVER status: $($svc.Status)"
$tcp = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\SuperSocketNetLib\Tcp' -ErrorAction SilentlyContinue
Write-Output "TCP Enabled: $($tcp.Enabled)"
$ipall = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\SuperSocketNetLib\Tcp\IPAll' -ErrorAction SilentlyContinue
Write-Output "TCP Port (IPAll): $($ipall.TcpPort) Dyn: $($ipall.TcpDynamicPorts)"
$auth = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer' -Name LoginMode -ErrorAction SilentlyContinue
Write-Output "LoginMode (1=Win,2=Mixed): $($auth.LoginMode)"
Write-Output "--- netstat 1433 ---"
netstat -an | Select-String ":1433"
Write-Output "--- firewall ---"
Get-NetFirewallRule -DisplayName "*SQL*" -ErrorAction SilentlyContinue | Select-Object DisplayName,Enabled,Direction,Action | Format-Table -AutoSize | Out-String
Write-Output "--- check fabric_login ---"
sqlcmd -S localhost -E -Q "SELECT name, type_desc FROM sys.server_principals WHERE name='fabric_login' OR type='S'" -h-1
