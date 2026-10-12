create table public.patients (
  patient_id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (clinic_id) on delete restrict,
  patient_number text not null,
  name text not null,
  dob date,
  gender text,
  phone text,
  created_at timestamptz not null default now(),
  constraint patients_patient_number_not_blank check (char_length(btrim(patient_number)) > 0),
  constraint patients_name_not_blank check (char_length(btrim(name)) > 0),
  constraint patients_clinic_id_patient_number_key unique (clinic_id, patient_number),
  -- Supports visits (clinic_id, patient_id) → patients (clinic_id, patient_id).
  -- patient_id is already unique; this key exists so a visit cannot pair a clinic
  -- with a patient from another clinic.
  constraint patients_clinic_id_patient_id_key unique (clinic_id, patient_id)
);

create table public.visits (
  visit_id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null,
  patient_id uuid not null,
  doctor_id uuid not null,
  created_by uuid not null,
  patient_note text,
  visit_date date not null,
  created_at timestamptz not null default now(),
  constraint visits_clinic_patient_fkey
    foreign key (clinic_id, patient_id)
    references public.patients (clinic_id, patient_id)
    on delete restrict,
  constraint visits_clinic_doctor_fkey
    foreign key (clinic_id, doctor_id)
    references public.clinic_members (clinic_id, profile_id)
    on delete restrict,
  constraint visits_clinic_created_by_fkey
    foreign key (clinic_id, created_by)
    references public.clinic_members (clinic_id, profile_id)
    on delete restrict
);

-- Visits for a patient in a clinic.
create index visits_clinic_id_patient_id_idx
  on public.visits (clinic_id, patient_id);

-- Visits assigned to a doctor in a clinic.
create index visits_clinic_id_doctor_id_idx
  on public.visits (clinic_id, doctor_id);

-- Visits in a clinic by date.
create index visits_clinic_id_visit_date_idx
  on public.visits (clinic_id, visit_date);
