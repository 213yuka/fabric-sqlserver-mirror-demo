# Headless OPDG registration using the DataGateway PowerShell module.
# Outputs a device-login URL+code; the user opens it in their browser to sign in.
# After sign-in, this script creates the gateway cluster and prints its name/id.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# 1) Install the module if missing
if (-not (Get-Module -ListAvailable -Name DataGateway)) {
    Write-Host "Installing DataGateway module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name DataGateway -Force -AllowClobber -Scope AllUsers
}
Import-Module DataGateway

# 2) Sign in via DEVICE CODE — prints URL + code to stdout
Write-Host "=== DEVICE LOGIN START ==="
Connect-DataGatewayServiceAccount -DeviceCode | Out-String | Write-Host
Write-Host "=== DEVICE LOGIN END ==="

# 3) Create the gateway cluster (will fail if name already exists, that's fine)
$gwName = 'sqlmirror-gw'
$recoveryKey = ConvertTo-SecureString 'Recover_Key_2026!' -AsPlainText -Force
try {
    $gw = Add-DataGatewayCluster -RecoveryKey $recoveryKey -Name $gwName -RegionKey 'japaneast' -OverwriteExistingGateway
    Write-Host "GATEWAY_CREATED: $($gw | ConvertTo-Json -Depth 5 -Compress)"
} catch {
    Write-Host "Add-DataGatewayCluster failed: $($_.Exception.Message)"
}

# 4) List clusters this user can see
Get-DataGatewayCluster | Select-Object Name, Id, Region, Status | Format-Table | Out-String | Write-Host

Write-Host "OPDG_HEADLESS_DONE"
