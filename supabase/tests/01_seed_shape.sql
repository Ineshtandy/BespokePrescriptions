-- High-level checks for the development seed.
-- These tests expect `supabase db reset` to have loaded supabase/seeds.

begin;
select no_plan();

select is(
  (select name from public.clinics where clinic_id = 'c1100000-0000-4000-8000-000000000001'),
  'Demo Clinic',
  'synthetic clinic is Demo Clinic'
);

select results_eq(
  $$ select full_name from public.profiles order by full_name $$,
  array['Admin A', 'Assistant A', 'Doctor A', 'Doctor B']::text[],
  'four primary staff profiles exist'
);

select results_eq(
  $$
    select p.full_name, m.role::text
    from public.clinic_members as m
    join public.profiles as p on p.id = m.profile_id
    where m.clinic_id = 'c1100000-0000-4000-8000-000000000001'
    order by p.full_name
  $$,
  $$
    select *
    from (values
      ('Admin A', 'admin'),
      ('Assistant A', 'assistant'),
      ('Doctor A', 'doctor'),
      ('Doctor B', 'doctor')
    ) as expected(full_name, role)
  $$,
  'each seeded staff member has one role in Demo Clinic'
);

select ok(
  exists (
    select 1
    from public.clinical_codes
    where clinic_id is null
      and code_type = 'duration'
      and code = 'CUSTOM'
  ),
  'system duration code CUSTOM exists'
);

select is(
  (select count(*)::integer from public.clinical_codes where clinic_id is null),
  23,
  'system vocabulary has the seeded code count'
);

select is(
  (select count(*)::integer from public.medicines),
  20,
  'development medicine catalogue has 20 entries'
);

select is((select count(*)::integer from public.patients), 5, 'five fictional patients');
select is((select count(*)::integer from public.visits), 8, 'eight fictional visits');

select is(
  (select count(*)::integer from public.visits where patient_id = 'b1100000-0000-4000-8000-000000000001'),
  3,
  'one patient has multiple visits'
);

select is(
  (select count(*)::integer from public.visits where doctor_id = 'a1100000-0000-4000-8000-000000000001'),
  6,
  'Doctor A has several visits'
);

select is(
  (select count(*)::integer from public.visits where doctor_id = 'a1100000-0000-4000-8000-000000000002'),
  2,
  'Doctor B has visits'
);

select ok(
  exists (select 1 from public.prescriptions where is_finalized = false),
  'at least one draft prescription exists'
);

select ok(
  exists (
    select 1
    from public.prescriptions
    where is_finalized = false
      and prescription_id in (select prescription_id from public.prescription_items)
  ),
  'at least one draft contains an item'
);

select ok(
  exists (
    select 1
    from public.prescriptions as prescriptions
    where is_finalized = false
      and not exists (
        select 1
        from public.prescription_items as items
        where items.prescription_id = prescriptions.prescription_id
      )
  ),
  'an empty draft prescription exists'
);

select ok(
  exists (
    select 1
    from public.prescriptions
    group by visit_id
    having count(*) >= 2
  ),
  'at least one visit contains multiple prescriptions'
);

select is(
  (
    select count(*)::integer
    from public.prescription_items as items
    join public.prescriptions as prescriptions
      on prescriptions.prescription_id = items.prescription_id
    join public.visits as visits on visits.visit_id = prescriptions.visit_id
    where visits.doctor_id = 'a1100000-0000-4000-8000-000000000001'
      and prescriptions.is_finalized
      and items.med_id = 'e1100000-0000-4000-8000-000000000001'
      and items.dose_normalized = '1 tablet'
      and items.frequency_code = 'BD'
      and items.timing_code = 'AFTER_FOOD'
      and items.duration_code = '5D'
      and items.route_code = 'ORAL'
  ),
  4,
  'Doctor A has four finalized uses of the leading Paracetamol combination'
);

select is(
  (
    select count(*)::integer
    from public.prescription_items as items
    join public.prescriptions as prescriptions
      on prescriptions.prescription_id = items.prescription_id
    join public.visits as visits on visits.visit_id = prescriptions.visit_id
    where visits.doctor_id = 'a1100000-0000-4000-8000-000000000001'
      and prescriptions.is_finalized
      and items.med_id = 'e1100000-0000-4000-8000-000000000001'
      and items.dose_normalized = '1 tablet'
      and items.frequency_code = 'TDS'
      and items.timing_code = 'AFTER_FOOD'
      and items.duration_code = '5D'
      and items.route_code = 'ORAL'
  ),
  2,
  'Doctor A has two finalized uses of the second Paracetamol combination'
);

select is(
  (
    select count(*)::integer
    from public.prescription_items as items
    join public.prescriptions as prescriptions
      on prescriptions.prescription_id = items.prescription_id
    join public.visits as visits on visits.visit_id = prescriptions.visit_id
    where visits.doctor_id = 'a1100000-0000-4000-8000-000000000001'
      and prescriptions.is_finalized
      and items.med_id = 'e1100000-0000-4000-8000-000000000001'
      and items.frequency_code = 'BD'
      and items.timing_code = 'AFTER_FOOD'
      and items.duration_code = '7D'
      and items.route_code = 'ORAL'
  ),
  1,
  'Doctor A has one finalized use of the third Paracetamol combination'
);

select is(
  (
    select count(*)::integer
    from public.prescription_items as items
    join public.prescriptions as prescriptions
      on prescriptions.prescription_id = items.prescription_id
    join public.visits as visits on visits.visit_id = prescriptions.visit_id
    where visits.doctor_id = 'a1100000-0000-4000-8000-000000000002'
      and prescriptions.is_finalized
      and items.med_id = 'e1100000-0000-4000-8000-000000000001'
      and items.frequency_code = 'OD'
      and items.timing_code = 'BEFORE_FOOD'
      and items.duration_code = '7D'
      and items.route_code = 'ORAL'
  ),
  2,
  'Doctor B history for the same medicine is a different combination'
);

select results_eq(
  $$
    select duration_note
    from public.prescription_items
    where duration_code = 'CUSTOM'
    order by duration_note
  $$,
  array['Every alternate day for three weeks', 'For ten days, then review']::text[],
  'different CUSTOM notes stay distinct'
);

select ok(
  exists (
    select 1 from public.prescription_items
    where dose_text = '1 Tablet' and dose_normalized = '1 tablet'
  ),
  'seeded "1 Tablet" normalized to "1 tablet"'
);

select ok(
  exists (
    select 1 from public.prescription_items
    where dose_text = '  5   mL ' and dose_normalized = '5 ml'
  ),
  'seeded spaced millilitre dose normalized to "5 ml"'
);

select ok(
  exists (
    select 1 from public.prescription_items
    where dose_text = '½ Tablet' and dose_normalized = '½ tablet'
  ),
  'seeded half-tablet dose keeps the fraction and lowercases the unit'
);

select ok(
  (
    select bool_and(relrowsecurity)
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'public'
      and class.relname in (
        'profiles', 'clinics', 'clinic_members', 'patients', 'visits',
        'medicines', 'clinical_codes', 'prescriptions', 'prescription_items'
      )
  ),
  'row-level security is enabled on every application table'
);

select * from finish();
rollback;
