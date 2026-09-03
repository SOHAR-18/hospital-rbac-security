-- ============================================================
-- SEED DATA: sample doctors, patients, records, billing
-- Run this AFTER 01_insecure_schema.sql
-- ============================================================

INSERT INTO doctors (full_name, specialization, phone) VALUES
('Dr. Ananya Rao', 'Cardiology', '9876543210'),
('Dr. Vikram Shah', 'Orthopedics', '9876543211'),
('Dr. Priya Menon', 'General Medicine', '9876543212');

INSERT INTO patients (full_name, dob, phone, address, assigned_doctor_id) VALUES
('Ravi Kumar', '1985-04-12', '9123456780', 'MG Road, Bengaluru', 1),
('Sneha Iyer', '1992-08-23', '9123456781', 'Koramangala, Bengaluru', 2),
('Arjun Nair', '1978-01-05', '9123456782', 'Indiranagar, Bengaluru', 1),
('Fatima Khan', '2000-11-30', '9123456783', 'Whitefield, Bengaluru', 3);

INSERT INTO medical_records (patient_id, doctor_id, diagnosis, treatment, notes) VALUES
(1, 1, 'Hypertension', 'Amlodipine 5mg daily', 'Follow up in 3 months'),
(2, 2, 'Fractured wrist', 'Cast for 6 weeks', 'Physiotherapy after cast removal'),
(3, 1, 'Arrhythmia', 'Beta blockers', 'ECG monitoring advised'),
(4, 3, 'Seasonal flu', 'Rest and fluids', 'No complications');

INSERT INTO billing (patient_id, amount, status) VALUES
(1, 1500.00, 'paid'),
(2, 8500.00, 'unpaid'),
(3, 3200.00, 'paid'),
(4, 600.00, 'unpaid');

INSERT INTO appointments (patient_id, doctor_id, appointment_date, status) VALUES
(1, 1, '2026-09-10 10:00:00', 'scheduled'),
(2, 2, '2026-09-11 14:30:00', 'scheduled'),
(3, 1, '2026-09-12 09:00:00', 'completed');

-- App login users -- passwords will be set properly via Python bcrypt script,
-- these are placeholders we will UPDATE in Phase 3
INSERT INTO users (username, password_hash, full_name, role, linked_id) VALUES
('admin1', 'PLACEHOLDER', 'System Admin', 'admin', NULL),
('drrao', 'PLACEHOLDER', 'Dr. Ananya Rao', 'doctor', 1),
('drshah', 'PLACEHOLDER', 'Dr. Vikram Shah', 'doctor', 2),
('nurse1', 'PLACEHOLDER', 'Nandini S', 'nurse', NULL),
('frontdesk1', 'PLACEHOLDER', 'Rahul Front-desk', 'receptionist', NULL),
('billing1', 'PLACEHOLDER', 'Meena Billing', 'billing_clerk', NULL);

-- Verify
SELECT * FROM users;