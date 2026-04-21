# Download On-premises Data Gateway installer to the SQL VM and install silently.
# After install, an interactive sign-in is required (run the gateway config UI via RDP).
$ErrorActionPreference = 'Stop'

$dl = 'C:\Temp\GatewayInstall.exe'
New-Item -ItemType Directory -Path C:\Temp -Force | Out-Null

if (-not (Test-Path $dl)) {
    Write-Host "Downloading On-premises Data Gateway..."
    # Stable Microsoft download endpoint
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/D/A/1/DA1FDDB8-6DA8-4F50-B4D0-18019591E182/GatewayInstall.exe' -OutFile $dl
}
Write-Host ("Installer size: {0} bytes" -f (Get-Item $dl).Length)

# Silent install
Write-Host "Running silent install..."
$p = Start-Process -FilePath $dl -ArgumentList '-quiet','-norestart','ACCEPTEULA=yes' -Wait -PassThru
Write-Host "ExitCode=$($p.ExitCode)"

# Verify gateway service
$svc = Get-Service 'PBIEgwService' -ErrorAction SilentlyContinue
if ($svc) { Write-Host "Service: $($svc.Name) - $($svc.Status)" } else { Write-Host "Service not found yet (may need a moment)" }

# Verify GUI launcher exists
$gui = 'C:\Program Files\On-premises data gateway\EnterpriseGatewayConfigurator.exe'
Write-Host "GUI exists: $(Test-Path $gui)"

Write-Host "OPDG_INSTALL_DONE"
