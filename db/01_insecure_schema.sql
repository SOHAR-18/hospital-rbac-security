-- ============================================================
-- PHASE 2: CORE SCHEMA (used by both insecure & secure versions)
-- Run this while connected to hospital_rbac database
-- (You should already see hospital_rbac=# prompt)
-- ============================================================

-- Drop tables if re-running this script during development
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS billing CASCADE;
DROP TABLE IF EXISTS medical_records CASCADE;
DROP TABLE IF EXISTS appointments CASCADE;
DROP TABLE IF EXISTS doctors CASCADE;
DROP TABLE IF EXISTS patients CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ------------------------------------------------------------
-- USERS TABLE: application login accounts
-- role column drives app-level checks in the INSECURE version
-- ------------------------------------------------------------
CREATE TABLE users (
    user_id       SERIAL PRIMARY KEY,
    username      VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,          -- bcrypt hash, never plain text
    full_name     VARCHAR(100) NOT NULL,
    role          VARCHAR(20) NOT NULL CHECK (role IN
                    ('admin','doctor','nurse','receptionist','billing_clerk','patient')),
    linked_id     INTEGER,                -- links to doctors.doctor_id or patients.patient_id
    created_at    TIMESTAMP DEFAULT NOW()
);

-- ------------------------------------------------------------
-- DOCTORS TABLE
-- ------------------------------------------------------------
CREATE TABLE doctors (
    doctor_id     SERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    specialization VARCHAR(100),
    phone         VARCHAR(20)
);

-- ------------------------------------------------------------
-- PATIENTS TABLE (personal + contact info -- receptionist territory)
-- ------------------------------------------------------------
CREATE TABLE patients (
    patient_id    SERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    dob           DATE,
    phone         VARCHAR(20),
    address       TEXT,
    assigned_doctor_id INTEGER REFERENCES doctors(doctor_id)
);

-- ------------------------------------------------------------
-- APPOINTMENTS TABLE
-- ------------------------------------------------------------
CREATE TABLE appointments (
    appointment_id SERIAL PRIMARY KEY,
    patient_id     INTEGER REFERENCES patients(patient_id),
    doctor_id      INTEGER REFERENCES doctors(doctor_id),
    appointment_date TIMESTAMP NOT NULL,
    status         VARCHAR(20) DEFAULT 'scheduled'
);

-- ------------------------------------------------------------
-- MEDICAL_RECORDS TABLE (MOST SENSITIVE -- the whole point of this project)
-- Only doctor (own patients) and nurse should ever see this
-- ------------------------------------------------------------
CREATE TABLE medical_records (
    record_id     SERIAL PRIMARY KEY,
    patient_id    INTEGER REFERENCES patients(patient_id),
    doctor_id     INTEGER REFERENCES doctors(doctor_id),
    diagnosis     TEXT NOT NULL,
    treatment     TEXT,
    notes         TEXT,
    record_date   TIMESTAMP DEFAULT NOW()
);

-- ------------------------------------------------------------
-- BILLING TABLE (only billing_clerk + admin should see this)
-- ------------------------------------------------------------
CREATE TABLE billing (
    bill_id       SERIAL PRIMARY KEY,
    patient_id    INTEGER REFERENCES patients(patient_id),
    amount        NUMERIC(10,2) NOT NULL,
    status        VARCHAR(20) DEFAULT 'unpaid',
    billed_date   TIMESTAMP DEFAULT NOW()
);

-- ------------------------------------------------------------
-- AUDIT_LOG TABLE (records every access attempt -- your evidence in the demo)
-- ------------------------------------------------------------
CREATE TABLE audit_log (
    log_id        SERIAL PRIMARY KEY,
    username      VARCHAR(50),
    action        TEXT NOT NULL,
    table_name    VARCHAR(50),
    success       BOOLEAN NOT NULL,
    detail        TEXT,
    logged_at     TIMESTAMP DEFAULT NOW()
);

-- Confirm tables created
\dt