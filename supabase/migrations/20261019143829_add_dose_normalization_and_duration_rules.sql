-- Textual grouping key for dose_text. No unit conversion or aliasing.
create function public.normalize_dose_text(dose text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
    when dose is null then null
    else lower(
      btrim(
        regexp_replace(
          regexp_replace(
            normalize(dose, nfc),
            -- Ordinary and non-breaking Unicode spaces become a normal space.
            '['
              || chr(160)
              || chr(5760)
              || chr(8192) || '-' || chr(8202)
              || chr(8232)
              || chr(8233)
              || chr(8239)
              || chr(8287)
              || chr(12288)
              || ']',
            ' ',
            'g'
          ),
          '[[:space:]]+',
          ' ',
          'g'
        )
      )
    )
  end;
$$;

create function public.sync_prescription_item_dose()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.dose_normalized := public.normalize_dose_text(new.dose_text);
  return new;
end;
$$;

create trigger prescription_items_sync_dose
  before insert or update of dose_text, dose_normalized
  on public.prescription_items
  for each row
  execute function public.sync_prescription_item_dose();

alter table public.prescription_items
  add constraint prescription_items_dose_text_not_blank
    check (
      dose_text is null
      or char_length(public.normalize_dose_text(dose_text)) > 0
    ),
  add constraint prescription_items_duration_note_matches_code
    check (
      case
        when duration_code = 'CUSTOM' then
          duration_note is not null
          and char_length(btrim(duration_note)) > 0
        else
          duration_note is null
      end
    );

-- The dose trigger calls normalize_dose_text() as the writing user.
-- That user needs EXECUTE here. The trigger function itself does not.
revoke all on function public.normalize_dose_text(text) from public, anon;
revoke all on function public.sync_prescription_item_dose() from public, anon, authenticated, service_role;

grant execute on function public.normalize_dose_text(text) to authenticated, service_role;
