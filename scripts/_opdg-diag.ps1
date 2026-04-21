$ErrorActionPreference = 'Continue'
Write-Host "PSVersion: $($PSVersionTable.PSVersion)"
Write-Host "PSEdition: $($PSVersionTable.PSEdition)"
Write-Host "CLR: $($PSVersionTable.CLRVersion)"
Write-Host ""
Write-Host "--- DataGateway modules ---"
Get-Module -ListAvailable DataGateway* | Select-Object Name, Version, ModuleBase | Format-Table | Out-String | Write-Host
Write-Host "--- Try import ---"
try {
    Import-Module DataGateway.Profile -ErrorAction Stop -Verbose 4>&1 | Select-Object -Last 30 | Out-String | Write-Host
} catch {
    Write-Host "ERR: $($_.Exception.Message)"
    Write-Host "INNER: $($_.Exception.InnerException.Message)"
}
