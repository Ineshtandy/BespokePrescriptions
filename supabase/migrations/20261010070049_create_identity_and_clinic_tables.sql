create type public.clinic_role as enum (
  'doctor',
  'assistant',
  'admin'
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  created_at timestamptz not null default now(),
  constraint profiles_full_name_not_blank check (char_length(btrim(full_name)) > 0)
);

create table public.clinics (
  clinic_id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now(),
  constraint clinics_name_not_blank check (char_length(btrim(name)) > 0)
);

create table public.clinic_members (
  clinic_id uuid not null references public.clinics (clinic_id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role public.clinic_role not null,
  created_at timestamptz not null default now(),
  primary key (clinic_id, profile_id)
);

-- Supports "clinics for this profile". The primary key already indexes
-- (clinic_id, profile_id), which covers members of a clinic and role lookup.
create index clinic_members_profile_id_idx
  on public.clinic_members (profile_id);
