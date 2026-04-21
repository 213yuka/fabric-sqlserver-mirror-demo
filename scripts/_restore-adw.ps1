$ErrorActionPreference = "Stop"
$bakUrl   = "https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksLT2022.bak"
$bakLocal = "C:\Backup\AdventureWorksLT2022.bak"

New-Item -ItemType Directory -Path "C:\Backup" -Force | Out-Null
if (-not (Test-Path $bakLocal)) {
    Write-Output "Downloading $bakUrl ..."
    Invoke-WebRequest -Uri $bakUrl -OutFile $bakLocal -UseBasicParsing
}
Write-Output ("Backup file size: " + (Get-Item $bakLocal).Length + " bytes")

$sql = @"
SET NOCOUNT ON;
USE [master];
IF DB_ID('AdventureWorksLT2022') IS NOT NULL
BEGIN
    ALTER DATABASE [AdventureWorksLT2022] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [AdventureWorksLT2022];
END

DECLARE @data NVARCHAR(500), @log NVARCHAR(500);
SELECT @data = SUBSTRING(physical_name, 1, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
FROM sys.master_files WHERE database_id = DB_ID('master') AND type = 0;
SELECT @log = SUBSTRING(physical_name, 1, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
FROM sys.master_files WHERE database_id = DB_ID('master') AND type = 1;

DECLARE @restoreSql NVARCHAR(MAX) = N'
RESTORE DATABASE [AdventureWorksLT2022] FROM DISK = N''C:\Backup\AdventureWorksLT2022.bak''
WITH MOVE ''AdventureWorksLT2022_Data'' TO ''' + @data + 'AdventureWorksLT2022.mdf'',
     MOVE ''AdventureWorksLT2022_Log''  TO ''' + @log  + 'AdventureWorksLT2022_log.ldf'',
     REPLACE, STATS = 25;';
EXEC sp_executesql @restoreSql;

SELECT name, state_desc FROM sys.databases WHERE name='AdventureWorksLT2022';
"@

sqlcmd -S localhost -U fabric_login -P 'F@bric_Strong_Pwd_2026' -C -b -Q $sql
if ($LASTEXITCODE -ne 0) { throw "Restore failed (exit $LASTEXITCODE)" }
Write-Output "RESTORE_DONE"
