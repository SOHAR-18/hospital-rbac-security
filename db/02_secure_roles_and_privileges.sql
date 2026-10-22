-- ============================================================
-- PHASE 5: DATABASE-LEVEL ROLES, PROFILES & PRIVILEGES
-- Run this while connected as postgres to the hospital_rbac database
-- ============================================================

-- ------------------------------------------------------------
-- STEP A: Drop roles if re-running during development
-- (can't drop a role while it owns privileges, so we revoke first
--  by just dropping and recreating cleanly here)
-- ------------------------------------------------------------
DROP ROLE IF EXISTS admin_role;
DROP ROLE IF EXISTS doctor_role;
DROP ROLE IF EXISTS nurse_role;
DROP ROLE IF EXISTS receptionist_role;
DROP ROLE IF EXISTS billing_role;

-- ------------------------------------------------------------
-- STEP B: Create roles with LOGIN + PASSWORD + CONNECTION LIMIT
-- CONNECTION LIMIT simulates "profiles" (Module 3 of your syllabus --
-- Oracle calls this a PROFILE; PostgreSQL attaches the same idea
-- directly to the role).
-- ------------------------------------------------------------
CREATE ROLE admin_role        LOGIN PASSWORD 'AdminRole@123'        CONNECTION LIMIT 5;
CREATE ROLE doctor_role       LOGIN PASSWORD 'DoctorRole@123'       CONNECTION LIMIT 10;
CREATE ROLE nurse_role        LOGIN PASSWORD 'NurseRole@123'        CONNECTION LIMIT 10;
CREATE ROLE receptionist_role LOGIN PASSWORD 'ReceptionRole@123'    CONNECTION LIMIT 10;
CREATE ROLE billing_role      LOGIN PASSWORD 'BillingRole@123'      CONNECTION LIMIT 5;

-- ------------------------------------------------------------
-- STEP C: Lock down the default -- revoke everything from PUBLIC
-- By default, Postgres lets any role read any table unless told
-- otherwise. We remove that default entirely, then grant back
-- ONLY what each role specifically needs. This is the core
-- "least privilege" principle from Module 3/4.
-- ------------------------------------------------------------
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;

-- ------------------------------------------------------------
-- STEP D: ADMIN -- full access to everything
-- ------------------------------------------------------------
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_role;

-- ------------------------------------------------------------
-- STEP E: DOCTOR
-- Can read patients/doctors/appointments, read+write medical_records.
-- Cannot touch billing at all.
-- ------------------------------------------------------------
GRANT SELECT ON patients, doctors, appointments TO doctor_role;
GRANT SELECT, INSERT, UPDATE ON medical_records TO doctor_role;
GRANT USAGE, SELECT ON SEQUENCE medical_records_record_id_seq TO doctor_role;
GRANT SELECT, INSERT ON audit_log TO doctor_role;
GRANT USAGE, SELECT ON SEQUENCE audit_log_log_id_seq TO doctor_role;
-- Explicitly NO grant on billing -- Postgres defaults to deny.

-- ------------------------------------------------------------
-- STEP F: NURSE
-- Can read patients + medical_records, update medical_records
-- (e.g. vitals/notes), but cannot touch billing.
-- ------------------------------------------------------------
GRANT SELECT ON patients, doctors, appointments TO nurse_role;
GRANT SELECT, UPDATE ON medical_records TO nurse_role;
GRANT SELECT, INSERT ON audit_log TO nurse_role;
GRANT USAGE, SELECT ON SEQUENCE audit_log_log_id_seq TO nurse_role;

-- ------------------------------------------------------------
-- STEP G: RECEPTIONIST
-- Can read/write patients + appointments (front-desk work).
-- NO access whatsoever to medical_records or billing --
-- this is the exact bug we exploited in Phase 4 (IDOR), now
-- made impossible at the database layer.
-- ------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON patients TO receptionist_role;
GRANT SELECT, INSERT, UPDATE ON appointments TO receptionist_role;
GRANT SELECT ON doctors TO receptionist_role;
GRANT USAGE, SELECT ON SEQUENCE patients_patient_id_seq TO receptionist_role;
GRANT USAGE, SELECT ON SEQUENCE appointments_appointment_id_seq TO receptionist_role;
GRANT SELECT, INSERT ON audit_log TO receptionist_role;
GRANT USAGE, SELECT ON SEQUENCE audit_log_log_id_seq TO receptionist_role;

-- ------------------------------------------------------------
-- STEP H: BILLING CLERK
-- Can read/write billing, can read patient names (needed to
-- show whose bill it is), but NO access to medical_records.
-- ------------------------------------------------------------
GRANT SELECT ON patients TO billing_role;
GRANT SELECT, INSERT, UPDATE ON billing TO billing_role;
GRANT USAGE, SELECT ON SEQUENCE billing_bill_id_seq TO billing_role;
GRANT SELECT, INSERT ON audit_log TO billing_role;
GRANT USAGE, SELECT ON SEQUENCE audit_log_log_id_seq TO billing_role;

-- ------------------------------------------------------------
-- STEP I: Confirm roles created
-- ------------------------------------------------------------
\du