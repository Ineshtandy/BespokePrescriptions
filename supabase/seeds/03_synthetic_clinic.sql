-- Synthetic Demo Clinic workflow fixtures.
-- LOCAL DEVELOPMENT ONLY.
-- Every person, phone number, and prescription below is fictional.
-- Password for every seeded auth user: demo-local-only
-- That password is not a production credential.
--
-- Historical prescriptions are inserted as drafts, their items are added,
-- and the database owner then sets is_finalized and a fixed finalized_at.
-- The item trigger rejects writes once a parent is finalized, so items
-- cannot be attached after that state. The owner is not an application
-- role, so the lifecycle trigger permits this finalization-column update
-- during controlled seed reconstruction. No trigger is disabled, and no
-- application bypass is created. Application roles still cannot write
-- finalization state directly. dose_normalized is left for the dose trigger.

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
) values
  (
    '00000000-0000-0000-0000-000000000000',
    'a1100000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    'doctor.a@demo.clinic.local',
    '$2a$10$eg4S2JCCieBtFgIbsEZLPOz6yXPW0bSfhQyYHSb0Ogdz8oXtv7.Vi',
    '2026-01-01 00:00:00+00',
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Doctor A"}',
    '2026-01-01 00:00:00+00',
    '2026-01-01 00:00:00+00',
    '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'a1100000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    'doctor.b@demo.clinic.local',
    '$2a$10$eg4S2JCCieBtFgIbsEZLPOz6yXPW0bSfhQyYHSb0Ogdz8oXtv7.Vi',
    '2026-01-01 00:00:00+00',
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Doctor B"}',
    '2026-01-01 00:00:00+00',
    '2026-01-01 00:00:00+00',
    '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'a1100000-0000-4000-8000-000000000003',
    'authenticated',
    'authenticated',
    'assistant.a@demo.clinic.local',
    '$2a$10$eg4S2JCCieBtFgIbsEZLPOz6yXPW0bSfhQyYHSb0Ogdz8oXtv7.Vi',
    '2026-01-01 00:00:00+00',
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Assistant A"}',
    '2026-01-01 00:00:00+00',
    '2026-01-01 00:00:00+00',
    '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'a1100000-0000-4000-8000-000000000004',
    'authenticated',
    'authenticated',
    'admin.a@demo.clinic.local',
    '$2a$10$eg4S2JCCieBtFgIbsEZLPOz6yXPW0bSfhQyYHSb0Ogdz8oXtv7.Vi',
    '2026-01-01 00:00:00+00',
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Admin A"}',
    '2026-01-01 00:00:00+00',
    '2026-01-01 00:00:00+00',
    '', '', '', ''
  );

-- email is generated from identity_data and cannot be inserted directly.
insert into auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  created_at,
  updated_at
) values
  (
    'a1100000-0000-4000-8000-000000000001',
    'a1100000-0000-4000-8000-000000000001',
    '{"sub":"a1100000-0000-4000-8000-000000000001","email":"doctor.a@demo.clinic.local"}',
    'email',
    'a1100000-0000-4000-8000-000000000001',
    '2026-01-01 00:00:00+00',
    '2026-01-01 00:00:00+00'
  ),
  (
    'a1100000-0000-4000-8000-000000000002',
    'a1100000-0000-4000-8000-000000000002',
    '{"sub":"a1100000-0000-4000-8000-000000000002","email":"doctor.b@demo.clinic.local"}',
    'email',
    'a1100000-0000-4000-8000-000000000002',
    '2026-01-01 00:00:00+00',
    '2026-01-01 00:00:00+00'
  ),
  (
    'a1100000-0000-4000-8000-000000000003',
    'a1100000-0000-4000-8000-000000000003',
    '{"sub":"a1100000-0000-4000-8000-000000000003","email":"assistant.a@demo.clinic.local"}',
    'email',
    'a1100000-0000-4000-8000-000000000003',
    '2026-01-01 00:00:00+00',
    '2026-01-01 00:00:00+00'
  ),
  (
    'a1100000-0000-4000-8000-000000000004',
    'a1100000-0000-4000-8000-000000000004',
    '{"sub":"a1100000-0000-4000-8000-000000000004","email":"admin.a@demo.clinic.local"}',
    'email',
    'a1100000-0000-4000-8000-000000000004',
    '2026-01-01 00:00:00+00',
    '2026-01-01 00:00:00+00'
  );

