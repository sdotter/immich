#requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

# ----- Settings -----
$Distro   = "Ubuntu"
$ListenIp = "immich"
$Port     = 443

# ----- Get current WSL IP -----
$WslIp = (wsl -d $Distro -- bash -lc "ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'").Trim()
if ([string]::IsNullOrWhiteSpace($WslIp)) {
  throw "Could not determine WSL IP for distro '$Distro'"
}

# ----- Ensure IP Helper is running (needed for portproxy) -----
$svc = Get-Service iphlpsvc
if ($svc.Status -ne "Running") {
  Set-Service iphlpsvc -StartupType Automatic
  Start-Service iphlpsvc
}

# ----- Firewall rule (idempotent) -----
$fwName = "Immich $Port"
if (-not (Get-NetFirewallRule -DisplayName $fwName -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName $fwName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port | Out-Null
}

# ----- Portproxy: delete then add (idempotent) -----
# Delete may fail if rule doesn't exist; ignore that.
& netsh interface portproxy delete v4tov4 listenaddress=$ListenIp listenport=$Port 2>$null | Out-Null

& netsh interface portproxy add v4tov4 `
  listenaddress=$ListenIp listenport=$Port `
  connectaddress=$WslIp connectport=$Port | Out-Null

# Optional: show who is listening now
Write-Host "Listeners on port ${Port}:"
netstat -ano | findstr ":$Port"

Write-Host ("`nImmich forwarded: http://{0}:{1}  -->  {2}:{1}" -f $ListenIp, $Port, $WslIp)

Read-Host "`nPress Enter to exit"