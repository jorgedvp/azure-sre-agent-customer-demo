#!/usr/bin/env bash
# =============================================================================
# 03-onboard-arc-windows.sh
# Same two-step design as 02-onboard-arc-linux.sh (see notes there): connect
# to Arc first while the native agent can still report back, then disable
# the native agent as a separate --no-wait step.
# =============================================================================
set -euo pipefail

RG="${RG:-rg-sre-customer-demo}"
SUBSCRIPTION="${SUBSCRIPTION:?}"
VM_NAME="${VM_NAME:-vm-onprem-iis}"
LOCATION="${LOCATION:-eastus2}"
SP_NAME="${SP_NAME:-sp-arc-onboard-sredemo}"

if [ -f /tmp/arc_sp_customer_demo.json ]; then
  echo "==> Reusing existing onboarding SP from /tmp/arc_sp_customer_demo.json"
else
  az ad sp create-for-rbac --name "$SP_NAME" --role "Azure Connected Machine Onboarding" \
    --scopes "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG" \
    -o json > /tmp/arc_sp_customer_demo.json
fi
APP_ID=$(python3 -c "import json; print(json.load(open('/tmp/arc_sp_customer_demo.json'))['appId'])")
APP_SECRET=$(python3 -c "import json; print(json.load(open('/tmp/arc_sp_customer_demo.json'))['password'])")
TENANT_ID=$(python3 -c "import json; print(json.load(open('/tmp/arc_sp_customer_demo.json'))['tenant'])")

echo "==> STEP A: Installing azcmagent and connecting to Arc (native agent still active)"
cat > /tmp/onboard-arc-windows-stepA.ps1 <<PS1
\$ErrorActionPreference = "Stop"
Write-Output "--- Downloading and installing Azure Connected Machine agent ---"
Invoke-WebRequest -UseBasicParsing -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile "\$env:TEMP\AzureConnectedMachineAgent.msi"
Start-Process msiexec.exe -ArgumentList "/i \$env:TEMP\AzureConnectedMachineAgent.msi /l*v \$env:TEMP\acm_installation.log /qn" -Wait

Write-Output "--- Connecting to Arc ---"
& "\$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect \`
  --service-principal-id "$APP_ID" \`
  --service-principal-secret "$APP_SECRET" \`
  --resource-group "$RG" \`
  --tenant-id "$TENANT_ID" \`
  --location "$LOCATION" \`
  --subscription-id "$SUBSCRIPTION" \`
  --cloud AzureCloud

Write-Output "--- Arc connect finished ---"
& "\$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" show
PS1

az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --command-id RunPowerShellScript \
  --scripts @/tmp/onboard-arc-windows-stepA.ps1 \
  --subscription "$SUBSCRIPTION" \
  -o json

echo "==> Verifying Arc machine registered"
for i in $(seq 1 10); do
  STATUS=$(az connectedmachine show --resource-group "$RG" --name "$VM_NAME" --subscription "$SUBSCRIPTION" --query status -o tsv 2>/dev/null || echo "NotFound")
  echo "   status: $STATUS"
  if [ "$STATUS" = "Connected" ]; then break; fi
  sleep 15
done

echo "==> STEP B: Simulating on-prem (disables native agent — fired with --no-wait)"
cat > /tmp/onboard-arc-windows-stepB.ps1 <<'PS1B'
New-NetFirewallRule -DisplayName "Block-IMDS" -Direction Outbound -RemoteAddress 169.254.169.254 -Action Block -ErrorAction SilentlyContinue | Out-Null
[Environment]::SetEnvironmentVariable("MSFT_ARC_TEST", "true", "Machine")
Stop-Service RdAgent -ErrorAction SilentlyContinue
Set-Service RdAgent -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service WindowsAzureGuestAgent -ErrorAction SilentlyContinue
Set-Service WindowsAzureGuestAgent -StartupType Disabled -ErrorAction SilentlyContinue
PS1B

az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --command-id RunPowerShellScript \
  --scripts @/tmp/onboard-arc-windows-stepB.ps1 \
  --subscription "$SUBSCRIPTION" \
  --no-wait \
  -o json || true

echo "==> Step B fired with --no-wait (expected to show as stuck on the native resource — harmless)."
echo "    From now on use scripts/run-via-arc.sh for ALL further automation against this VM."