insert into public.profiles (id, full_name) values
  ('a1100000-0000-4000-8000-000000000001', 'Doctor A'),
  ('a1100000-0000-4000-8000-000000000002', 'Doctor B'),
  ('a1100000-0000-4000-8000-000000000003', 'Assistant A'),
  ('a1100000-0000-4000-8000-000000000004', 'Admin A');

insert into public.clinics (clinic_id, name) values
  ('c1100000-0000-4000-8000-000000000001', 'Demo Clinic');

insert into public.clinic_members (clinic_id, profile_id, role) values
  ('c1100000-0000-4000-8000-000000000001', 'a1100000-0000-4000-8000-000000000001', 'doctor'),
  ('c1100000-0000-4000-8000-000000000001', 'a1100000-0000-4000-8000-000000000002', 'doctor'),
  ('c1100000-0000-4000-8000-000000000001', 'a1100000-0000-4000-8000-000000000003', 'assistant'),
  ('c1100000-0000-4000-8000-000000000001', 'a1100000-0000-4000-8000-000000000004', 'admin');

insert into public.patients (
  patient_id, clinic_id, patient_number, name, dob, gender, phone
) values
  (
    'b1100000-0000-4000-8000-000000000001',
    'c1100000-0000-4000-8000-000000000001',
    'P0001', 'Meera Kapoor', '1988-04-12', 'Female', '555-010-0001'
  ),
  (
    'b1100000-0000-4000-8000-000000000002',
    'c1100000-0000-4000-8000-000000000001',
    'P0002', 'Arun Deshmukh', '1975-11-03', 'Male', null
  ),
  (
    'b1100000-0000-4000-8000-000000000003',
    'c1100000-0000-4000-8000-000000000001',
    'P0003', 'Lila Fernandez', null, 'Female', '555-010-0003'
  ),
  (
    'b1100000-0000-4000-8000-000000000004',
    'c1100000-0000-4000-8000-000000000001',
    'P0004', 'Noor Rahman', '2016-06-21', 'Female', '555-010-0004'
  ),
  (
    'b1100000-0000-4000-8000-000000000005',
    'c1100000-0000-4000-8000-000000000001',
    'P0005', 'Kabir Menon', '1992-01-30', 'Male', null
  );

insert into public.visits (
  visit_id, clinic_id, patient_id, doctor_id, created_by, patient_note, visit_date
) values
  (
    'd1100000-0000-4000-8000-000000000001',
    'c1100000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000001',
    'a1100000-0000-4000-8000-000000000001',
    'a1100000-0000-4000-8000-000000000001',
    'Fever and body ache for two days.',
    '2026-01-10'
  ),
  (
    'd1100000-0000-4000-8000-000000000002',
    'c1100000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000001',
    'a1100000-0000-4000-8000-000000000001',
    'a1100000-0000-4000-8000-000000000001',
    'Follow-up after the first visit.',
    '2026-02-14'
  ),
  (
    'd1100000-0000-4000-8000-000000000003',
    'c1100000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000001',
    'a1100000-0000-4000-8000-000000000001',
    'a1100000-0000-4000-8000-000000000001',
    'Recurrent headache.',
    '2026-03-20'
  ),
  (
    'd1100000-0000-4000-8000-000000000004',
    'c1100000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000002',
    'a1100000-0000-4000-8000-000000000001',
    'a1100000-0000-4000-8000-000000000003',
    'Sore throat. Visit recorded by the assistant.',
    '2026-04-02'
  ),
  (
    'd1100000-0000-4000-8000-000000000005',
    'c1100000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000003',
    'a1100000-0000-4000-8000-000000000001',
    'a1100000-0000-4000-8000-000000000001',
    'Seasonal allergy symptoms.',
    '2026-05-08'
  ),
  (
    'd1100000-0000-4000-8000-000000000006',
    'c1100000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000003',
    'a1100000-0000-4000-8000-000000000002',
    'a1100000-0000-4000-8000-000000000002',
    'Seen by Doctor B on a later date.',
    '2026-06-12'
  ),
  (
    'd1100000-0000-4000-8000-000000000007',
    'c1100000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000004',
    'a1100000-0000-4000-8000-000000000002',
    'a1100000-0000-4000-8000-000000000002',
    'Eye irritation and wheeze.',
    '2026-07-01'
  ),
  (
    'd1100000-0000-4000-8000-000000000008',
    'c1100000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000005',
    'a1100000-0000-4000-8000-000000000001',
    'a1100000-0000-4000-8000-000000000001',
    'Skin rash and nasal congestion.',
    '2026-08-18'
  );

