-- Row-level security and table-privilege checks.
-- Each identity is applied with auth.uid() under the authenticated or anon role.

begin;
select no_plan();

create function pg_temp.exec_as(actor uuid, statement text)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  affected integer := 0;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  execute 'set local role authenticated';
  execute statement;
  get diagnostics affected = row_count;
  execute 'reset role';
  return affected;
exception
  when others then
    begin
      execute 'reset role';
    exception
      when others then
        null;
    end;
    raise;
end;
$$;

create function pg_temp.count_as(actor uuid, query text)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  n bigint;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  execute 'set local role authenticated';
  execute query into n;
  execute 'reset role';
  return n;
exception
  when others then
    begin
      execute 'reset role';
    exception
      when others then
        null;
    end;
    raise;
end;
$$;

create function pg_temp.exec_as_anon(statement text)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  affected integer := 0;
begin
  execute 'set local role anon';
  execute statement;
  get diagnostics affected = row_count;
  execute 'reset role';
  return affected;
exception
  when others then
    begin
      execute 'reset role';
    exception
      when others then
        null;
    end;
    raise;
end;
$$;

select throws_ok(
  $$ select pg_temp.exec_as_anon('select * from public.patients') $$,
  '42501',
  NULL,
  'anon cannot read patients'
);
select throws_ok(
  $$ select pg_temp.exec_as_anon('select * from public.medicines') $$,
  '42501',
  NULL,
  'anon cannot read medicines'
);
select throws_ok(
  $$ select pg_temp.exec_as_anon('select * from public.prescriptions') $$,
  '42501',
  NULL,
  'anon cannot read prescriptions'
);
select throws_ok(
  $t$ select pg_temp.exec_as_anon($s$ insert into public.patients (clinic_id, patient_number, name) values ('c1100000-0000-4000-8000-000000000001', 'NOPE', 'Nope') $s$) $t$,
  '42501',
  NULL,
  'anon cannot create patients'
);
select throws_ok(
  $t$ select pg_temp.exec_as_anon($s$ insert into public.visits (clinic_id, patient_id, doctor_id, created_by, visit_date) values ('c1100000-0000-4000-8000-000000000001', 'b1100000-0000-4000-8000-000000000001', 'a1100000-0000-4000-8000-000000000001', 'a1100000-0000-4000-8000-000000000001', '2026-09-06') $s$) $t$,
  '42501',
  NULL,
  'anon cannot create visits'
);
select throws_ok(
  $t$ select pg_temp.exec_as_anon($s$ insert into public.prescriptions (visit_id, sequence_number) values ('d1100000-0000-4000-8000-000000000001', 9) $s$) $t$,
  '42501',
  NULL,
  'anon cannot create prescriptions'
);
select throws_ok(
  $t$ select pg_temp.exec_as_anon($s$ insert into public.prescription_items (prescription_id, med_id, order_index) values ('f1100000-0000-4000-8000-000000000003', 'e1100000-0000-4000-8000-000000000001', 9) $s$) $t$,
  '42501',
  NULL,
  'anon cannot create prescription items'
);
select throws_ok(
  $t$ select pg_temp.exec_as_anon($s$ select public.finalize_prescription('f1100000-0000-4000-8000-000000000003') $s$) $t$,
  '42501',
  NULL,
  'anon cannot execute finalize_prescription'
);

insert into auth.users (id) values
  ('aa000000-0000-4000-8000-000000000041'),
  ('aa000000-0000-4000-8000-000000000042'),
  ('aa000000-0000-4000-8000-000000000043'),
  ('aa000000-0000-4000-8000-000000000044'),
  ('aa000000-0000-4000-8000-000000000045'),
  ('aa000000-0000-4000-8000-000000000046');
insert into public.profiles (id, full_name) values
  ('aa000000-0000-4000-8000-000000000041', 'RLS Doctor A'),
  ('aa000000-0000-4000-8000-000000000042', 'RLS Doctor B'),
  ('aa000000-0000-4000-8000-000000000043', 'RLS Assistant'),
  ('aa000000-0000-4000-8000-000000000044', 'RLS Admin'),
  ('aa000000-0000-4000-8000-000000000045', 'RLS Outside Doctor'),
  ('aa000000-0000-4000-8000-000000000046', 'RLS Lone User');
