$r = Get-NetFirewallRule -DisplayName 'SQL Server Database Engine (TCP-In)' -ErrorAction SilentlyContinue
if ($r) {
  $f = $r | Get-NetFirewallPortFilter
  Write-Output ("SQL Engine TCP-In: enabled=$($r.Enabled) dir=$($r.Direction) act=$($r.Action) port=$($f.LocalPort)")
} else {
  Write-Output "no rule named 'SQL Server Database Engine (TCP-In)'"
}
Write-Output "--- all SQL rules ---"
Get-NetFirewallRule -DisplayName '*SQL*' | ForEach-Object {
  $rule = $_
  $pf = $rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
  Write-Output ("$($rule.DisplayName) | en=$($rule.Enabled) dir=$($rule.Direction) act=$($rule.Action) port=$($pf.LocalPort)")
}
Write-Output "--- create rule for 11433 if missing ---"
if (-not (Get-NetFirewallRule -DisplayName 'SQL-11433' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName 'SQL-11433' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 11433 -Profile Any | Out-Null
  Write-Output "created SQL-11433"
} else { Write-Output "SQL-11433 exists" }
