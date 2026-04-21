# Azure Functions デプロイスクリプト
# Usage: pwsh ./08-deploy-functions.ps1
$ErrorActionPreference = 'Stop'

# 環境変数の読み込み
$envFile = Join-Path $PSScriptRoot '.azure-env.ps1'
if (Test-Path $envFile) {
    . $envFile
    Write-Host "==> 環境変数を .azure-env.ps1 から読み込み" -ForegroundColor Cyan
}

$ResourceGroup = 'rg-sqlmirror-demo'
$FunctionsDir  = Join-Path $PSScriptRoot '..\..\functions' | Resolve-Path -ErrorAction SilentlyContinue
if (-not $FunctionsDir) {
    $FunctionsDir = Join-Path $PSScriptRoot '..\functions'
}

# Functions App 名を取得
Write-Host "==> Functions App 名を取得中..." -ForegroundColor Cyan
$funcAppName = az functionapp list `
    --resource-group $ResourceGroup `
    --query "[?contains(name, 'sqlmirror')].name" `
    -o tsv

if (-not $funcAppName) {
    throw "Functions App が見つかりません。先に 00-deploy-azure.ps1 を実行してください。"
}
Write-Host "==> Functions App: $funcAppName" -ForegroundColor Cyan

# ビルド
Write-Host "==> Functions プロジェクトをビルド中..." -ForegroundColor Cyan
Push-Location $FunctionsDir
try {
    dotnet publish -c Release -o ./publish
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }

    # デプロイ (zip deploy)
    Write-Host "==> Azure Functions にデプロイ中..." -ForegroundColor Cyan
    $publishDir = Join-Path $FunctionsDir 'publish'
    $zipFile    = Join-Path $FunctionsDir 'publish.zip'

    # 既存の zip があれば削除
    if (Test-Path $zipFile) { Remove-Item $zipFile }

    Compress-Archive -Path "$publishDir\*" -DestinationPath $zipFile -Force

    az functionapp deployment source config-zip `
        --resource-group $ResourceGroup `
        --name $funcAppName `
        --src $zipFile

    if ($LASTEXITCODE -ne 0) { throw "Deployment failed" }

    Write-Host ""
    Write-Host "✅ Functions デプロイ完了" -ForegroundColor Green
    Write-Host "  App Name : $funcAppName" -ForegroundColor Cyan
    Write-Host "  URL      : https://$funcAppName.azurewebsites.net" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Application Insights でログを確認してください。" -ForegroundColor Yellow

} finally {
    Pop-Location
}
