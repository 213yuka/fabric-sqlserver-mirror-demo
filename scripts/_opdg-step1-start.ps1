# Step 1: Start headless device-code login in a background process. Print the code.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Install DataGateway module if missing
if (-not (Get-Module -ListAvailable -Name DataGateway)) {
    Write-Host "Installing DataGateway module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Install-Module -Name DataGateway -Force -AllowClobber -Scope AllUsers
}

$logFile = 'C:\Temp\opdg-login.log'
$donFile = 'C:\Temp\opdg-login.done'
$gwFile  = 'C:\Temp\opdg-gw.json'
New-Item -ItemType Directory -Path C:\Temp -Force | Out-Null
Remove-Item $logFile, $donFile, $gwFile -ErrorAction SilentlyContinue

# Background script: device login, then create gateway cluster, then write done marker.
$bgScript = @'
$ErrorActionPreference = 'Continue'
Import-Module DataGateway
try {
    Connect-DataGatewayServiceAccount -DeviceCode *> 'C:\Temp\opdg-login.log'
    $key = ConvertTo-SecureString 'Recover_Key_2026!' -AsPlainText -Force
    try {
        $gw = Add-DataGatewayCluster -RecoveryKey $key -Name 'sqlmirror-gw' -RegionKey 'japaneast' -OverwriteExistingGateway
        $gw | ConvertTo-Json -Depth 5 | Out-File 'C:\Temp\opdg-gw.json' -Encoding utf8
    } catch {
        "ADD_FAILED: $($_.Exception.Message)" | Out-File 'C:\Temp\opdg-gw.json' -Encoding utf8
    }
} catch {
    "LOGIN_FAILED: $($_.Exception.Message)" *>> 'C:\Temp\opdg-login.log'
}
'OK' | Out-File 'C:\Temp\opdg-login.done' -Encoding ascii
'@
Set-Content -Path 'C:\Temp\opdg-bg.ps1' -Value $bgScript -Encoding utf8

Write-Host "Starting background login process..."
Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Temp\opdg-bg.ps1' -WindowStyle Hidden

# Poll log for device code (up to 60s)
$code = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    if (Test-Path $logFile) {
        $content = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
        if ($content -match 'code\s+([A-Z0-9]{8,12})') {
            $code = $Matches[1]
            break
        }
    }
}

Write-Host "===== LOG CONTENT ====="
if (Test-Path $logFile) { Get-Content $logFile | Out-String | Write-Host } else { Write-Host "(log file not yet created)" }
Write-Host "===== /LOG CONTENT ====="
if ($code) { Write-Host "DEVICE_CODE=$code" } else { Write-Host "DEVICE_CODE=(not detected, check log above)" }
Write-Host "DEVICE_LOGIN_URL=https://microsoft.com/devicelogin"
Write-Host "STEP1_DONE"
