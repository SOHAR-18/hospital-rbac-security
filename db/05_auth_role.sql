-- ============================================================
-- PHASE 7 (DB PART): AUTH ROLE
-- A minimal-privilege role used ONLY for the login step --
-- it can read the users table (to check username/password)
-- and write to audit_log, and nothing else whatsoever.
-- Run as postgres, connected to hospital_rbac.
-- ============================================================

DROP ROLE IF EXISTS app_auth_role;

CREATE ROLE app_auth_role LOGIN PASSWORD 'AuthRole@123' CONNECTION LIMIT 20;

GRANT SELECT ON users TO app_auth_role;
GRANT SELECT, INSERT ON audit_log TO app_auth_role;
GRANT USAGE, SELECT ON SEQUENCE audit_log_log_id_seq TO app_auth_role;

-- Confirm
\du app_auth_role