-- Visit d110...0001 has two finalized prescriptions and one draft.
-- Visit d110...0002 has one finalized prescription and one empty draft.
insert into public.prescriptions (
  prescription_id, visit_id, sequence_number, advice_notes
) values
  (
    'f1100000-0000-4000-8000-000000000001',
    'd1100000-0000-4000-8000-000000000001',
    1, 'Drink water and rest.'
  ),
  (
    'f1100000-0000-4000-8000-000000000002',
    'd1100000-0000-4000-8000-000000000001',
    2, null
  ),
  (
    'f1100000-0000-4000-8000-000000000003',
    'd1100000-0000-4000-8000-000000000001',
    3, 'Draft for demonstration. Not a real prescription.'
  ),
  (
    'f1100000-0000-4000-8000-000000000004',
    'd1100000-0000-4000-8000-000000000002',
    1, null
  ),
  (
    'f1100000-0000-4000-8000-000000000005',
    'd1100000-0000-4000-8000-000000000002',
    2, null
  ),
  (
    'f1100000-0000-4000-8000-000000000006',
    'd1100000-0000-4000-8000-000000000003',
    1, null
  ),
  (
    'f1100000-0000-4000-8000-000000000007',
    'd1100000-0000-4000-8000-000000000003',
    2, null
  ),
  (
    'f1100000-0000-4000-8000-000000000008',
    'd1100000-0000-4000-8000-000000000004',
    1, null
  ),
  (
    'f1100000-0000-4000-8000-000000000009',
    'd1100000-0000-4000-8000-000000000005',
    1, null
  ),
  (
    'f1100000-0000-4000-8000-00000000000a',
    'd1100000-0000-4000-8000-000000000006',
    1, null
  ),
  (
    'f1100000-0000-4000-8000-00000000000b',
    'd1100000-0000-4000-8000-000000000007',
    1, null
  ),
  (
    'f1100000-0000-4000-8000-00000000000c',
    'd1100000-0000-4000-8000-000000000008',
    1, null
  );