insert into public.clinics (clinic_id, name) values
  ('cc000000-0000-4000-8000-000000000041', 'RLS Clinic A'),
  ('cc000000-0000-4000-8000-000000000042', 'RLS Clinic B');
insert into public.clinic_members (clinic_id, profile_id, role) values
  ('cc000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000041', 'doctor'),
  ('cc000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000042', 'doctor'),
  ('cc000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000043', 'assistant'),
  ('cc000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000044', 'admin'),
  ('cc000000-0000-4000-8000-000000000042', 'aa000000-0000-4000-8000-000000000045', 'doctor');
insert into public.patients (patient_id, clinic_id, patient_number, name) values
  ('bb000000-0000-4000-8000-000000000041', 'cc000000-0000-4000-8000-000000000041', 'R-001', 'RLS Patient A'),
  ('bb000000-0000-4000-8000-000000000042', 'cc000000-0000-4000-8000-000000000042', 'R-001', 'RLS Patient B');
insert into public.visits (visit_id, clinic_id, patient_id, doctor_id, created_by, visit_date) values
  (
    'dd000000-0000-4000-8000-000000000041',
    'cc000000-0000-4000-8000-000000000041',
    'bb000000-0000-4000-8000-000000000041',
    'aa000000-0000-4000-8000-000000000041',
    'aa000000-0000-4000-8000-000000000041',
    '2026-09-07'
  ),
  (
    'dd000000-0000-4000-8000-000000000042',
    'cc000000-0000-4000-8000-000000000041',
    'bb000000-0000-4000-8000-000000000041',
    'aa000000-0000-4000-8000-000000000042',
    'aa000000-0000-4000-8000-000000000042',
    '2026-09-08'
  ),
  (
    'dd000000-0000-4000-8000-000000000043',
    'cc000000-0000-4000-8000-000000000042',
    'bb000000-0000-4000-8000-000000000042',
    'aa000000-0000-4000-8000-000000000045',
    'aa000000-0000-4000-8000-000000000045',
    '2026-09-09'
  );
insert into public.clinical_codes (clinic_id, code_type, code, label) values
  ('cc000000-0000-4000-8000-000000000041', 'frequency', 'LOCAL_A', 'Clinic A only'),
  ('cc000000-0000-4000-8000-000000000042', 'frequency', 'LOCAL_B', 'Clinic B only');

select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.clinics where clinic_id = 'cc000000-0000-4000-8000-000000000042' $$), 0::bigint, 'Clinic A doctor cannot read Clinic B');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.clinic_members where clinic_id = 'cc000000-0000-4000-8000-000000000042' $$), 0::bigint, 'Clinic A doctor cannot read Clinic B memberships');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.profiles where id = 'aa000000-0000-4000-8000-000000000045' $$), 0::bigint, 'Clinic A doctor cannot read an outside profile');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.profiles where id = 'aa000000-0000-4000-8000-000000000041' $$), 1::bigint, 'a user can read their own profile');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000046', $$ select count(*) from public.profiles $$), 1::bigint, 'a user with no clinic sees only their own profile');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.patients where patient_id = 'bb000000-0000-4000-8000-000000000042' $$), 0::bigint, 'Clinic A doctor cannot read a Clinic B patient');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.visits where visit_id = 'dd000000-0000-4000-8000-000000000043' $$), 0::bigint, 'Clinic A doctor cannot read a Clinic B visit');

select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $$ insert into public.patients (clinic_id, patient_number, name) values ('cc000000-0000-4000-8000-000000000041', 'R-101', 'Doctor Insert') $$), 1, 'doctor can insert a same-clinic patient');
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $$ update public.patients set name = 'Doctor Updated' where patient_number = 'R-101' $$), 1, 'doctor can update a same-clinic patient');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $s$ delete from public.patients where patient_number = 'R-101' $s$) $t$, '42501', NULL, 'doctor cannot delete a patient');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $s$ update public.patients set clinic_id = 'cc000000-0000-4000-8000-000000000042' where patient_number = 'R-101' $s$) $t$, '42501', NULL, 'doctor cannot move a patient to another clinic');

