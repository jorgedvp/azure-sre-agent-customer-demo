-- =============================================================================
-- Remediation: Revoke excessive SELECT permission from public role on DemoDB
-- =============================================================================
-- Finding:    Microsoft Defender for SQL — Vulnerability Assessment
-- Category:   Authentication & Authorization
-- Resource:   vm-onprem-sql (Azure Arc-enabled server)
-- Database:   DemoDB
-- Issue:      https://github.com/jorgedvp/azure-sre-agent-customer-demo/issues/1
--
-- Description:
--   The public database role was granted SELECT on SCHEMA::dbo, giving every
--   authenticated user read access to all tables, views, and inline functions
--   in the dbo schema. This violates the principle of least privilege.
--
-- Impact:
--   Revoking this permission will remove the blanket SELECT access from the
--   public role. Any application or user that relies on this implicit access
--   will need explicit grants on the specific objects they require.
--
-- Pre-execution checklist:
--   1. Identify all application accounts and their required object access.
--   2. Prepare explicit GRANT statements for those accounts BEFORE revoking.
--   3. Test in a non-production environment first.
--   4. Schedule a maintenance window if the database serves production traffic.
--
-- Rollback (if needed):
--   USE DemoDB;
--   GRANT SELECT ON SCHEMA::dbo TO public;
-- =============================================================================

USE DemoDB;
GO

-- Step 1: Verify current state (before remediation)
PRINT '=== BEFORE: Public role schema-level permissions ===';
SELECT
    dp.permission_name,
    dp.state_desc,
    dp.class_desc,
    SCHEMA_NAME(dp.major_id) AS schema_name
FROM sys.database_permissions dp
JOIN sys.database_principals pr
    ON dp.grantee_principal_id = pr.principal_id
WHERE pr.name = 'public'
  AND dp.class_desc = 'SCHEMA';
GO

-- Step 2: Revoke the excessive SELECT permission on dbo schema from public
PRINT '=== Revoking SELECT ON SCHEMA::dbo FROM public ===';
REVOKE SELECT ON SCHEMA::dbo FROM public;
GO

-- Step 3: Verify the remediation was applied
PRINT '=== AFTER: Public role schema-level permissions (should be empty) ===';
SELECT
    dp.permission_name,
    dp.state_desc,
    dp.class_desc,
    SCHEMA_NAME(dp.major_id) AS schema_name
FROM sys.database_permissions dp
JOIN sys.database_principals pr
    ON dp.grantee_principal_id = pr.principal_id
WHERE pr.name = 'public'
  AND dp.class_desc = 'SCHEMA';
GO

PRINT '=== Remediation complete. Verify application functionality. ===';
GO
