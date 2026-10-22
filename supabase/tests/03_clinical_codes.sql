-- Instruction codes must match a system clinical code of the same type.

begin;
select no_plan();

insert into auth.users (id) values ('aa000000-0000-4000-8000-000000000011');
insert into public.profiles (id, full_name) values ('aa000000-0000-4000-8000-000000000011', 'Code Doctor');
insert into public.clinics (clinic_id, name) values ('cc000000-0000-4000-8000-000000000011', 'Code Clinic');
insert into public.clinic_members (clinic_id, profile_id, role)
values ('cc000000-0000-4000-8000-000000000011', 'aa000000-0000-4000-8000-000000000011', 'doctor');
insert into public.patients (patient_id, clinic_id, patient_number, name)
values ('bb000000-0000-4000-8000-000000000011', 'cc000000-0000-4000-8000-000000000011', 'C-001', 'Code Patient');
insert into public.visits (visit_id, clinic_id, patient_id, doctor_id, created_by, visit_date)
values (
  'dd000000-0000-4000-8000-000000000011',
  'cc000000-0000-4000-8000-000000000011',
  'bb000000-0000-4000-8000-000000000011',
  'aa000000-0000-4000-8000-000000000011',
  'aa000000-0000-4000-8000-000000000011',
  '2026-09-03'
);
insert into public.prescriptions (prescription_id, visit_id, sequence_number)
values ('ee000000-0000-4000-8000-000000000011', 'dd000000-0000-4000-8000-000000000011', 1);
insert into public.clinical_codes (clinic_id, code_type, code, label)
values (
  'cc000000-0000-4000-8000-000000000011',
  'frequency',
  'LOCAL',
  'Clinic only frequency'
);

select lives_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, frequency_code, timing_code, duration_code, route_code
    ) values (
      'ee000000-0000-4000-8000-000000000011',
      'e1100000-0000-4000-8000-000000000001',
      0, 'BD', 'AFTER_FOOD', '5D', 'ORAL'
    )
  $$,
  'seeded system frequency, timing, duration, and route codes are accepted'
);

select throws_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, frequency_code
    ) values (
      'ee000000-0000-4000-8000-000000000011',
      'e1100000-0000-4000-8000-000000000001',
      1, 'NO_SUCH'
    )
  $$,
  '23514',
  NULL,
  'an unknown frequency code is rejected'
);

select throws_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, frequency_code
    ) values (
      'ee000000-0000-4000-8000-000000000011',
      'e1100000-0000-4000-8000-000000000001',
      2, 'ORAL'
    )
  $$,
  '23514',
  NULL,
  'a route code is rejected when used as a frequency'
);

select throws_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, frequency_code
    ) values (
      'ee000000-0000-4000-8000-000000000011',
      'e1100000-0000-4000-8000-000000000001',
      3, 'LOCAL'
    )
  $$,
  '23514',
  NULL,
  'a clinic-specific code is not accepted without a system row'
);

select throws_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, frequency_code
    ) values (
      'ee000000-0000-4000-8000-000000000011',
      'e1100000-0000-4000-8000-000000000001',
      4, '   '
    )
  $$,
  '23514',
  NULL,
  'a blank frequency code is rejected'
);

select lives_ok(
  $$
    insert into public.prescription_items (prescription_id, med_id, order_index)
    values (
      'ee000000-0000-4000-8000-000000000011',
      'e1100000-0000-4000-8000-000000000001',
      5
    )
  $$,
  'null instruction codes are allowed'
);

select * from finish();
rollback;
