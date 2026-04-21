# Azure VM 上の SQL Server に AdventureWorksLT2022 を復元
# az vm run-command で VM 内で PowerShell を実行
# Usage: . ./.azure-env.ps1; ./02a-restore-adventureworkslt-azure.ps1

$ErrorActionPreference = 'Stop'

$ResourceGroup = 'rg-sqlmirror-demo'
$VmName        = 'sqlmirror-vm'

$remoteScript = @'
$ErrorActionPreference = "Stop"
$bakUrl   = "https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksLT2022.bak"
$bakLocal = "C:\Backup\AdventureWorksLT2022.bak"

New-Item -ItemType Directory -Path "C:\Backup" -Force | Out-Null
if (-not (Test-Path $bakLocal)) {
    Invoke-WebRequest -Uri $bakUrl -OutFile $bakLocal -UseBasicParsing
}

# SQL Server に SYSTEM 権限で接続して復元
$sql = @"
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
     REPLACE, STATS = 10;';
EXEC sp_executesql @restoreSql;
"@

sqlcmd -S localhost -E -Q $sql
'@

Write-Host "==> VM 内で復元スクリプトを実行 (3-5 分)" -ForegroundColor Cyan
$result = az vm run-command invoke `
    --resource-group $ResourceGroup `
    --name $VmName `
    --command-id RunPowerShellScript `
    --scripts $remoteScript `
    -o json | ConvertFrom-Json

foreach ($msg in $result.value) {
    Write-Host "--- $($msg.code) ---" -ForegroundColor DarkGray
    Write-Host $msg.message
}

Write-Host "✅ 復元コマンド送信完了" -ForegroundColor Green
