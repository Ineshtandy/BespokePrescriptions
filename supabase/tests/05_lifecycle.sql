-- Draft editing, controlled finalization, and finalized immutability.
-- Authorization uses auth.uid() through an authenticated role, not a helper argument.

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
  perform set_config('request.jwt.claim.sub', coalesce(actor::text, ''), true);
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

create function pg_temp.finalize_as(actor uuid, prescription uuid)
returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  stamp timestamptz;
begin
  perform set_config('request.jwt.claim.sub', coalesce(actor::text, ''), true);
  execute 'set local role authenticated';
  execute format(
    'select finalized_at from public.finalize_prescription(%L)',
    prescription
  ) into stamp;
  execute 'reset role';
  return stamp;
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

insert into auth.users (id) values
  ('aa000000-0000-4000-8000-000000000031'),
  ('aa000000-0000-4000-8000-000000000032'),
  ('aa000000-0000-4000-8000-000000000033'),
  ('aa000000-0000-4000-8000-000000000034');
insert into public.profiles (id, full_name) values
  ('aa000000-0000-4000-8000-000000000031', 'Lifecycle Doctor A'),
  ('aa000000-0000-4000-8000-000000000032', 'Lifecycle Doctor B'),
  ('aa000000-0000-4000-8000-000000000033', 'Lifecycle Assistant'),
  ('aa000000-0000-4000-8000-000000000034', 'Lifecycle Admin');
insert into public.clinics (clinic_id, name) values
  ('cc000000-0000-4000-8000-000000000031', 'Lifecycle Clinic');
insert into public.clinic_members (clinic_id, profile_id, role) values
  ('cc000000-0000-4000-8000-000000000031', 'aa000000-0000-4000-8000-000000000031', 'doctor'),
  ('cc000000-0000-4000-8000-000000000031', 'aa000000-0000-4000-8000-000000000032', 'doctor'),
  ('cc000000-0000-4000-8000-000000000031', 'aa000000-0000-4000-8000-000000000033', 'assistant'),
  ('cc000000-0000-4000-8000-000000000031', 'aa000000-0000-4000-8000-000000000034', 'admin');
insert into public.patients (patient_id, clinic_id, patient_number, name) values
  ('bb000000-0000-4000-8000-000000000031', 'cc000000-0000-4000-8000-000000000031', 'L-001', 'Lifecycle Patient');
insert into public.visits (visit_id, clinic_id, patient_id, doctor_id, created_by, visit_date) values
  (
    'dd000000-0000-4000-8000-000000000031',
    'cc000000-0000-4000-8000-000000000031',
    'bb000000-0000-4000-8000-000000000031',
    'aa000000-0000-4000-8000-000000000031',
    'aa000000-0000-4000-8000-000000000031',
    '2026-09-05'
  );
insert into public.prescriptions (prescription_id, visit_id, sequence_number, advice_notes) values
  (
    'ee000000-0000-4000-8000-000000000031',
    'dd000000-0000-4000-8000-000000000031',
    1,
    'Original advice'
  );
insert into public.prescription_items (id, prescription_id, med_id, order_index, dose_text) values
  (
    'ff000000-0000-4000-8000-000000000031',
    'ee000000-0000-4000-8000-000000000031',
    'e1100000-0000-4000-8000-000000000001',
    0,
    '1 Tablet'
  );

select is(
  pg_temp.exec_as(
    'aa000000-0000-4000-8000-000000000031',
    $$ update public.prescriptions set advice_notes = 'Edited draft' where prescription_id = 'ee000000-0000-4000-8000-000000000031' $$
  ),
  1,
  'the assigned doctor can edit a draft'
);

select throws_ok(
  $t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000031', $s$ update public.prescriptions set is_finalized = true, finalized_at = clock_timestamp() where prescription_id = 'ee000000-0000-4000-8000-000000000031' $s$) $t$,
  '42501',
  NULL,
  'an ordinary authenticated update cannot finalize a prescription'
);

