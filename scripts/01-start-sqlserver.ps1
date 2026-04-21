# SQL Server 2022 Developer (Docker) を起動
# Usage: pwsh ./01-start-sqlserver.ps1

$ErrorActionPreference = 'Stop'

$ContainerName = 'sqlserver-mirror'
$SaPassword    = 'P@ssw0rd!Demo'
$Image         = 'mcr.microsoft.com/mssql/server:2022-latest'
$Port          = 1433

Write-Host "==> Docker の存在確認" -ForegroundColor Cyan
docker version | Out-Null

# 既存コンテナーの掃除
$existing = docker ps -a --filter "name=^/$ContainerName$" --format '{{.Names}}'
if ($existing -eq $ContainerName) {
    Write-Host "==> 既存コンテナー '$ContainerName' を削除" -ForegroundColor Yellow
    docker rm -f $ContainerName | Out-Null
}

Write-Host "==> SQL Server 2022 イメージを取得" -ForegroundColor Cyan
docker pull $Image

Write-Host "==> コンテナー起動 (Port=$Port)" -ForegroundColor Cyan
docker run -d `
    --name $ContainerName `
    -e 'ACCEPT_EULA=Y' `
    -e "MSSQL_SA_PASSWORD=$SaPassword" `
    -e 'MSSQL_PID=Developer' `
    -e 'MSSQL_AGENT_ENABLED=true' `
    -p "${Port}:1433" `
    $Image | Out-Null

Write-Host "==> 起動を待機 (最大60秒)" -ForegroundColor Cyan
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    $logs = docker logs $ContainerName 2>&1 | Out-String
    if ($logs -match 'SQL Server is now ready for client connections') {
        $ready = $true
        break
    }
}

if (-not $ready) {
    Write-Host "❌ 起動失敗。docker logs $ContainerName を確認してください" -ForegroundColor Red
    exit 1
}

Write-Host "✅ SQL Server 2022 起動完了" -ForegroundColor Green
Write-Host ""
Write-Host "接続情報:" -ForegroundColor Cyan
Write-Host "  Server   : localhost,$Port"
Write-Host "  User     : sa"
Write-Host "  Password : $SaPassword"
Write-Host "  Database : master"
Write-Host ""
Write-Host "次のステップ: ./02-restore-adventureworkslt.ps1" -ForegroundColor Yellow
