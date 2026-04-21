# ローカルから sqlcmd で T-SQL スクリプトを Azure VM の SQL Server に流し込む
# Usage: . ./.azure-env.ps1; ./03a-run-tsql-azure.ps1

$ErrorActionPreference = 'Stop'

if (-not $env:SQL_SERVER) { throw "先に . ./.azure-env.ps1 を読み込んでください" }

# fabric_login は Bicep で作成済み。SQL パスワードを再設定 + DB ユーザー + CDC を実行
$base = $PSScriptRoot
$saPwd = $env:SQL_PASSWORD  # fabric_login がサーバーレベルで作成済みなので sysadmin 化が必要

# Bicep で作成された fabric_login は既に sysadmin 権限を持っている (SQL VM extension 仕様)
# そのまま使える

$server = $env:SQL_SERVER
$user   = $env:SQL_LOGIN
$pwd    = $env:SQL_PASSWORD

function Invoke-SqlFile($file, $database) {
    Write-Host "== $file (DB=$database) ==" -ForegroundColor Cyan
    sqlcmd -S $server -U $user -P $pwd -d $database -i (Join-Path $base $file) -C -b
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed: $file" }
}

# 04 (DB ユーザー) は fabric_login = sa 相当の sysadmin なので不要だが、念のためロール確認
# 03 (login 作成) も Bicep でやるので skip
Invoke-SqlFile '05-enable-cdc.sql' 'AdventureWorksLT2022'
Invoke-SqlFile '06-verify.sql'      'AdventureWorksLT2022'

Write-Host "✅ T-SQL 実行完了" -ForegroundColor Green