select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $$ insert into public.patients (clinic_id, patient_number, name) values ('cc000000-0000-4000-8000-000000000041', 'R-102', 'Assistant Insert') $$), 1, 'assistant can insert a same-clinic patient');
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $$ update public.patients set name = 'Assistant Updated' where patient_number = 'R-102' $$), 1, 'assistant can update a same-clinic patient');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $s$ delete from public.patients where patient_number = 'R-102' $s$) $t$, '42501', NULL, 'assistant cannot delete a patient');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $s$ update public.patients set clinic_id = 'cc000000-0000-4000-8000-000000000042' where patient_number = 'R-102' $s$) $t$, '42501', NULL, 'assistant cannot move a patient to another clinic');

select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $$ insert into public.patients (clinic_id, patient_number, name) values ('cc000000-0000-4000-8000-000000000041', 'R-103', 'Admin Insert') $$), 1, 'admin can insert a same-clinic patient');
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $$ update public.patients set name = 'Admin Updated' where patient_number = 'R-103' $$), 1, 'admin can update a same-clinic patient');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $s$ delete from public.patients where patient_number = 'R-103' $s$) $t$, '42501', NULL, 'admin cannot delete a patient');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $s$ update public.patients set clinic_id = 'cc000000-0000-4000-8000-000000000042' where patient_number = 'R-103' $s$) $t$, '42501', NULL, 'admin cannot move a patient to another clinic');

select is(
  pg_temp.exec_as(
    'aa000000-0000-4000-8000-000000000041',
    $$ insert into public.visits (clinic_id, patient_id, doctor_id, created_by, visit_date) values ('cc000000-0000-4000-8000-000000000041', 'bb000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000041', '2026-09-10') $$
  ),
  1,
  'doctor can insert a same-clinic visit'
);
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $$ update public.visits set patient_note = 'doctor note' where visit_date = '2026-09-10' $$), 1, 'doctor can update a same-clinic visit');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $s$ delete from public.visits where visit_date = '2026-09-10' $s$) $t$, '42501', NULL, 'doctor cannot delete a visit');
select throws_ok(
  $t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $s$ update public.visits set clinic_id = 'cc000000-0000-4000-8000-000000000042', patient_id = 'bb000000-0000-4000-8000-000000000042', doctor_id = 'aa000000-0000-4000-8000-000000000045', created_by = 'aa000000-0000-4000-8000-000000000045' where visit_date = '2026-09-10' $s$) $t$,
  '42501',
  NULL,
  'doctor cannot move a visit to another clinic'
);

select is(
  pg_temp.exec_as(
    'aa000000-0000-4000-8000-000000000043',
    $$ insert into public.visits (clinic_id, patient_id, doctor_id, created_by, visit_date) values ('cc000000-0000-4000-8000-000000000041', 'bb000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000043', '2026-09-11') $$
  ),
  1,
  'assistant can insert a same-clinic visit'
);
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $$ update public.visits set patient_note = 'assistant note' where visit_date = '2026-09-11' $$), 1, 'assistant can update a same-clinic visit');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $s$ delete from public.visits where visit_date = '2026-09-11' $s$) $t$, '42501', NULL, 'assistant cannot delete a visit');
select throws_ok(
  $t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $s$ insert into public.visits (clinic_id, patient_id, doctor_id, created_by, visit_date) values ('cc000000-0000-4000-8000-000000000041', 'bb000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000043', 'aa000000-0000-4000-8000-000000000043', '2026-09-12') $s$) $t$,
  '23514',
  NULL,
  'assistant cannot assign themselves as the visit doctor'
);

select is(
  pg_temp.exec_as(
    'aa000000-0000-4000-8000-000000000044',
    $$ insert into public.visits (clinic_id, patient_id, doctor_id, created_by, visit_date) values ('cc000000-0000-4000-8000-000000000041', 'bb000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000044', '2026-09-13') $$
  ),
  1,
  'admin can insert a same-clinic visit'
);
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $$ update public.visits set patient_note = 'admin note' where visit_date = '2026-09-13' $$), 1, 'admin can update a same-clinic visit');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $s$ delete from public.visits where visit_date = '2026-09-13' $s$) $t$, '42501', NULL, 'admin cannot delete a visit');
select throws_ok(
  $t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $s$ insert into public.visits (clinic_id, patient_id, doctor_id, created_by, visit_date) values ('cc000000-0000-4000-8000-000000000041', 'bb000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000044', 'aa000000-0000-4000-8000-000000000044', '2026-09-14') $s$) $t$,
  '23514',
  NULL,
  'admin cannot assign themselves as the visit doctor'
);

