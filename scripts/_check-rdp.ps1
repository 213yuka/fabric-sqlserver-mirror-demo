$ErrorActionPreference = 'Continue'
$svc = Get-Service TermService
Write-Host "TermService=$($svc.Status)"
$rdp = (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections).fDenyTSConnections
Write-Host "fDenyTSConnections=$rdp"
Get-NetFirewallRule -DisplayGroup 'Remote Desktop' | Select-Object DisplayName, Enabled, Profile | Format-Table | Out-String | Write-Host
Get-NetTCPConnection -LocalPort 3389 -State Listen -EA SilentlyContinue | Select-Object LocalAddress, LocalPort, State | Format-Table | Out-String | Write-Host