-- Doctor A / Paracetamol 500 mg Tablet history used by a future
-- "Commonly used by you" ranking:
--   1 Tablet, BD, AFTER_FOOD, 5D, ORAL  → 4 finalized uses
--   1 Tablet, TDS, AFTER_FOOD, 5D, ORAL → 2 finalized uses
--   1 Tablet, BD, AFTER_FOOD, 7D, ORAL  → 1 finalized use
-- Doctor B uses the same medicine as 1 Tablet, OD, BEFORE_FOOD, 7D, ORAL twice.
insert into public.prescription_items (
  id, prescription_id, med_id, dose_text, frequency_code, timing_code,
  duration_code, duration_note, route_code, order_index
) values
  (
    'f2110000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000001',
    'e1100000-0000-4000-8000-000000000001',
    '1 Tablet', 'BD', 'AFTER_FOOD', '5D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-000000000002',
    'f1100000-0000-4000-8000-000000000001',
    'e1100000-0000-4000-8000-000000000005',
    '1 Tablet', 'OD', 'BEDTIME', '5D', null, 'ORAL', 1
  ),
  (
    'f2110000-0000-4000-8000-000000000003',
    'f1100000-0000-4000-8000-000000000002',
    'e1100000-0000-4000-8000-000000000001',
    '1 Tablet', 'BD', 'AFTER_FOOD', '5D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-000000000004',
    'f1100000-0000-4000-8000-000000000003',
    'e1100000-0000-4000-8000-000000000003',
    '1 Capsule', 'TDS', 'AFTER_FOOD', '5D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-000000000005',
    'f1100000-0000-4000-8000-000000000004',
    'e1100000-0000-4000-8000-000000000001',
    '1 Tablet', 'BD', 'AFTER_FOOD', '5D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-000000000006',
    'f1100000-0000-4000-8000-000000000006',
    'e1100000-0000-4000-8000-000000000001',
    '1 Tablet', 'BD', 'AFTER_FOOD', '5D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-000000000007',
    'f1100000-0000-4000-8000-000000000007',
    'e1100000-0000-4000-8000-000000000001',
    '1 Tablet', 'BD', 'AFTER_FOOD', '7D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-000000000008',
    'f1100000-0000-4000-8000-000000000008',
    'e1100000-0000-4000-8000-000000000001',
    '1 Tablet', 'TDS', 'AFTER_FOOD', '5D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-000000000009',
    'f1100000-0000-4000-8000-000000000008',
    'e1100000-0000-4000-8000-00000000000c',
    '  5   mL ', 'BD', 'AFTER_FOOD', '5D', null, 'ORAL', 1
  ),
  (
    'f2110000-0000-4000-8000-00000000000a',
    'f1100000-0000-4000-8000-000000000009',
    'e1100000-0000-4000-8000-000000000001',
    '1 Tablet', 'TDS', 'AFTER_FOOD', '5D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-00000000000b',
    'f1100000-0000-4000-8000-000000000009',
    'e1100000-0000-4000-8000-000000000001',
    '1 Tablet', 'BD', 'AFTER_FOOD', 'CUSTOM', 'Every alternate day for three weeks', 'ORAL', 1
  ),
  (
    'f2110000-0000-4000-8000-00000000000c',
    'f1100000-0000-4000-8000-00000000000a',
    'e1100000-0000-4000-8000-000000000001',
    '1 Tablet', 'OD', 'BEFORE_FOOD', '7D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-00000000000d',
    'f1100000-0000-4000-8000-00000000000a',
    'e1100000-0000-4000-8000-000000000005',
    '1 Tablet', 'OD', 'BEDTIME', 'CUSTOM', 'For ten days, then review', 'ORAL', 1
  ),
  (
    'f2110000-0000-4000-8000-00000000000e',
    'f1100000-0000-4000-8000-00000000000b',
    'e1100000-0000-4000-8000-000000000001',
    '1 Tablet', 'OD', 'BEFORE_FOOD', '7D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-00000000000f',
    'f1100000-0000-4000-8000-00000000000b',
    'e1100000-0000-4000-8000-000000000011',
    '1 drop', 'TDS', null, '7D', null, 'OPHTHALMIC', 1
  ),
  (
    'f2110000-0000-4000-8000-000000000010',
    'f1100000-0000-4000-8000-00000000000b',
    'e1100000-0000-4000-8000-00000000000a',
    '2 puffs', 'BD', null, '2W', null, 'INHALATION', 2
  ),
  (
    'f2110000-0000-4000-8000-000000000011',
    'f1100000-0000-4000-8000-00000000000c',
    'e1100000-0000-4000-8000-000000000005',
    '½ Tablet', 'OD', 'BEDTIME', '7D', null, 'ORAL', 0
  ),
  (
    'f2110000-0000-4000-8000-000000000012',
    'f1100000-0000-4000-8000-00000000000c',
    'e1100000-0000-4000-8000-00000000000f',
    'Thin layer', 'BD', null, '10D', null, 'TOPICAL', 1
  ),
  (
    'f2110000-0000-4000-8000-000000000013',
    'f1100000-0000-4000-8000-00000000000c',
    'e1100000-0000-4000-8000-000000000013',
    '2 drops', 'TDS', null, '5D', null, 'NASAL', 2
  );

-- Drafts f110...0003 and f110...0005 stay editable.
update public.prescriptions as prescriptions
set
  is_finalized = true,
  finalized_at = history.finalized_at
from (
  values
    ('f1100000-0000-4000-8000-000000000001'::uuid, '2026-01-10 09:00:00+00'::timestamptz),
    ('f1100000-0000-4000-8000-000000000002'::uuid, '2026-01-10 09:05:00+00'::timestamptz),
    ('f1100000-0000-4000-8000-000000000004'::uuid, '2026-02-14 09:00:00+00'::timestamptz),
    ('f1100000-0000-4000-8000-000000000006'::uuid, '2026-03-20 09:00:00+00'::timestamptz),
    ('f1100000-0000-4000-8000-000000000007'::uuid, '2026-03-20 09:10:00+00'::timestamptz),
    ('f1100000-0000-4000-8000-000000000008'::uuid, '2026-04-02 09:00:00+00'::timestamptz),
    ('f1100000-0000-4000-8000-000000000009'::uuid, '2026-05-08 09:00:00+00'::timestamptz),
    ('f1100000-0000-4000-8000-00000000000a'::uuid, '2026-06-12 09:00:00+00'::timestamptz),
    ('f1100000-0000-4000-8000-00000000000b'::uuid, '2026-07-01 09:00:00+00'::timestamptz),
    ('f1100000-0000-4000-8000-00000000000c'::uuid, '2026-08-18 09:00:00+00'::timestamptz)
) as history(prescription_id, finalized_at)
where prescriptions.prescription_id = history.prescription_id;