select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $$ insert into public.prescriptions (prescription_id, visit_id, sequence_number, advice_notes) values ('ee000000-0000-4000-8000-000000000041', 'dd000000-0000-4000-8000-000000000041', 1, 'draft one') $$), 1, 'assigned doctor can create a draft');
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $$ insert into public.prescriptions (prescription_id, visit_id, sequence_number) values ('ee000000-0000-4000-8000-000000000042', 'dd000000-0000-4000-8000-000000000041', 2) $$), 1, 'assigned doctor can create a second draft');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 1::bigint, 'assigned doctor can read their draft');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000042', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0::bigint, 'same-clinic doctor cannot read another draft');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000043', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0::bigint, 'assistant cannot read a draft');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000044', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0::bigint, 'admin cannot read a draft');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000045', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0::bigint, 'outside doctor cannot read a draft');
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000042', $$ update public.prescriptions set advice_notes = 'nope' where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0, 'same-clinic doctor cannot update another draft');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000042', $s$ insert into public.prescriptions (visit_id, sequence_number) values ('dd000000-0000-4000-8000-000000000041', 3) $s$) $t$, '42501', NULL, 'same-clinic doctor cannot prescribe on another doctor visit');

select is(
  pg_temp.exec_as(
    'aa000000-0000-4000-8000-000000000041',
    $$ insert into public.prescription_items (id, prescription_id, med_id, order_index, dose_text, frequency_code, timing_code, duration_code, route_code) values ('ff000000-0000-4000-8000-000000000041', 'ee000000-0000-4000-8000-000000000041', 'e1100000-0000-4000-8000-000000000001', 0, '1 Tablet', 'BD', 'AFTER_FOOD', '5D', 'ORAL') $$
  ),
  1,
  'assigned doctor can add a draft item'
);
select is(
  (select dose_normalized from public.prescription_items where id = 'ff000000-0000-4000-8000-000000000041'),
  '1 tablet',
  'dose normalization still runs under row-level security'
);
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $$ update public.prescription_items set notes = 'with water' where id = 'ff000000-0000-4000-8000-000000000041' $$), 1, 'assigned doctor can edit a draft item');
select is(
  pg_temp.exec_as(
    'aa000000-0000-4000-8000-000000000041',
    $$ insert into public.prescription_items (id, prescription_id, med_id, order_index, duration_code, duration_note) values ('ff000000-0000-4000-8000-000000000042', 'ee000000-0000-4000-8000-000000000041', 'e1100000-0000-4000-8000-000000000001', 1, 'CUSTOM', 'Every alternate day for three weeks') $$
  ),
  1,
  'CUSTOM duration validation still accepts a note under row-level security'
);
select throws_ok(
  $t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $s$ insert into public.prescription_items (prescription_id, med_id, order_index, frequency_code) values ('ee000000-0000-4000-8000-000000000041', 'e1100000-0000-4000-8000-000000000001', 2, 'NO_SUCH') $s$) $t$,
  '23514',
  NULL,
  'clinical-code validation still rejects an unknown code under row-level security'
);
select is(
  pg_temp.exec_as(
    'aa000000-0000-4000-8000-000000000041',
    $$ update public.prescription_items set order_index = case order_index when 0 then 1 else 0 end where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$
  ),
  2,
  'assigned doctor can reorder draft items'
);
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $$ update public.prescription_items set prescription_id = 'ee000000-0000-4000-8000-000000000042', order_index = 0 where id = 'ff000000-0000-4000-8000-000000000042' $$), 1, 'assigned doctor can move an item between their drafts');
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $$ delete from public.prescription_items where id = 'ff000000-0000-4000-8000-000000000042' $$), 1, 'assigned doctor can delete a draft item');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000042', $$ select count(*) from public.prescription_items where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0::bigint, 'same-clinic doctor cannot read draft items');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000043', $$ select count(*) from public.prescription_items where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0::bigint, 'assistant cannot read draft items');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000045', $$ select count(*) from public.prescription_items where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0::bigint, 'outside doctor cannot read draft items');

