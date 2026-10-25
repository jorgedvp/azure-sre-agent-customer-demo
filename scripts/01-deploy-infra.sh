#!/usr/bin/env bash
# =============================================================================
# 01-deploy-infra.sh
# Deploys the core Bicep infrastructure: VNet, NSG, 2 VMs, Log Analytics, DCR.
# =============================================================================
set -euo pipefail

RG="${RG:-rg-sre-customer-demo}"
LOCATION="${LOCATION:-eastus2}"
SUBSCRIPTION="${SUBSCRIPTION:?Set SUBSCRIPTION env var to your subscription ID}"
ADMIN_USERNAME="${ADMIN_USERNAME:-azureadmin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:?Set ADMIN_PASSWORD env var (used for both VMs)}"

MY_IP="$(curl -s ifconfig.me)"
ALLOWED_CIDR="${ALLOWED_CIDR:-${MY_IP}/32}"

echo "==> Creating resource group ${RG} in ${LOCATION}"
az group create --name "$RG" --location "$LOCATION" --subscription "$SUBSCRIPTION" -o none

SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-$(cat ~/.ssh/id_rsa.pub)}"

echo "==> Deploying Bicep (this takes ~5-8 minutes: 2 VMs + networking + Log Analytics + DCR)"
az deployment group create \
  --resource-group "$RG" \
  --template-file "$(dirname "$0")/../infra/main.bicep" \
  --parameters adminUsername="$ADMIN_USERNAME" adminPassword="$ADMIN_PASSWORD" sshPublicKey="$SSH_PUBLIC_KEY" allowedSetupIpCidr="$ALLOWED_CIDR" location="$LOCATION" \
  --subscription "$SUBSCRIPTION" \
  -o json > /tmp/sre-demo-deploy-output.json

echo "==> Deployment complete. Outputs saved to /tmp/sre-demo-deploy-output.json"
cat /tmp/sre-demo-deploy-output.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['properties']['outputs'], indent=2))"
