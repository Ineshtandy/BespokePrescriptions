-- Visit doctor role is checked on insert and when clinic_id or doctor_id changes.
-- Clinic alignment stays on visits_clinic_doctor_fkey.
-- Changing clinic_members.role after the visit exists is not re-checked here.
-- Ordinary role edits are not an MVP workflow; Task 1.10 restricts them.

create function public.enforce_visit_doctor_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  assigned_role text;
begin
  if tg_op = 'UPDATE'
     and new.clinic_id is not distinct from old.clinic_id
     and new.doctor_id is not distinct from old.doctor_id then
    return new;
  end if;

  select cm.role::text
    into assigned_role
  from public.clinic_members as cm
  where cm.clinic_id = new.clinic_id
    and cm.profile_id = new.doctor_id;

  if assigned_role is null then
    return new;
  end if;

  if assigned_role <> 'doctor' then
    raise exception 'visits.doctor_id must be a member of the visit clinic with role doctor'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger visits_enforce_doctor_role
  before insert or update of clinic_id, doctor_id
  on public.visits
  for each row
  execute function public.enforce_visit_doctor_role();

-- Instruction codes are canonical text, matched to system clinical codes.
-- A privileged rename or delete of a system code is not blocked here.
-- Task 1.10 restricts ordinary clinical-code updates and deletes.

create function public.enforce_prescription_item_codes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and new.frequency_code is not distinct from old.frequency_code
     and new.timing_code is not distinct from old.timing_code
     and new.duration_code is not distinct from old.duration_code
     and new.route_code is not distinct from old.route_code then
    return new;
  end if;

  if new.frequency_code is not null
     and char_length(btrim(new.frequency_code)) > 0
     and not exists (
       select 1
       from public.clinical_codes as codes
       where codes.clinic_id is null
         and codes.code_type = 'frequency'::public.clinical_code_type
         and codes.code = new.frequency_code
     ) then
    raise exception 'frequency_code must match a system clinical code of type frequency'
      using errcode = '23514';
  end if;

  if new.timing_code is not null
     and char_length(btrim(new.timing_code)) > 0
     and not exists (
       select 1
       from public.clinical_codes as codes
       where codes.clinic_id is null
         and codes.code_type = 'timing'::public.clinical_code_type
         and codes.code = new.timing_code
     ) then
    raise exception 'timing_code must match a system clinical code of type timing'
      using errcode = '23514';
  end if;

  if new.duration_code is not null
     and char_length(btrim(new.duration_code)) > 0
     and not exists (
       select 1
       from public.clinical_codes as codes
       where codes.clinic_id is null
         and codes.code_type = 'duration'::public.clinical_code_type
         and codes.code = new.duration_code
     ) then
    raise exception 'duration_code must match a system clinical code of type duration'
      using errcode = '23514';
  end if;

  if new.route_code is not null
     and char_length(btrim(new.route_code)) > 0
     and not exists (
       select 1
       from public.clinical_codes as codes
       where codes.clinic_id is null
         and codes.code_type = 'route'::public.clinical_code_type
         and codes.code = new.route_code
     ) then
    raise exception 'route_code must match a system clinical code of type route'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger prescription_items_enforce_instruction_codes
  before insert or update of frequency_code, timing_code, duration_code, route_code
  on public.prescription_items
  for each row
  execute function public.enforce_prescription_item_codes();

alter table public.prescription_items
  add constraint prescription_items_frequency_code_not_blank
    check (frequency_code is null or char_length(btrim(frequency_code)) > 0),
  add constraint prescription_items_timing_code_not_blank
    check (timing_code is null or char_length(btrim(timing_code)) > 0),
  add constraint prescription_items_duration_code_not_blank
    check (duration_code is null or char_length(btrim(duration_code)) > 0),
  add constraint prescription_items_route_code_not_blank
    check (route_code is null or char_length(btrim(route_code)) > 0);

revoke all on function public.enforce_visit_doctor_role() from public, anon;
revoke all on function public.enforce_prescription_item_codes() from public, anon;

grant execute on function public.enforce_visit_doctor_role() to authenticated, service_role;
grant execute on function public.enforce_prescription_item_codes() to authenticated, service_role;
