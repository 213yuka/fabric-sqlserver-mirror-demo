$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
$logFile = 'C:\Temp\opdg-rr-login.log'
$donFile = 'C:\Temp\opdg-rr-login.done'
$gwFile  = 'C:\Temp\opdg-rr-gw.json'
New-Item -ItemType Directory -Path C:\Temp -Force | Out-Null
Remove-Item $logFile, $donFile, $gwFile -ErrorAction SilentlyContinue

# Kill any lingering pwsh from prior attempts
Get-Process pwsh -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID } | Stop-Process -Force -ErrorAction SilentlyContinue

$bg = @'
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
Import-Module DataGateway
try {
    Connect-DataGatewayServiceAccount -ForceDeviceCodeAuthentication:$true *> 'C:\Temp\opdg-rr-login.log'
    $key = ConvertTo-SecureString 'Recover_Key_2026!' -AsPlainText -Force
    try {
        $gw = Add-DataGatewayCluster -RecoveryKey $key -Name 'sqlmirror-gw' -RegionKey 'westus3' -OverwriteExistingGateway
        $gw | ConvertTo-Json -Depth 5 | Out-File 'C:\Temp\opdg-rr-gw.json' -Encoding utf8
    } catch {
        "ADD_FAILED: $($_.Exception.Message)" | Out-File 'C:\Temp\opdg-rr-gw.json' -Encoding utf8
    }
} catch {
    "LOGIN_FAILED: $($_.Exception.Message)" *>> 'C:\Temp\opdg-rr-login.log'
}
'OK' | Out-File 'C:\Temp\opdg-rr-login.done' -Encoding ascii
'@
Set-Content -Path 'C:\Temp\opdg-rr-bg.ps1' -Value $bg -Encoding utf8

Start-Process -FilePath $pwsh -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Temp\opdg-rr-bg.ps1' -WindowStyle Hidden

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
if (Test-Path $logFile) { Get-Content $logFile | Out-String | Write-Host }
Write-Host "===== /LOG ====="
if ($code) { Write-Host "DEVICE_CODE=$code" } else { Write-Host "DEVICE_CODE=(not detected)" }
Write-Host "URL=https://microsoft.com/devicelogin"
