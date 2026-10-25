#!/usr/bin/env bash
# =============================================================================
# 05-install-iis.sh
# Installs IIS on vm-onprem-iis and deploys a minimal demo web app used by
# scenario 2 (Application Pool crash / HTTP 500). Executed via Arc Run Command.
# =============================================================================
set -euo pipefail

RG="${RG:-rg-sre-customer-demo}"
SUBSCRIPTION="${SUBSCRIPTION:?}"
VM_NAME="${VM_NAME:-vm-onprem-iis}"
LOCATION="${LOCATION:-eastus2}"

cat > /tmp/install-iis.json <<'EOF'
{
  "script": "Install-WindowsFeature -Name Web-Server,Web-Mgmt-Console,Web-Asp-Net45 -IncludeManagementTools\nImport-Module WebAdministration\n$siteContent = '<html><body><h1>Demo App - OK</h1><p>Server: ' + $env:COMPUTERNAME + '</p></body></html>'\nSet-Content -Path 'C:\\inetpub\\wwwroot\\index.html' -Value $siteContent\nWrite-Output 'IIS_INSTALL_COMPLETE'\nGet-Website | Select-Object Name, State\nGet-WebAppPoolState -Name 'DefaultAppPool'"
}
EOF

echo "==> Installing IIS on ${VM_NAME} via Arc Run Command (this takes 2-4 minutes)"
az connectedmachine run-command create \
  --resource-group "$RG" \
  --machine-name "$VM_NAME" \
  --name install-iis \
  --location "$LOCATION" \
  --source @/tmp/install-iis.json \
  --timeout-in-seconds 240 \
  --subscription "$SUBSCRIPTION" \
  -o json

echo "==> IIS installation complete. Default site serving a minimal demo page."
