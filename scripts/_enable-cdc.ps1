$ErrorActionPreference = "Stop"

# Ensure SQL Server Agent is running (required for CDC capture jobs)
$agent = Get-Service -Name SQLSERVERAGENT -ErrorAction SilentlyContinue
if ($agent) {
    if ($agent.StartType -ne 'Automatic') { Set-Service SQLSERVERAGENT -StartupType Automatic }
    if ($agent.Status -ne 'Running')      { Start-Service SQLSERVERAGENT }
    Write-Output ("SQLSERVERAGENT: " + (Get-Service SQLSERVERAGENT).Status)
} else {
    Write-Output "WARN: SQLSERVERAGENT not installed?"
}

$sql = @"
SET NOCOUNT ON;

-- Snapshot isolation (required by Fabric mirroring)
USE [master];
ALTER DATABASE [AdventureWorksLT2022] SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE [AdventureWorksLT2022] SET READ_COMMITTED_SNAPSHOT ON WITH NO_WAIT;

USE [AdventureWorksLT2022];

-- DB-level CDC
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'AdventureWorksLT2022' AND is_cdc_enabled = 1)
BEGIN
    EXEC sys.sp_cdc_enable_db;
    PRINT 'CDC enabled on database.';
END

-- Enable CDC on every SalesLT.* table
DECLARE @schema sysname = N'SalesLT';
DECLARE @table  sysname;

DECLARE c CURSOR FOR
    SELECT t.name FROM sys.tables t
    WHERE t.schema_id = SCHEMA_ID(@schema)
      AND NOT EXISTS (SELECT 1 FROM cdc.change_tables ct WHERE ct.source_object_id = t.object_id);
OPEN c;
FETCH NEXT FROM c INTO @table;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC sys.sp_cdc_enable_table
            @source_schema = @schema,
            @source_name   = @table,
            @role_name     = NULL,
            @supports_net_changes = 0;
        PRINT N'CDC enabled: ' + @schema + N'.' + @table;
    END TRY
    BEGIN CATCH
        PRINT N'CDC skipped: ' + @schema + N'.' + @table + N' (' + ERROR_MESSAGE() + N')';
    END CATCH
    FETCH NEXT FROM c INTO @table;
END
CLOSE c; DEALLOCATE c;

-- Verify
SELECT 'DB CDC=' + CAST(is_cdc_enabled AS VARCHAR) + '; SnapshotIsolation=' + CAST(snapshot_isolation_state AS VARCHAR) + '; RCSI=' + CAST(is_read_committed_snapshot_on AS VARCHAR)
FROM sys.databases WHERE name='AdventureWorksLT2022';

SELECT capture_instance + ' <- ' + OBJECT_SCHEMA_NAME(source_object_id) + '.' + OBJECT_NAME(source_object_id) FROM cdc.change_tables;
"@

sqlcmd -S localhost -U fabric_login -P 'F@bric_Strong_Pwd_2026' -C -h-1 -W -b -Q $sql
if ($LASTEXITCODE -ne 0) { throw "CDC setup failed (exit $LASTEXITCODE)" }
Write-Output "CDC_DONE"
