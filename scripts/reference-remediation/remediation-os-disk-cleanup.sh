#!/usr/bin/env bash
# =============================================================================
# remediation-os-disk-cleanup.sh
# Reference script the SRE Agent can read (and propose updating via PR) when
# diagnosing scenario 1 (OS disk full). Lives in this repo as the agent's
# "known good" remediation for this failure class.
# =============================================================================
set -euo pipefail

LOG_FILE="${LOG_FILE:-/var/log/demo-fill.log}"

echo "=== Disk usage before cleanup ==="
df -h /

if [ -f "$LOG_FILE" ]; then
  echo "=== Truncating oversized demo log file: $LOG_FILE ==="
  sudo truncate -s 0 "$LOG_FILE"
else
  echo "=== $LOG_FILE not found, checking top disk consumers under /var/log instead ==="
  sudo du -sh /var/log/* 2>/dev/null | sort -rh | head -10
fi

echo "=== Disk usage after cleanup ==="
df -h /

echo "=== Recommendation: configure logrotate for /var/log to prevent recurrence ==="
cat <<'LOGROTATE_SAMPLE'
# Suggested /etc/logrotate.d/demo-app entry:
/var/log/demo-fill.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    maxsize 500M
}
LOGROTATE_SAMPLE