select pg_temp.exec_as(
  'aa000000-0000-4000-8000-000000000041',
  $$ select public.finalize_prescription('ee000000-0000-4000-8000-000000000041') $$
);
select is(
  (select is_finalized from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041'),
  true,
  'assigned doctor can finalize through the controlled function'
);

select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000042', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 1::bigint, 'same-clinic doctor can read finalized history');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000043', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 1::bigint, 'assistant can read finalized history');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000044', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 1::bigint, 'admin can read finalized history');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000042', $$ select count(*) from public.prescription_items where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 1::bigint, 'same-clinic doctor can read finalized items');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000043', $$ select count(*) from public.prescription_items where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 1::bigint, 'assistant can read finalized items');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000045', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0::bigint, 'outside doctor cannot read finalized history');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000045', $$ select count(*) from public.prescription_items where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0::bigint, 'outside doctor cannot read finalized items');
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000042', $$ update public.prescriptions set advice_notes = 'changed' where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0, 'same-clinic doctor cannot change finalized history');
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $$ update public.prescription_items set notes = 'changed' where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0, 'assistant cannot change finalized items');
select is(pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $$ delete from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000041' $$), 0, 'admin cannot delete finalized history');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000042' $$), 1::bigint, 'the second draft remains private to its doctor');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000042', $$ select count(*) from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000042' $$), 0::bigint, 'the remaining draft stays hidden from the other doctor');

select cmp_ok(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.medicines $$), '>', 0::bigint, 'a clinic doctor can read the medicine catalogue');
select cmp_ok(pg_temp.count_as('aa000000-0000-4000-8000-000000000043', $$ select count(*) from public.medicines $$), '>', 0::bigint, 'an assistant can read the medicine catalogue');
select cmp_ok(pg_temp.count_as('aa000000-0000-4000-8000-000000000044', $$ select count(*) from public.medicines $$), '>', 0::bigint, 'an admin can read the medicine catalogue');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000046', $$ select count(*) from public.medicines $$), 0::bigint, 'a user with no clinic cannot read medicines');
select cmp_ok(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.clinical_codes where clinic_id is null and code = 'BD' $$), '>', 0::bigint, 'a clinic member can read system codes');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.clinical_codes where code = 'LOCAL_A' $$), 1::bigint, 'a member can read their clinic-specific code');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000041', $$ select count(*) from public.clinical_codes where code = 'LOCAL_B' $$), 0::bigint, 'a member cannot read another clinic code');
select is(pg_temp.count_as('aa000000-0000-4000-8000-000000000045', $$ select count(*) from public.clinical_codes where code = 'LOCAL_A' $$), 0::bigint, 'the other clinic cannot read Clinic A code');

select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $s$ update public.medicines set med_name = 'Changed' $s$) $t$, '42501', NULL, 'doctor cannot update medicines');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $s$ delete from public.medicines $s$) $t$, '42501', NULL, 'assistant cannot delete medicines');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $s$ insert into public.medicines (med_name) values ('New medicine') $s$) $t$, '42501', NULL, 'admin cannot insert medicines');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $s$ update public.clinical_codes set label = 'Changed' $s$) $t$, '42501', NULL, 'doctor cannot update clinical codes');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $s$ delete from public.clinical_codes $s$) $t$, '42501', NULL, 'assistant cannot delete clinical codes');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $s$ insert into public.clinical_codes (code_type, code, label) values ('frequency', 'NEW', 'New') $s$) $t$, '42501', NULL, 'admin cannot insert clinical codes');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $s$ update public.clinic_members set role = 'admin' where profile_id = 'aa000000-0000-4000-8000-000000000041' $s$) $t$, '42501', NULL, 'doctor cannot promote themselves');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000043', $s$ update public.clinic_members set role = 'doctor' where profile_id = 'aa000000-0000-4000-8000-000000000043' $s$) $t$, '42501', NULL, 'assistant cannot change their role');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $s$ update public.clinic_members set role = 'assistant' where profile_id = 'aa000000-0000-4000-8000-000000000042' $s$) $t$, '42501', NULL, 'admin cannot change another membership');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $s$ update public.profiles set full_name = 'Changed' $s$) $t$, '42501', NULL, 'doctor cannot edit profiles');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000044', $s$ update public.clinics set name = 'Changed' $s$) $t$, '42501', NULL, 'admin cannot edit clinics');
select throws_ok($t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000041', $s$ delete from public.clinic_members where profile_id = 'aa000000-0000-4000-8000-000000000043' $s$) $t$, '42501', NULL, 'doctor cannot delete a membership');

select * from finish();
rollback;
