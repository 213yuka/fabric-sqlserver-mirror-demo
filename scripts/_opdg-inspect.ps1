$pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
$inner = @'
Import-Module DataGateway
$cmd = Get-Command Connect-DataGatewayServiceAccount
"Parameters: " + ($cmd.Parameters.Keys -join ', ')
"---"
$cmd.ParameterSets | ForEach-Object { $_.Name + ": " + ($_.Parameters.Name -join ', ') }
'@
Set-Content -Path C:\Temp\inspect.ps1 -Value $inner -Encoding utf8
& $pwsh -NoProfile -ExecutionPolicy Bypass -File C:\Temp\inspect.ps1
