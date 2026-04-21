# Wrapper that re-launches itself in pwsh7 to use the DataGateway module.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
$logFile = 'C:\Temp\opdg-login.log'
$donFile = 'C:\Temp\opdg-login.done'
$gwFile  = 'C:\Temp\opdg-gw.json'
New-Item -ItemType Directory -Path C:\Temp -Force | Out-Null
Remove-Item $logFile, $donFile, $gwFile -ErrorAction SilentlyContinue

# Background script content (runs under pwsh7)
$bg = @'
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
if (-not (Get-Module -ListAvailable -Name DataGateway)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Install-Module -Name DataGateway -Force -AllowClobber -Scope AllUsers
}
Import-Module DataGateway
try {
    Connect-DataGatewayServiceAccount -ForceDeviceCodeAuthentication:$true *> 'C:\Temp\opdg-login.log'
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
Set-Content -Path 'C:\Temp\opdg-bg.ps1' -Value $bg -Encoding utf8

Write-Host "Launching background pwsh7..."
Start-Process -FilePath $pwsh -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Temp\opdg-bg.ps1' -WindowStyle Hidden

# Poll log for device code (up to 120s — module may need to install first)
$code = $null
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 2
    if (Test-Path $logFile) {
        $content = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
        if ($content -match 'code\s+([A-Z0-9]{8,12})') {
            $code = $Matches[1]
            break
        }
    }
}

Write-Host "===== LOG ====="
if (Test-Path $logFile) { Get-Content $logFile | Out-String | Write-Host } else { Write-Host "(no log yet)" }
Write-Host "===== /LOG ====="
if ($code) { Write-Host "DEVICE_CODE=$code" } else { Write-Host "DEVICE_CODE=(not detected)" }
Write-Host "URL=https://microsoft.com/devicelogin"
Write-Host "STEP1_DONE"
