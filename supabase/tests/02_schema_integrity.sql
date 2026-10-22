-- Product invariants for identity, clinic membership, visits, and ordering.
-- Fixtures are created in this transaction and rolled back.

begin;
select no_plan();

insert into auth.users (id) values
  ('aa000000-0000-4000-8000-000000000001'),
  ('aa000000-0000-4000-8000-000000000002'),
  ('aa000000-0000-4000-8000-000000000003'),
  ('aa000000-0000-4000-8000-000000000004');

insert into public.profiles (id, full_name) values
  ('aa000000-0000-4000-8000-000000000001', 'Schema Doctor'),
  ('aa000000-0000-4000-8000-000000000002', 'Schema Assistant'),
  ('aa000000-0000-4000-8000-000000000003', 'Schema Admin'),
  ('aa000000-0000-4000-8000-000000000004', 'Schema Other Doctor');

insert into public.clinics (clinic_id, name) values
  ('cc000000-0000-4000-8000-000000000001', 'Schema Clinic A'),
  ('cc000000-0000-4000-8000-000000000002', 'Schema Clinic B');

insert into public.clinic_members (clinic_id, profile_id, role) values
  ('cc000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000001', 'doctor'),
  ('cc000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000002', 'assistant'),
  ('cc000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000003', 'admin'),
  ('cc000000-0000-4000-8000-000000000002', 'aa000000-0000-4000-8000-000000000004', 'doctor');

insert into public.patients (patient_id, clinic_id, patient_number, name) values
  ('bb000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-000000000001', 'T-001', 'Schema Patient'),
  ('bb000000-0000-4000-8000-000000000002', 'cc000000-0000-4000-8000-000000000002', 'T-001', 'Other Clinic Patient');

select throws_ok(
  $$ insert into public.profiles (id, full_name) values ('99999999-9999-4999-8999-999999999999', 'Missing Auth User') $$,
  '23503',
  NULL,
  'a profile requires a matching auth user'
);

select throws_ok(
  $$
    insert into public.clinic_members (clinic_id, profile_id, role)
    values ('cc000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000001', 'admin')
  $$,
  '23505',
  NULL,
  'a user has one membership per clinic'
);

select throws_ok(
  $$
    insert into public.clinic_members (clinic_id, profile_id, role)
    values ('cc000000-0000-4000-8000-000000000002', 'aa000000-0000-4000-8000-000000000001', 'nurse')
  $$,
  '22P02',
  NULL,
  'membership role must be doctor, assistant, or admin'
);

select throws_ok(
  $$
    insert into public.patients (clinic_id, patient_number, name)
    values ('cc000000-0000-4000-8000-000000000001', 'T-001', 'Duplicate Number')
  $$,
  '23505',
  NULL,
  'patient numbers are unique inside a clinic'
);

select lives_ok(
  $$
    insert into public.patients (clinic_id, patient_number, name)
    values ('cc000000-0000-4000-8000-000000000002', 'T-009', 'Same Number Other Clinic')
  $$,
  'the same patient number may exist in another clinic'
);

select throws_ok(
  $$
    insert into public.visits (clinic_id, patient_id, doctor_id, created_by, visit_date)
    values (
      'cc000000-0000-4000-8000-000000000001',
      'bb000000-0000-4000-8000-000000000002',
      'aa000000-0000-4000-8000-000000000001',
      'aa000000-0000-4000-8000-000000000001',
      '2026-09-01'
    )
  $$,
  '23503',
  NULL,
  'a visit patient must belong to the visit clinic'
);

select throws_ok(
  $$
    insert into public.visits (clinic_id, patient_id, doctor_id, created_by, visit_date)
    values (
      'cc000000-0000-4000-8000-000000000001',
      'bb000000-0000-4000-8000-000000000001',
      'aa000000-0000-4000-8000-000000000004',
      'aa000000-0000-4000-8000-000000000001',
      '2026-09-01'
    )
  $$,
  '23503',
  NULL,
  'a visit doctor must be a member of the visit clinic'
);

select throws_ok(
  $$
    insert into public.visits (clinic_id, patient_id, doctor_id, created_by, visit_date)
    values (
      'cc000000-0000-4000-8000-000000000001',
      'bb000000-0000-4000-8000-000000000001',
      'aa000000-0000-4000-8000-000000000002',
      'aa000000-0000-4000-8000-000000000001',
      '2026-09-01'
    )
  $$,
  '23514',
  NULL,
  'an assistant cannot be the assigned visit doctor'
);

select throws_ok(
  $$
    insert into public.visits (clinic_id, patient_id, doctor_id, created_by, visit_date)
    values (
      'cc000000-0000-4000-8000-000000000001',
      'bb000000-0000-4000-8000-000000000001',
      'aa000000-0000-4000-8000-000000000003',
      'aa000000-0000-4000-8000-000000000001',
      '2026-09-01'
    )
  $$,
  '23514',
  NULL,
  'an admin cannot be the assigned visit doctor'
);

insert into public.visits (visit_id, clinic_id, patient_id, doctor_id, created_by, visit_date)
values (
  'dd000000-0000-4000-8000-000000000001',
  'cc000000-0000-4000-8000-000000000001',
  'bb000000-0000-4000-8000-000000000001',
  'aa000000-0000-4000-8000-000000000001',
  'aa000000-0000-4000-8000-000000000001',
  '2026-09-02'
);

insert into public.prescriptions (prescription_id, visit_id, sequence_number)
values ('ee000000-0000-4000-8000-000000000001', 'dd000000-0000-4000-8000-000000000001', 1);

select throws_ok(
  $$
    insert into public.prescriptions (visit_id, sequence_number)
    values ('dd000000-0000-4000-8000-000000000001', 0)
  $$,
  '23514',
  NULL,
  'prescription sequence numbers are positive'
);

select throws_ok(
  $$
    insert into public.prescriptions (visit_id, sequence_number)
    values ('dd000000-0000-4000-8000-000000000001', 1)
  $$,
  '23505',
  NULL,
  'prescription sequence numbers are unique within a visit'
);

select throws_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index
    ) values (
      'ee000000-0000-4000-8000-000000000001',
      'e1100000-0000-4000-8000-000000000001',
      -1
    )
  $$,
  '23514',
  NULL,
  'item order starts at zero'
);

insert into public.prescription_items (prescription_id, med_id, order_index)
values (
  'ee000000-0000-4000-8000-000000000001',
  'e1100000-0000-4000-8000-000000000001',
  0
);

select throws_ok(
  $$
    insert into public.prescription_items (prescription_id, med_id, order_index)
    values (
      'ee000000-0000-4000-8000-000000000001',
      'e1100000-0000-4000-8000-000000000002',
      0
    )
  $$,
  '23505',
  NULL,
  'item order is unique within a prescription'
);

select * from finish();
rollback;
