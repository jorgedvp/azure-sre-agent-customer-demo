-- =============================================================================
-- db-health-check.sql
-- Reference diagnostic script for SQL Server scenarios (3 and 4). Lives in
-- this repo as the agent's "Code" source — the agent reads this when
-- diagnosing SQL issues and can propose updates to it via Pull Request,
-- the same pattern validated in the azure-sre-agent-arc-lab research repo.
-- =============================================================================

SET NOCOUNT ON;

-- 1. BLOCKING CHAIN DETECTION
PRINT '=== BLOCKING CHAIN ===';
SELECT
    r.session_id AS blocked_spid,
    r.blocking_session_id AS blocking_spid,
    r.wait_type,
    r.wait_time / 1000 AS wait_sec,
    r.wait_resource,
    r.status,
    r.command,
    DB_NAME(r.database_id) AS db_name
FROM sys.dm_exec_requests r
WHERE r.blocking_session_id <> 0
ORDER BY r.wait_time DESC;

-- 2. OPEN TRANSACTIONS (root cause for most blocking scenarios)
PRINT '=== OPEN TRANSACTIONS ===';
SELECT
    t.transaction_id,
    s.session_id,
    t.transaction_begin_time,
    DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) AS age_sec,
    s.open_transaction_count,
    s.status AS session_status
FROM sys.dm_tran_active_transactions t
JOIN sys.dm_tran_session_transactions st ON t.transaction_id = st.transaction_id
JOIN sys.dm_exec_sessions s ON st.session_id = s.session_id
WHERE t.transaction_type = 1
ORDER BY t.transaction_begin_time;

-- 3. DATABASE SIZE
PRINT '=== DATABASE SIZES ===';
SELECT name, size * 8 / 1024 AS size_mb FROM sys.master_files;

-- 4. EXCESSIVE PUBLIC PERMISSIONS (scenario 4 — Defender vulnerability check)
PRINT '=== PUBLIC ROLE PERMISSIONS (security check) ===';
SELECT
    dp.permission_name,
    dp.state_desc,
    OBJECT_SCHEMA_NAME(dp.major_id) AS schema_name
FROM sys.database_permissions dp
WHERE dp.grantee_principal_id = DATABASE_PRINCIPAL_ID('public')
  AND dp.class = 3; -- schema-level permissions

-- 5. LOCK TIMEOUT / BLOCKED PROCESS THRESHOLD CONFIG CHECK
PRINT '=== SERVER CONFIG: blocked process threshold ===';
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'blocked process threshold';
