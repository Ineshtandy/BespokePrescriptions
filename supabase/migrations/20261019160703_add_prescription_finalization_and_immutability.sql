-- Marker visible only to the finalization function and its guard trigger.
-- Ordinary roles cannot insert it, so they cannot forge a controlled transition.
create schema private;

revoke all on schema private from public;
revoke all on schema private from anon, authenticated, service_role;

create table private.prescription_finalization (
  prescription_id uuid primary key
);

revoke all on table private.prescription_finalization from public;
revoke all on table private.prescription_finalization from anon, authenticated, service_role;

-- Returns the prescription row.
-- A second call by the same assigned doctor returns that row unchanged,
-- including the original finalized_at.
-- Any other caller is rejected, including when the prescription is already finalized.
create function public.finalize_prescription(p_prescription_id uuid)
returns public.prescriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  result public.prescriptions;
  assigned_doctor uuid;
begin
  if p_prescription_id is null then
    raise exception 'prescription id is required'
      using errcode = '22023';
  end if;

  select prescriptions.*
    into result
  from public.prescriptions as prescriptions
  where prescriptions.prescription_id = p_prescription_id
  for update;

  if not found then
    raise exception 'prescription not found'
      using errcode = 'P0002';
  end if;

  select visits.doctor_id
    into assigned_doctor
  from public.visits as visits
  where visits.visit_id = result.visit_id;

  if auth.uid() is null then
    raise exception 'authentication required to finalize a prescription'
      using errcode = '42501';
  end if;

  if auth.uid() is distinct from assigned_doctor then
    raise exception 'only the doctor assigned to the visit can finalize this prescription'
      using errcode = '42501';
  end if;

  if result.is_finalized then
    return result;
  end if;

  insert into private.prescription_finalization (prescription_id)
  values (p_prescription_id);

  update public.prescriptions
  set is_finalized = true,
      finalized_at = clock_timestamp()
  where prescription_id = p_prescription_id
  returning * into result;

  delete from private.prescription_finalization
  where prescription_id = p_prescription_id;

  return result;
end;
$$;

-- Invoker rights are required so current_user is the application role on a
-- direct write, and the owner of finalize_prescription() during its update.
create function public.enforce_prescription_lifecycle()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  controlled boolean;
  app_role boolean;
begin
  app_role := current_user in ('anon', 'authenticated', 'service_role');

  if tg_op = 'DELETE' then
    if old.is_finalized then
      raise exception 'finalized prescriptions cannot be deleted'
        using errcode = '55000';
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    if app_role and (new.is_finalized or new.finalized_at is not null) then
      raise exception 'prescriptions must be created as drafts'
        using errcode = '42501';
    end if;
    return new;
  end if;

  if old.is_finalized then
    raise exception 'finalized prescriptions cannot be changed'
      using errcode = '55000';
  end if;

  if new.is_finalized is not distinct from old.is_finalized
     and new.finalized_at is not distinct from old.finalized_at then
    return new;
  end if;

  if app_role then
    raise exception 'finalization state can only be changed by finalize_prescription()'
      using errcode = '42501';
  end if;

  select exists (
    select 1
    from private.prescription_finalization as pending
    where pending.prescription_id = old.prescription_id
  )
    into controlled;

  if controlled
     and not (
       new.is_finalized
       and new.finalized_at is not null
       and new.prescription_id is not distinct from old.prescription_id
       and new.visit_id is not distinct from old.visit_id
       and new.sequence_number is not distinct from old.sequence_number
       and new.advice_notes is not distinct from old.advice_notes
       and new.created_at is not distinct from old.created_at
     ) then
    raise exception 'finalization cannot change other prescription fields'
      using errcode = '55000';
  end if;

  return new;
end;
$$;

create trigger prescriptions_enforce_lifecycle
  before insert or update or delete
  on public.prescriptions
  for each row
  execute function public.enforce_prescription_lifecycle();

-- Locks the parent prescription so item writes serialize with finalization.
-- Two parents are locked in UUID order.
create function public.enforce_finalized_prescription_items()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  first_id uuid;
  second_id uuid;
  first_finalized boolean;
  second_finalized boolean;
begin
  if tg_op = 'INSERT' then
    first_id := new.prescription_id;
  elsif tg_op = 'DELETE' then
    first_id := old.prescription_id;
  elsif old.prescription_id = new.prescription_id then
    first_id := new.prescription_id;
  elsif old.prescription_id < new.prescription_id then
    first_id := old.prescription_id;
    second_id := new.prescription_id;
  else
    first_id := new.prescription_id;
    second_id := old.prescription_id;
  end if;

  select prescriptions.is_finalized
    into first_finalized
  from public.prescriptions as prescriptions
  where prescriptions.prescription_id = first_id
  for update;

  if second_id is not null then
    select prescriptions.is_finalized
      into second_finalized
    from public.prescriptions as prescriptions
    where prescriptions.prescription_id = second_id
    for update;
  end if;

  if first_finalized or second_finalized then
    raise exception 'finalized prescription items cannot be changed'
      using errcode = '55000';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create trigger prescription_items_enforce_finalized_parent
  before insert or update or delete
  on public.prescription_items
  for each row
  execute function public.enforce_finalized_prescription_items();

-- Trigger execution does not consult EXECUTE on these functions.
-- Only finalize_prescription() is an application call.
revoke all on function public.finalize_prescription(uuid) from public, anon;
revoke all on function public.enforce_prescription_lifecycle() from public, anon, authenticated, service_role;
revoke all on function public.enforce_finalized_prescription_items() from public, anon, authenticated, service_role;

grant execute on function public.finalize_prescription(uuid) to authenticated, service_role;
