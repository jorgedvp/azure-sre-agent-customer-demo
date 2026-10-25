#!/usr/bin/env bash
# =============================================================================
# 06-create-sre-agent.sh
# Creates the Azure SRE Agent resource and grants it the RBAC roles needed to
# read monitoring data and execute Run Command against both Arc machines.
# =============================================================================
set -euo pipefail

RG="${RG:-rg-sre-customer-demo}"
SUBSCRIPTION="${SUBSCRIPTION:?}"
LOCATION="${LOCATION:-eastus2}"
AGENT_NAME="${AGENT_NAME:-sre-customer-demo}"
VM_LINUX="${VM_LINUX:-vm-onprem-sql}"
VM_WINDOWS="${VM_WINDOWS:-vm-onprem-iis}"
LAW_NAME="${LAW_NAME:-law-sredemo}"

echo "==> NOTE: SRE Agent creation is currently a portal-driven / preview CLI experience."
echo "    If 'az sre-agent' is not available in your CLI version, create the agent via"
echo "    https://sre.azure.com in the target resource group, name it '${AGENT_NAME}',"
echo "    then re-run this script to only apply the RBAC assignments below."

AGENT_PRINCIPAL_ID=$(az resource list --resource-group "$RG" --resource-type "Microsoft.App/agents" \
  --query "[?name=='${AGENT_NAME}'].identity.principalId | [0]" -o tsv --subscription "$SUBSCRIPTION" 2>/dev/null || true)

if [ -z "$AGENT_PRINCIPAL_ID" ]; then
  echo "!! Could not find the SRE Agent's managed identity automatically."
  echo "!! Create the agent first via the portal (https://sre.azure.com), then export:"
  echo "!!   export AGENT_PRINCIPAL_ID=<principalId>"
  echo "!! and re-run this script."
  exit 1
fi

RG_SCOPE="/subscriptions/${SUBSCRIPTION}/resourceGroups/${RG}"
LAW_SCOPE="${RG_SCOPE}/providers/Microsoft.OperationalInsights/workspaces/${LAW_NAME}"
VM_LINUX_SCOPE="${RG_SCOPE}/providers/Microsoft.HybridCompute/machines/${VM_LINUX}"
VM_WINDOWS_SCOPE="${RG_SCOPE}/providers/Microsoft.HybridCompute/machines/${VM_WINDOWS}"

echo "==> Assigning Reader at resource group scope"
az role assignment create --assignee "$AGENT_PRINCIPAL_ID" --role "Reader" --scope "$RG_SCOPE" --subscription "$SUBSCRIPTION" -o none || true

echo "==> Assigning Monitoring Reader at resource group scope"
az role assignment create --assignee "$AGENT_PRINCIPAL_ID" --role "Monitoring Reader" --scope "$RG_SCOPE" --subscription "$SUBSCRIPTION" -o none || true

echo "==> Assigning Log Analytics Reader at workspace scope"
az role assignment create --assignee "$AGENT_PRINCIPAL_ID" --role "Log Analytics Reader" --scope "$LAW_SCOPE" --subscription "$SUBSCRIPTION" -o none || true

echo "==> Assigning Azure Connected Machine Resource Administrator on both Arc machines (enables Run Command)"
az role assignment create --assignee "$AGENT_PRINCIPAL_ID" --role "Azure Connected Machine Resource Administrator" --scope "$VM_LINUX_SCOPE" --subscription "$SUBSCRIPTION" -o none || true
az role assignment create --assignee "$AGENT_PRINCIPAL_ID" --role "Azure Connected Machine Resource Administrator" --scope "$VM_WINDOWS_SCOPE" --subscription "$SUBSCRIPTION" -o none || true

echo "==> RBAC assignments complete. Allow 3-5 minutes for propagation before testing the agent."
echo "==> Next steps (manual, portal-driven):"
echo "    1. In https://sre.azure.com, connect the Log Analytics workspace '${LAW_NAME}' to the agent."
echo "    2. Connect this GitHub repo (azure-sre-agent-customer-demo) as the agent's Code source"
echo "       using a Personal Access Token (see docs/GUIDE.md section 'Conectar el repositorio')."
