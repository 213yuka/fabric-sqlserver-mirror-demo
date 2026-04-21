# Install PowerShell 7 on the VM
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if (Test-Path 'C:\Program Files\PowerShell\7\pwsh.exe') {
    & 'C:\Program Files\PowerShell\7\pwsh.exe' -Command '$PSVersionTable.PSVersion'
    Write-Host "ALREADY_INSTALLED"
    return
}

$msi = 'C:\Temp\PowerShell-7.4.6-win-x64.msi'
New-Item -ItemType Directory -Path C:\Temp -Force | Out-Null
Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi' -OutFile $msi
Write-Host "Downloaded $((Get-Item $msi).Length) bytes"

$p = Start-Process msiexec.exe -ArgumentList "/package $msi /quiet ADD_PATH=1" -Wait -PassThru
Write-Host "Install exit code: $($p.ExitCode)"
& 'C:\Program Files\PowerShell\7\pwsh.exe' -Command '$PSVersionTable.PSVersion'
Write-Host "PWSH7_INSTALLED"
