-- Conservative dose normalization and the CUSTOM duration note rule.

begin;
select no_plan();

select is(public.normalize_dose_text('1 Tablet'), '1 tablet', 'mixed case collapses to a lowercase grouping key');
select is(public.normalize_dose_text('  1   tablet '), '1 tablet', 'extra spaces collapse');
select is(public.normalize_dose_text('  5   mL '), '5 ml', 'millilitre unit is lowercased without unit conversion');
select is(public.normalize_dose_text('½ Tablet'), '½ tablet', 'the fraction character is preserved');
select is(public.normalize_dose_text(null), null, 'null dose stays null');

insert into auth.users (id) values ('aa000000-0000-4000-8000-000000000021');
insert into public.profiles (id, full_name) values ('aa000000-0000-4000-8000-000000000021', 'Dose Doctor');
insert into public.clinics (clinic_id, name) values ('cc000000-0000-4000-8000-000000000021', 'Dose Clinic');
insert into public.clinic_members (clinic_id, profile_id, role)
values ('cc000000-0000-4000-8000-000000000021', 'aa000000-0000-4000-8000-000000000021', 'doctor');
insert into public.patients (patient_id, clinic_id, patient_number, name)
values ('bb000000-0000-4000-8000-000000000021', 'cc000000-0000-4000-8000-000000000021', 'D-001', 'Dose Patient');
insert into public.visits (visit_id, clinic_id, patient_id, doctor_id, created_by, visit_date)
values (
  'dd000000-0000-4000-8000-000000000021',
  'cc000000-0000-4000-8000-000000000021',
  'bb000000-0000-4000-8000-000000000021',
  'aa000000-0000-4000-8000-000000000021',
  'aa000000-0000-4000-8000-000000000021',
  '2026-09-04'
);
insert into public.prescriptions (prescription_id, visit_id, sequence_number)
values ('ee000000-0000-4000-8000-000000000021', 'dd000000-0000-4000-8000-000000000021', 1);

select throws_ok(
  $$
    insert into public.prescription_items (prescription_id, med_id, order_index, dose_text)
    values (
      'ee000000-0000-4000-8000-000000000021',
      'e1100000-0000-4000-8000-000000000001',
      0, '   '
    )
  $$,
  '23514',
  NULL,
  'a blank dose is rejected'
);

insert into public.prescription_items (
  id, prescription_id, med_id, order_index, dose_text, dose_normalized
) values (
  'ff000000-0000-4000-8000-000000000021',
  'ee000000-0000-4000-8000-000000000021',
  'e1100000-0000-4000-8000-000000000001',
  1, '1 Tablet', 'HACKED'
);

select is(
  (select dose_normalized from public.prescription_items where id = 'ff000000-0000-4000-8000-000000000021'),
  '1 tablet',
  'a caller-supplied normalized dose is overwritten'
);

update public.prescription_items
set dose_text = '  5   mL '
where id = 'ff000000-0000-4000-8000-000000000021';

select is(
  (select dose_normalized from public.prescription_items where id = 'ff000000-0000-4000-8000-000000000021'),
  '5 ml',
  'changing dose text recalculates the normalized value'
);

select lives_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, duration_code
    ) values (
      'ee000000-0000-4000-8000-000000000021',
      'e1100000-0000-4000-8000-000000000001',
      2, '5D'
    )
  $$,
  'a standard duration does not require a note'
);

select lives_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, duration_code, duration_note
    ) values (
      'ee000000-0000-4000-8000-000000000021',
      'e1100000-0000-4000-8000-000000000001',
      3, 'CUSTOM', 'Every alternate day for three weeks'
    )
  $$,
  'CUSTOM accepts a meaningful note'
);

select lives_ok(
  $$
    insert into public.prescription_items (prescription_id, med_id, order_index)
    values (
      'ee000000-0000-4000-8000-000000000021',
      'e1100000-0000-4000-8000-000000000001',
      4
    )
  $$,
  'a null duration with a null note is valid'
);

select throws_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, duration_code
    ) values (
      'ee000000-0000-4000-8000-000000000021',
      'e1100000-0000-4000-8000-000000000001',
      5, 'CUSTOM'
    )
  $$,
  '23514',
  NULL,
  'CUSTOM without a note is rejected'
);

select throws_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, duration_code, duration_note
    ) values (
      'ee000000-0000-4000-8000-000000000021',
      'e1100000-0000-4000-8000-000000000001',
      6, 'CUSTOM', '   '
    )
  $$,
  '23514',
  NULL,
  'CUSTOM with a blank note is rejected'
);

select throws_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, duration_code, duration_note
    ) values (
      'ee000000-0000-4000-8000-000000000021',
      'e1100000-0000-4000-8000-000000000001',
      7, '5D', 'extra note'
    )
  $$,
  '23514',
  NULL,
  'a standard duration rejects a note'
);

select throws_ok(
  $$
    insert into public.prescription_items (
      prescription_id, med_id, order_index, duration_note
    ) values (
      'ee000000-0000-4000-8000-000000000021',
      'e1100000-0000-4000-8000-000000000001',
      8, 'note without a code'
    )
  $$,
  '23514',
  NULL,
  'a note without a duration code is rejected'
);

insert into public.prescription_items (
  prescription_id, med_id, order_index, duration_code, duration_note
) values (
  'ee000000-0000-4000-8000-000000000021',
  'e1100000-0000-4000-8000-000000000001',
  9, 'CUSTOM', 'For ten days, then review'
);

select is(
  (
    select count(distinct duration_note)::integer
    from public.prescription_items
    where prescription_id = 'ee000000-0000-4000-8000-000000000021'
      and duration_code = 'CUSTOM'
  ),
  2,
  'different CUSTOM notes are stored as different text'
);

select * from finish();
rollback;
