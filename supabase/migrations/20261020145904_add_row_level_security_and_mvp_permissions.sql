-- Ordinary application authorization.
-- Table privileges decide which commands a role may attempt.
-- Row-level security decides which rows an authenticated user may touch.
-- Clinical integrity stays in the existing constraints, triggers, and
-- finalize_prescription(). These helpers only answer membership questions.
-- They run as the owner so policy checks do not recurse through RLS.

create function private.is_clinic_member(target_clinic_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.clinic_members as clinic_members
    where clinic_members.clinic_id = target_clinic_id
      and clinic_members.profile_id = auth.uid()
  );
$$;

create function private.is_any_clinic_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.clinic_members as clinic_members
    where clinic_members.profile_id = auth.uid()
  );
$$;

create function private.shares_clinic(target_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.clinic_members as mine
    join public.clinic_members as theirs
      on theirs.clinic_id = mine.clinic_id
    where mine.profile_id = auth.uid()
      and theirs.profile_id = target_profile_id
  );
$$;

create function private.is_assigned_doctor(target_visit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.visits as visits
    where visits.visit_id = target_visit_id
      and visits.doctor_id = auth.uid()
  );
$$;

create function private.can_read_prescription(
  target_visit_id uuid,
  prescription_is_finalized boolean
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_assigned_doctor(target_visit_id)
    or (
      prescription_is_finalized
      and exists (
        select 1
        from public.visits as visits
        where visits.visit_id = target_visit_id
          and private.is_clinic_member(visits.clinic_id)
      )
    );
$$;

create function private.can_read_prescription_item(target_prescription_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.prescriptions as prescriptions
    where prescriptions.prescription_id = target_prescription_id
      and private.can_read_prescription(
        prescriptions.visit_id,
        prescriptions.is_finalized
      )
  );
$$;

create function private.can_edit_prescription_item(target_prescription_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.prescriptions as prescriptions
    join public.visits as visits
      on visits.visit_id = prescriptions.visit_id
    where prescriptions.prescription_id = target_prescription_id
      and prescriptions.is_finalized = false
      and visits.doctor_id = auth.uid()
  );
$$;

revoke all on function private.is_clinic_member(uuid) from public, anon, authenticated, service_role;
revoke all on function private.is_any_clinic_member() from public, anon, authenticated, service_role;
revoke all on function private.shares_clinic(uuid) from public, anon, authenticated, service_role;
revoke all on function private.is_assigned_doctor(uuid) from public, anon, authenticated, service_role;
revoke all on function private.can_read_prescription(uuid, boolean) from public, anon, authenticated, service_role;
revoke all on function private.can_read_prescription_item(uuid) from public, anon, authenticated, service_role;
revoke all on function private.can_edit_prescription_item(uuid) from public, anon, authenticated, service_role;

grant usage on schema private to authenticated;

grant execute on function private.is_clinic_member(uuid) to authenticated;
grant execute on function private.is_any_clinic_member() to authenticated;
grant execute on function private.shares_clinic(uuid) to authenticated;
grant execute on function private.is_assigned_doctor(uuid) to authenticated;
grant execute on function private.can_read_prescription(uuid, boolean) to authenticated;
grant execute on function private.can_read_prescription_item(uuid) to authenticated;
grant execute on function private.can_edit_prescription_item(uuid) to authenticated;

revoke all on table
  public.profiles,
  public.clinics,
  public.clinic_members,
  public.patients,
  public.visits,
  public.medicines,
  public.clinical_codes,
  public.prescriptions,
  public.prescription_items
from public, anon, authenticated;

grant select on table
  public.profiles,
  public.clinics,
  public.clinic_members,
  public.medicines,
  public.clinical_codes
to authenticated;

grant select, insert, update on table
  public.patients,
  public.visits
to authenticated;

grant select, insert, update, delete on table
  public.prescriptions,
  public.prescription_items
to authenticated;

alter table public.profiles enable row level security;
alter table public.clinics enable row level security;
alter table public.clinic_members enable row level security;
alter table public.patients enable row level security;
alter table public.visits enable row level security;
alter table public.medicines enable row level security;
alter table public.clinical_codes enable row level security;
alter table public.prescriptions enable row level security;
alter table public.prescription_items enable row level security;

create policy profiles_select_self_or_same_clinic
  on public.profiles
  for select
  to authenticated
  using (
    id = auth.uid()
    or private.shares_clinic(id)
  );

create policy clinics_select_member
  on public.clinics
  for select
  to authenticated
  using (private.is_clinic_member(clinic_id));

create policy clinic_members_select_same_clinic
  on public.clinic_members
  for select
  to authenticated
  using (private.is_clinic_member(clinic_id));

create policy patients_select_same_clinic
  on public.patients
  for select
  to authenticated
  using (private.is_clinic_member(clinic_id));

create policy patients_insert_same_clinic
  on public.patients
  for insert
  to authenticated
  with check (private.is_clinic_member(clinic_id));

create policy patients_update_same_clinic
  on public.patients
  for update
  to authenticated
  using (private.is_clinic_member(clinic_id))
  with check (private.is_clinic_member(clinic_id));

create policy visits_select_same_clinic
  on public.visits
  for select
  to authenticated
  using (private.is_clinic_member(clinic_id));

create policy visits_insert_same_clinic
  on public.visits
  for insert
  to authenticated
  with check (private.is_clinic_member(clinic_id));

create policy visits_update_same_clinic
  on public.visits
  for update
  to authenticated
  using (private.is_clinic_member(clinic_id))
  with check (private.is_clinic_member(clinic_id));

create policy medicines_select_clinic_member
  on public.medicines
  for select
  to authenticated
  using (private.is_any_clinic_member());

create policy clinical_codes_select_visible
  on public.clinical_codes
  for select
  to authenticated
  using (
    private.is_any_clinic_member()
    and (
      clinic_id is null
      or private.is_clinic_member(clinic_id)
    )
  );

create policy prescriptions_select_authorized
  on public.prescriptions
  for select
  to authenticated
  using (private.can_read_prescription(visit_id, is_finalized));

create policy prescriptions_insert_assigned_doctor
  on public.prescriptions
  for insert
  to authenticated
  with check (private.is_assigned_doctor(visit_id));

create policy prescriptions_update_assigned_draft
  on public.prescriptions
  for update
  to authenticated
  using (
    is_finalized = false
    and private.is_assigned_doctor(visit_id)
  )
  with check (private.is_assigned_doctor(visit_id));

create policy prescriptions_delete_assigned_draft
  on public.prescriptions
  for delete
  to authenticated
  using (
    is_finalized = false
    and private.is_assigned_doctor(visit_id)
  );

create policy prescription_items_select_authorized
  on public.prescription_items
  for select
  to authenticated
  using (private.can_read_prescription_item(prescription_id));

create policy prescription_items_insert_assigned_draft
  on public.prescription_items
  for insert
  to authenticated
  with check (private.can_edit_prescription_item(prescription_id));

create policy prescription_items_update_assigned_draft
  on public.prescription_items
  for update
  to authenticated
  using (private.can_edit_prescription_item(prescription_id))
  with check (private.can_edit_prescription_item(prescription_id));

create policy prescription_items_delete_assigned_draft
  on public.prescription_items
  for delete
  to authenticated
  using (private.can_edit_prescription_item(prescription_id));