select is(
  (
    select is_finalized
    from public.prescriptions
    where prescription_id = 'ee000000-0000-4000-8000-000000000031'
  ),
  false,
  'the draft remains unfinalized after the direct write'
);

select throws_ok(
  $$ select pg_temp.finalize_as('aa000000-0000-4000-8000-000000000032', 'ee000000-0000-4000-8000-000000000031') $$,
  '42501',
  NULL,
  'a different doctor cannot finalize the prescription'
);

select throws_ok(
  $$ select pg_temp.finalize_as('aa000000-0000-4000-8000-000000000033', 'ee000000-0000-4000-8000-000000000031') $$,
  '42501',
  NULL,
  'an assistant cannot finalize the prescription'
);

select throws_ok(
  $$ select pg_temp.finalize_as('aa000000-0000-4000-8000-000000000034', 'ee000000-0000-4000-8000-000000000031') $$,
  '42501',
  NULL,
  'an admin cannot finalize the prescription'
);

select throws_ok(
  $$ select pg_temp.finalize_as(null, 'ee000000-0000-4000-8000-000000000031') $$,
  '42501',
  NULL,
  'an authenticated session without auth.uid() cannot finalize'
);

create temp table pg_temp.lifecycle_stamp (finalized_at timestamptz);
insert into pg_temp.lifecycle_stamp
select pg_temp.finalize_as(
  'aa000000-0000-4000-8000-000000000031',
  'ee000000-0000-4000-8000-000000000031'
);

select ok(
  (select finalized_at is not null from pg_temp.lifecycle_stamp),
  'finalization stores a database timestamp'
);

select is(
  pg_temp.finalize_as(
    'aa000000-0000-4000-8000-000000000031',
    'ee000000-0000-4000-8000-000000000031'
  ),
  (select finalized_at from pg_temp.lifecycle_stamp),
  'finalizing again keeps the original timestamp'
);

select is(
  pg_temp.exec_as(
    'aa000000-0000-4000-8000-000000000031',
    $$ update public.prescriptions set advice_notes = 'after' where prescription_id = 'ee000000-0000-4000-8000-000000000031' $$
  ),
  0,
  'the assigned doctor cannot update a finalized prescription through ordinary access'
);

select is(
  pg_temp.exec_as(
    'aa000000-0000-4000-8000-000000000031',
    $$ delete from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000031' $$
  ),
  0,
  'the assigned doctor cannot delete a finalized prescription through ordinary access'
);

select throws_ok(
  $$
    update public.prescriptions
    set advice_notes = 'owner edit'
    where prescription_id = 'ee000000-0000-4000-8000-000000000031'
  $$,
  '55000',
  NULL,
  'the immutability trigger rejects a finalized prescription update'
);

select throws_ok(
  $$
    delete from public.prescriptions
    where prescription_id = 'ee000000-0000-4000-8000-000000000031'
  $$,
  '55000',
  NULL,
  'the immutability trigger rejects deleting a finalized prescription'
);

select throws_ok(
  $t$ select pg_temp.exec_as('aa000000-0000-4000-8000-000000000031', $s$ insert into public.prescription_items (prescription_id, med_id, order_index) values ('ee000000-0000-4000-8000-000000000031', 'e1100000-0000-4000-8000-000000000001', 1) $s$) $t$,
  '55000',
  NULL,
  'inserting an item into a finalized prescription is rejected'
);

select throws_ok(
  $$
    update public.prescription_items
    set dose_text = '2 tablets'
    where id = 'ff000000-0000-4000-8000-000000000031'
  $$,
  '55000',
  NULL,
  'updating a finalized item is rejected'
);

select throws_ok(
  $$
    delete from public.prescription_items
    where id = 'ff000000-0000-4000-8000-000000000031'
  $$,
  '55000',
  NULL,
  'deleting a finalized item is rejected'
);

select is(
  (select advice_notes from public.prescriptions where prescription_id = 'ee000000-0000-4000-8000-000000000031'),
  'Edited draft',
  'the finalized prescription text is unchanged'
);

select * from finish();
rollback;
