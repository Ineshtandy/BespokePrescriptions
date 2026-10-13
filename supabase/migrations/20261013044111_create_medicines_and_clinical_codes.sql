create type public.clinical_code_type as enum (
  'frequency',
  'timing',
  'duration',
  'route'
);

create table public.medicines (
  med_id uuid primary key default gen_random_uuid(),
  med_name text not null,
  generic_name text,
  strength text,
  dosage_form text,
  created_at timestamptz not null default now(),
  constraint medicines_med_name_not_blank check (char_length(btrim(med_name)) > 0),
  constraint medicines_generic_name_not_blank check (
    generic_name is null or char_length(btrim(generic_name)) > 0
  ),
  constraint medicines_strength_not_blank check (
    strength is null or char_length(btrim(strength)) > 0
  ),
  constraint medicines_dosage_form_not_blank check (
    dosage_form is null or char_length(btrim(dosage_form)) > 0
  )
);

create table public.clinical_codes (
  code_id uuid primary key default gen_random_uuid(),
  clinic_id uuid references public.clinics (clinic_id) on delete restrict,
  code_type public.clinical_code_type not null,
  code text not null,
  label text not null,
  created_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint clinical_codes_code_not_blank check (char_length(btrim(code)) > 0),
  constraint clinical_codes_label_not_blank check (char_length(btrim(label)) > 0)
);

-- System codes: one (code_type, code) where the row is not clinic-specific.
create unique index clinical_codes_system_code_key
  on public.clinical_codes (code_type, code)
  where clinic_id is null;

-- Clinic codes: one (clinic_id, code_type, code) per clinic.
create unique index clinical_codes_clinic_code_key
  on public.clinical_codes (clinic_id, code_type, code)
  where clinic_id is not null;
