-- ============================================================
-- PHASE 6: ROW-LEVEL SECURITY (RLS)
-- Solves what GRANT/REVOKE alone cannot: multiple doctors share
-- the SAME login (doctor_role), so table-level grants can't tell
-- them apart. RLS filters individual ROWS based on a session
-- variable the app sets right after login.
-- Run this while connected as postgres to hospital_rbac.
-- ============================================================

-- ------------------------------------------------------------
-- STEP A: Let admin bypass RLS entirely (admins see everything,
-- same as a real hospital system administrator would).
-- ------------------------------------------------------------
ALTER ROLE admin_role BYPASSRLS;

-- ------------------------------------------------------------
-- STEP B: Enable RLS on the sensitive tables.
-- IMPORTANT: once RLS is enabled on a table, EVERY role (except
-- BYPASSRLS roles and the table owner) sees ZERO rows unless a
-- matching policy exists for them -- this is a safe "default deny".
-- ------------------------------------------------------------
ALTER TABLE medical_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients        ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments    ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- STEP C: DOCTOR policies -- only rows belonging to the
-- CURRENTLY LOGGED-IN doctor's doctor_id (from a session
-- variable the app will SET right after authenticating).
-- current_setting(..., true) with true = don't error if unset,
-- just return NULL (so an unset variable safely shows zero rows
-- instead of crashing).
-- ------------------------------------------------------------
CREATE POLICY doctor_own_records ON medical_records
    FOR ALL
    TO doctor_role
    USING (doctor_id = NULLIF(current_setting('app.current_doctor_id', true), '')::int);

CREATE POLICY doctor_own_patients ON patients
    FOR SELECT
    TO doctor_role
    USING (assigned_doctor_id = NULLIF(current_setting('app.current_doctor_id', true), '')::int);

CREATE POLICY doctor_own_appointments ON appointments
    FOR SELECT
    TO doctor_role
    USING (doctor_id = NULLIF(current_setting('app.current_doctor_id', true), '')::int);

-- ------------------------------------------------------------
-- STEP D: NURSE policies -- nurses work hospital-wide in this
-- design, so they see ALL rows (USING (true)), but remember:
-- GRANT/REVOKE from Phase 5 already blocks them from billing
-- entirely regardless of these policies.
-- ------------------------------------------------------------
CREATE POLICY nurse_all_records ON medical_records
    FOR ALL
    TO nurse_role
    USING (true);

CREATE POLICY nurse_all_patients ON patients
    FOR SELECT
    TO nurse_role
    USING (true);

CREATE POLICY nurse_all_appointments ON appointments
    FOR SELECT
    TO nurse_role
    USING (true);

-- ------------------------------------------------------------
-- STEP E: RECEPTIONIST policies -- receptionists need to see
-- ALL patients/appointments (front desk needs the whole list),
-- but Phase 5's GRANT already fully blocks medical_records for
-- them, so no policy is needed there at all.
-- ------------------------------------------------------------
CREATE POLICY receptionist_all_patients ON patients
    FOR ALL
    TO receptionist_role
    USING (true);

CREATE POLICY receptionist_all_appointments ON appointments
    FOR ALL
    TO receptionist_role
    USING (true);

-- ------------------------------------------------------------
-- STEP F: BILLING CLERK -- needs to see all patient NAMES to
-- label bills, so gets full read on patients. No policy needed
-- on medical_records/appointments since Phase 5 already blocks
-- billing_role from touching those tables entirely.
-- ------------------------------------------------------------
CREATE POLICY billing_all_patients ON patients
    FOR SELECT
    TO billing_role
    USING (true);

-- ------------------------------------------------------------
-- Confirm policies created
-- ------------------------------------------------------------
\d medical_records
SELECT schemaname, tablename, policyname, roles, cmd
FROM pg_policies
ORDER BY tablename, policyname;