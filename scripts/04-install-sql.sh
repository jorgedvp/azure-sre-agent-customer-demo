#!/usr/bin/env bash
# =============================================================================
# 04-install-sql.sh
# Installs SQL Server 2022 Developer + sqlcmd on vm-onprem-sql, creates the
# DemoDB database used by scenario 3 (blocking session) and scenario 4
# (Defender for SQL vulnerability). Executed entirely via Arc Run Command.
#
# NOTE 1: the run-command JSON payload is built with Python (not a bash
# heredoc) to avoid shell/JSON escaping issues with $PATH and nested quotes.
#
# NOTE 2 (lesson learned): SQL Server 2022 does not officially support
# Ubuntu 24.04 (the image used by this demo's Bicep, chosen for Arc
# reliability — see prompts/REDEPLOY.md). It requires liblber-2.5/
# libldap-2.5-0, which 24.04 (noble) no longer ships (it moved to libldap
# 2.6). This script installs the compatible library from a temporary jammy
# (22.04) apt source BEFORE running mssql-conf setup, so the initial sa
# password setup succeeds on the first try.
# =============================================================================
set -euo pipefail

RG="${RG:-rg-sre-customer-demo}"
SUBSCRIPTION="${SUBSCRIPTION:?}"
VM_NAME="${VM_NAME:-vm-onprem-sql}"
LOCATION="${LOCATION:-eastus2}"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD env var for the SQL Server sa account}"

SCRIPT_BODY=$(cat <<'BASH_SCRIPT'
export DEBIAN_FRONTEND=noninteractive
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list | sed -E 's#\[arch=([^]]*)\]#[arch=\1 signed-by=/usr/share/keyrings/microsoft-prod.gpg]#' | sudo tee /etc/apt/sources.list.d/mssql-server-2022.list
curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sed -E 's#\[arch=([^]]*)\]#[arch=\1 signed-by=/usr/share/keyrings/microsoft-prod.gpg]#' | sudo tee /etc/apt/sources.list.d/mssql-release.list
sudo apt-get update -y

# Ubuntu 24.04 compatibility fix: pull libldap-2.5-0 from jammy BEFORE
# installing mssql-server, so the initial 'mssql-conf setup' (which starts
# sqlservr to apply the sa password) succeeds the first time.
echo 'deb [trusted=yes] http://archive.ubuntu.com/ubuntu jammy main universe' | sudo tee /etc/apt/sources.list.d/jammy-temp.list
sudo apt-get update -y -qq
sudo apt-get install -y -qq libldap-2.5-0
sudo rm /etc/apt/sources.list.d/jammy-temp.list
sudo apt-get update -y -qq

sudo apt-get install -y mssql-server
sudo MSSQL_SA_PASSWORD='__SA_PASSWORD__' MSSQL_PID=Developer /opt/mssql/bin/mssql-conf -n setup accept-eula

sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev
echo 'export PATH=$PATH:/opt/mssql-tools18/bin' | sudo tee -a /etc/profile.d/mssql-tools.sh
sleep 10
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '__SA_PASSWORD__' -C -Q "CREATE DATABASE DemoDB;"
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '__SA_PASSWORD__' -C -d DemoDB -Q "CREATE TABLE Orders (OrderId INT PRIMARY KEY, CustomerName NVARCHAR(100), Amount DECIMAL(10,2), CreatedAt DATETIME DEFAULT GETDATE()); INSERT INTO Orders (OrderId, CustomerName, Amount) VALUES (1, 'Contoso', 100.00), (2, 'Fabrikam', 250.50);"
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '__SA_PASSWORD__' -C -d DemoDB -W -Q "SELECT * FROM Orders;"
echo SQL_INSTALL_COMPLETE
BASH_SCRIPT
)

SCRIPT_BODY="${SCRIPT_BODY//__SA_PASSWORD__/$SA_PASSWORD}"

python3 -c "
import json, sys
script = sys.stdin.read()
print(json.dumps({'script': script}))
" <<< "$SCRIPT_BODY" > /tmp/install-sql.json

echo "==> Installing SQL Server 2022 on ${VM_NAME} via Arc Run Command (this takes 5-8 minutes)"
az connectedmachine run-command create \
  --resource-group "$RG" \
  --machine-name "$VM_NAME" \
  --name install-sql-server \
  --location "$LOCATION" \
  --source @/tmp/install-sql.json \
  --timeout-in-seconds 400 \
  --subscription "$SUBSCRIPTION" \
  -o json

echo "==> SQL Server installation complete. DemoDB created with Orders table."
