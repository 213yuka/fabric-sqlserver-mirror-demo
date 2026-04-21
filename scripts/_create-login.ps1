$ErrorActionPreference = 'Stop'

# fabric_login をローカル SQL に SYSTEM 権限で作成 (BUILTIN\Administrators が sysadmin)
$pwd = 'F@bric_Strong_Pwd_2026'
$sql = @"
USE [master];
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'fabric_login')
BEGIN
    CREATE LOGIN [fabric_login] WITH PASSWORD = '$pwd', CHECK_POLICY = OFF;
    ALTER SERVER ROLE [sysadmin] ADD MEMBER [fabric_login];
    PRINT 'fabric_login created and added to sysadmin';
END
ELSE
BEGIN
    ALTER LOGIN [fabric_login] WITH PASSWORD = '$pwd';
    ALTER SERVER ROLE [sysadmin] ADD MEMBER [fabric_login];
    PRINT 'fabric_login updated';
END
"@

sqlcmd -S localhost -E -Q $sql

# Force Encryption を OFF にして接続性向上 (デモ用)
$regPath = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\SuperSocketNetLib'
$current = (Get-ItemProperty $regPath -Name ForceEncryption -ErrorAction SilentlyContinue).ForceEncryption
Write-Output "Current ForceEncryption: $current"
if ($current -ne 0) {
    Set-ItemProperty -Path $regPath -Name ForceEncryption -Value 0
    Write-Output "Set ForceEncryption to 0; restarting MSSQLSERVER..."
    Restart-Service MSSQLSERVER -Force
    Restart-Service SQLSERVERAGENT -ErrorAction SilentlyContinue
    Write-Output "Service restarted"
}

# 確認
sqlcmd -S localhost -E -Q "SELECT name FROM sys.server_principals WHERE name='fabric_login'"
Write-Output "Done"
