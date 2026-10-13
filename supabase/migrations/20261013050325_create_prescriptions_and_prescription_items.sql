create table public.prescriptions (
  prescription_id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits (visit_id) on delete restrict,
  sequence_number integer not null,
  advice_notes text,
  is_finalized boolean not null default false,
  finalized_at timestamptz,
  created_at timestamptz not null default now(),
  constraint prescriptions_sequence_number_positive check (sequence_number > 0),
  constraint prescriptions_finalization_consistent check (
    (is_finalized = false and finalized_at is null)
    or (is_finalized = true and finalized_at is not null)
  ),
  constraint prescriptions_visit_id_sequence_number_key unique (visit_id, sequence_number)
);

create table public.prescription_items (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions (prescription_id) on delete restrict,
  med_id uuid not null references public.medicines (med_id) on delete restrict,
  dose_text text,
  dose_normalized text,
  frequency_code text,
  timing_code text,
  duration_code text,
  duration_note text,
  route_code text,
  notes text,
  order_index integer not null,
  created_at timestamptz not null default now(),
  constraint prescription_items_order_index_non_negative check (order_index >= 0),
  constraint prescription_items_prescription_id_order_index_key
    unique (prescription_id, order_index)
    deferrable initially immediate
);

-- Preset lookup filters items by medicine, then joins the parent prescription.
create index prescription_items_med_id_prescription_id_idx
  on public.prescription_items (med_id, prescription_id);
