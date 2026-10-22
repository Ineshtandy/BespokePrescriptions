-- System clinical vocabulary for local development.
-- clinic_id is null: these rows are system codes, not clinic-specific codes.
-- `code` is the canonical value stored on prescription items.
-- `label` is presentation text only.

insert into public.clinical_codes (code_id, clinic_id, code_type, code, label) values
  ('cd110000-0000-4000-8000-000000000001', null, 'frequency', 'OD', 'Once daily'),
  ('cd110000-0000-4000-8000-000000000002', null, 'frequency', 'BD', 'Twice daily'),
  ('cd110000-0000-4000-8000-000000000003', null, 'frequency', 'TDS', 'Three times daily'),
  ('cd110000-0000-4000-8000-000000000004', null, 'frequency', 'QID', 'Four times daily'),
  ('cd110000-0000-4000-8000-000000000005', null, 'frequency', 'PRN', 'When required'),
  ('cd110000-0000-4000-8000-000000000006', null, 'timing', 'BEFORE_FOOD', 'Before food'),
  ('cd110000-0000-4000-8000-000000000007', null, 'timing', 'AFTER_FOOD', 'After food'),
  ('cd110000-0000-4000-8000-000000000008', null, 'timing', 'WITH_FOOD', 'With food'),
  ('cd110000-0000-4000-8000-000000000009', null, 'timing', 'BEDTIME', 'At bedtime'),
  ('cd110000-0000-4000-8000-00000000000a', null, 'duration', '5D', 'Five days'),
  ('cd110000-0000-4000-8000-00000000000b', null, 'duration', '7D', 'Seven days'),
  ('cd110000-0000-4000-8000-00000000000c', null, 'duration', '10D', 'Ten days'),
  ('cd110000-0000-4000-8000-00000000000d', null, 'duration', '2W', 'Two weeks'),
  ('cd110000-0000-4000-8000-00000000000e', null, 'duration', '1M', 'One month'),
  ('cd110000-0000-4000-8000-00000000000f', null, 'duration', 'CONTINUE', 'Continue'),
  ('cd110000-0000-4000-8000-000000000010', null, 'duration', 'UNTIL_REVIEW', 'Until review'),
  ('cd110000-0000-4000-8000-000000000011', null, 'duration', 'CUSTOM', 'Custom duration'),
  ('cd110000-0000-4000-8000-000000000012', null, 'route', 'ORAL', 'Oral'),
  ('cd110000-0000-4000-8000-000000000013', null, 'route', 'TOPICAL', 'Topical'),
  ('cd110000-0000-4000-8000-000000000014', null, 'route', 'INHALATION', 'Inhalation'),
  ('cd110000-0000-4000-8000-000000000015', null, 'route', 'NASAL', 'Nasal'),
  ('cd110000-0000-4000-8000-000000000016', null, 'route', 'OPHTHALMIC', 'Ophthalmic'),
  ('cd110000-0000-4000-8000-000000000017', null, 'route', 'OTIC', 'Otic');
