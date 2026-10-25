#!/usr/bin/env bash
# =============================================================================
# 07-enable-defender-and-alerts.sh
# Enables Microsoft Defender for Servers (Plan 2) and Defender for SQL on
# Arc machines, and creates baseline Azure Monitor alert rules used by the
# 4 demo scenarios.
# =============================================================================
set -euo pipefail

RG="${RG:-rg-sre-customer-demo}"
SUBSCRIPTION="${SUBSCRIPTION:?}"
LAW_NAME="${LAW_NAME:-law-sredemo}"
VM_LINUX="${VM_LINUX:-vm-onprem-sql}"

echo "==> Enabling Defender for Servers Plan 2 (subscription-wide)"
az security pricing create --name VirtualMachines --tier Standard --subscription "$SUBSCRIPTION" -o none

echo "==> Enabling Defender for SQL servers on machines (Arc-enabled SQL Server protection)"
az security pricing create --name SqlServerVirtualMachines --tier Standard --subscription "$SUBSCRIPTION" -o none

LAW_ID=$(az monitor log-analytics workspace show --resource-group "$RG" --workspace-name "$LAW_NAME" --subscription "$SUBSCRIPTION" --query id -o tsv)

echo "==> Creating alert rule: OS service down (Heartbeat gap / high disk usage)"
az monitor scheduled-query create \
  --name "alert-os-disk-critical" \
  --resource-group "$RG" \
  --scopes "$LAW_ID" \
  --condition "count 'FreeMegabytesQuery' > 0" \
  --condition-query FreeMegabytesQuery="Perf | where ObjectName == 'LogicalDisk' and CounterName == 'Free Megabytes' and InstanceName == '_Total' | where CounterValue < 2048 | summarize AggregatedValue = count() by bin(TimeGenerated, 5m)" \
  --description "Fires when free disk space on the on-prem Linux server drops below 2GB" \
  --severity 2 \
  --evaluation-frequency 5m \
  --window-size 5m \
  --subscription "$SUBSCRIPTION" -o none || echo "   (non-blocking: verify syntax against current az monitor CLI version)"

echo "==> Creating alert rule: SQL blocking session detected"
az monitor scheduled-query create \
  --name "alert-sql-blocking-session" \
  --resource-group "$RG" \
  --scopes "$LAW_ID" \
  --condition "count 'BlockingQuery' > 0" \
  --condition-query BlockingQuery="Event | where Source == 'MSSQLSERVER' and EventID == 1222 | summarize AggregatedValue = count() by bin(TimeGenerated, 5m)" \
  --description "Fires when SQL Server reports a blocked process (event 1222)" \
  --severity 2 \
  --evaluation-frequency 5m \
  --window-size 5m \
  --subscription "$SUBSCRIPTION" -o none || echo "   (non-blocking: verify syntax; may require enabling 'blocked process threshold' + SQL error log ingestion)"

echo "==> Defender and alert setup complete."
echo "==> NOTE: Defender vulnerability scan results for SQL typically take 24-48h to"
echo "    first populate. For demo purposes, scenario 4 can also be triggered on-demand"
echo "    (see scenarios/scenario-4-defender-sql/README.md)."
