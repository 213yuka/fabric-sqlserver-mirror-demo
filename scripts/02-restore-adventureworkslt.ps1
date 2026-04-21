# AdventureWorksLT2022 を SQL Server コンテナーへ復元
# Usage: pwsh ./02-restore-adventureworkslt.ps1

$ErrorActionPreference = 'Stop'

$ContainerName = 'sqlserver-mirror'
$SaPassword    = 'P@ssw0rd!Demo'
$BakUrl        = 'https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksLT2022.bak'
$BakLocal      = Join-Path $PSScriptRoot 'AdventureWorksLT2022.bak'
$BakInContainer = '/var/opt/mssql/backup/AdventureWorksLT2022.bak'

if (-not (Test-Path $BakLocal)) {
    Write-Host "==> .bak をダウンロード" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $BakUrl -OutFile $BakLocal
}

Write-Host "==> コンテナーへコピー" -ForegroundColor Cyan
docker exec $ContainerName mkdir -p /var/opt/mssql/backup | Out-Null
docker cp $BakLocal "${ContainerName}:$BakInContainer"

$restoreSql = @"
USE [master];
IF DB_ID('AdventureWorksLT2022') IS NOT NULL
BEGIN
    ALTER DATABASE [AdventureWorksLT2022] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [AdventureWorksLT2022];
END

RESTORE DATABASE [AdventureWorksLT2022]
FROM DISK = N'$BakInContainer'
WITH MOVE 'AdventureWorksLT2022_Data' TO '/var/opt/mssql/data/AdventureWorksLT2022.mdf',
     MOVE 'AdventureWorksLT2022_Log'  TO '/var/opt/mssql/data/AdventureWorksLT2022_log.ldf',
     REPLACE, STATS = 10;
"@

Write-Host "==> RESTORE 実行" -ForegroundColor Cyan
docker exec -i $ContainerName /opt/mssql-tools18/bin/sqlcmd `
    -S localhost -U sa -P $SaPassword -C `
    -Q $restoreSql

Write-Host "✅ AdventureWorksLT2022 復元完了" -ForegroundColor Green
Write-Host ""
Write-Host "次のステップ: SSMS / VS Code MSSQL から 03-fabric-login.sql を実行" -ForegroundColor Yellow
