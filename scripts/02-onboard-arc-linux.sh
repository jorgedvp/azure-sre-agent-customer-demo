#!/usr/bin/env bash
# =============================================================================
# 02-onboard-arc-linux.sh
#
# IMPORTANT DESIGN NOTE (lesson learned building this lab):
# Arc onboarding is split into TWO separate run-command invocations:
#   Step A) Install azcmagent + connect to Arc (native guest agent still
#           active, so the result is reported back normally).
#   Step B) THEN disable the native guest agent + block IMDS + set
#           MSFT_ARC_TEST (the "simulate on-prem" step). This step disables
#           the very channel that reports results, so it is fired with
#           --no-wait and verified independently via `az connectedmachine show`
#           instead of waiting for the native run-command to return — doing
#           both in one script creates a deadlock where the agent disables
#           itself before it can report success, and the CLI call hangs
#           until the VM-level operation times out server-side.
# =============================================================================
set -euo pipefail

RG="${RG:-rg-sre-customer-demo}"
SUBSCRIPTION="${SUBSCRIPTION:?}"
VM_NAME="${VM_NAME:-vm-onprem-sql}"
LOCATION="${LOCATION:-eastus2}"
SP_NAME="${SP_NAME:-sp-arc-onboard-sredemo}"

echo "==> Creating service principal for Arc onboarding (Azure Connected Machine Onboarding role)"
if [ -f /tmp/arc_sp_customer_demo.json ]; then
  echo "   (reusing existing SP from /tmp/arc_sp_customer_demo.json)"
else
  az ad sp create-for-rbac --name "$SP_NAME" --role "Azure Connected Machine Onboarding" \
    --scopes "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG" \
    -o json > /tmp/arc_sp_customer_demo.json
fi
APP_ID=$(python3 -c "import json; print(json.load(open('/tmp/arc_sp_customer_demo.json'))['appId'])")
APP_SECRET=$(python3 -c "import json; print(json.load(open('/tmp/arc_sp_customer_demo.json'))['password'])")
TENANT_ID=$(python3 -c "import json; print(json.load(open('/tmp/arc_sp_customer_demo.json'))['tenant'])")

echo "==> STEP A: Installing azcmagent and connecting to Arc (native agent still active)"
cat > /tmp/onboard-arc-linux-stepA.sh <<REMOTE_SCRIPT
#!/bin/bash
set -euo pipefail
echo "--- Setting MSFT_ARC_TEST (must be set BEFORE install/connect per official Microsoft docs) ---"
export MSFT_ARC_TEST=true
sudo systemctl set-environment MSFT_ARC_TEST=true

echo "--- Installing Azure Connected Machine agent ---"
curl -sLo /tmp/install_linux_azcmagent.sh https://aka.ms/azcmagent
sudo MSFT_ARC_TEST=true bash /tmp/install_linux_azcmagent.sh

echo "--- Connecting to Arc ---"
sudo MSFT_ARC_TEST=true azcmagent connect \\
  --service-principal-id "$APP_ID" \\
  --service-principal-secret "$APP_SECRET" \\
  --resource-group "$RG" \\
  --tenant-id "$TENANT_ID" \\
  --location "$LOCATION" \\
  --subscription-id "$SUBSCRIPTION" \\
  --cloud AzureCloud

echo "--- Arc connect finished ---"
sudo azcmagent show
REMOTE_SCRIPT

az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts @/tmp/onboard-arc-linux-stepA.sh \
  --subscription "$SUBSCRIPTION" \
  -o json

echo "==> Verifying Arc machine registered"
for i in $(seq 1 10); do
  STATUS=$(az connectedmachine show --resource-group "$RG" --name "$VM_NAME" --subscription "$SUBSCRIPTION" --query status -o tsv 2>/dev/null || echo "NotFound")
  echo "   status: $STATUS"
  if [ "$STATUS" = "Connected" ]; then break; fi
  sleep 15
done

echo "==> STEP B: Simulating on-prem (disables native agent — fired with --no-wait, verified independently)"
cat > /tmp/onboard-arc-linux-stepB.sh <<'REMOTE_SCRIPT_B'
#!/bin/bash
echo "--- Blocking IMDS endpoint ---"
sudo apt-get update -y -qq && sudo apt-get install -y -qq ufw
sudo ufw --force enable
sudo ufw deny out to 169.254.169.254

echo "--- Setting MSFT_ARC_TEST flag ---"
echo 'export MSFT_ARC_TEST=true' | sudo tee -a /etc/profile.d/arc-test.sh
sudo systemctl set-environment MSFT_ARC_TEST=true

echo "--- Disabling native Azure guest agent (point of no return for native run-command) ---"
sudo systemctl stop walinuxagent
sudo systemctl disable walinuxagent
REMOTE_SCRIPT_B

az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts @/tmp/onboard-arc-linux-stepB.sh \
  --subscription "$SUBSCRIPTION" \
  --no-wait \
  -o json || true

echo "==> Step B fired with --no-wait (expected: this run-command will show as stuck/in-progress"
echo "    forever on the native VM resource, because it disables the agent that reports back —"
echo "    this is harmless and expected. From now on use scripts/run-via-arc.sh for ALL further"
echo "    automation against this VM."
