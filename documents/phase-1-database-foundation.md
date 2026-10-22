# Phase 1 — Database Foundation

This document records the database that Phase 1 left in place. It is the architectural reference for later developers, coding agents, and reviewers. Schema changes after this phase belong in new migrations. Accepted migrations in `supabase/migrations` stay as written.

## Phase overview

Phase 1 built the local Supabase/PostgreSQL foundation for the prescription digitization MVP. It covers identity, clinic membership, patients, visits, a development medicine catalogue, system clinical codes, prescriptions, prescription items, dose normalization, custom duration rules, controlled finalization, immutability, row-level security, synthetic development data, and an automated database test suite.

Phase 1 ends at the database. It does not include a frontend, staff onboarding, catalogue administration, or preset calculation. A later phase can open a draft, finalize it, and read history against this schema.

The canonical local rebuild is `supabase db reset` from the repository root. The canonical check after that rebuild is `supabase test db`.

## Final technology choices relevant to Phase 1

- **Supabase** is the local platform. The CLI project lives in `supabase/`. Schema changes are SQL migrations.
- **PostgreSQL** stores the clinical records and enforces the integrity rules. The local project uses PostgreSQL 17.
- **Supabase Auth** owns login identities in `auth.users`. Application profiles use the same UUID.
- **PostgreSQL row-level security** limits which rows an authenticated clinic member can read or write. Table grants limit which commands `anon` and `authenticated` may attempt.
- **Migration-first development** means `supabase/migrations` is the schema source of truth. Studio is for inspection. A reset recreates the database from migrations and then loads seed files.
- **Database-enforced clinical integrity** covers visit-doctor role, instruction codes, dose text, custom duration notes, prescription sequence, item order, and the draft-to-finalized lifecycle. Application code is expected to follow these rules, and the database still rejects violations.

## Final relational model

```text
auth.users
    ↓
profiles
    ↓
clinic_members ← clinics
                    ↓
                 patients
                    ↓
                  visits
                    ↓
              prescriptions
                    ↓
           prescription_items
                 ↓
              medicines
```

`clinical_codes` sits beside this chain. Prescription items store canonical code text. They do not store a foreign key to `clinical_codes`.

Relationships:

- `profiles.id` references `auth.users.id` and cascades on delete.
- `clinic_members` joins one profile to one clinic with one role. The primary key is `(clinic_id, profile_id)`.
- `patients` belong to one clinic. `patient_number` is unique inside that clinic.
- `visits` belong to one clinic, one patient in that clinic, one assigned doctor who is a member of that clinic, and one `created_by` member of that clinic.
- `prescriptions` belong to one visit. `sequence_number` is unique and positive inside the visit.
- `prescription_items` belong to one prescription and one medicine. `order_index` is unique inside the prescription and starts at zero. The unique constraint is deferrable so one statement can reorder items.
- `medicines` is a global catalogue. `clinical_codes` is a vocabulary. A null `clinic_id` on a code means the code is a system code.

## Identity model

`profiles.id` is `auth.users.id`. The profile row is the application identity, and the auth row is the login identity. There is one UUID, so authorization can use `auth.uid()` directly as `profiles.id`, `clinic_members.profile_id`, and `visits.doctor_id`.

A profile cannot exist without a matching auth user. Deleting the auth user deletes the profile.

## Clinic-membership model

Role belongs to the membership, not to a global user flag and not to a PostgreSQL role. The allowed values are `doctor`, `assistant`, and `admin`.

One user has one membership in a given clinic. The same user can belong to more than one clinic later, because the primary key is the pair `(clinic_id, profile_id)` and `profile_id` is indexed on its own. The development seed uses one clinic.

Ordinary authenticated users can read memberships in their own clinics. They cannot insert, update, or delete memberships, so they cannot change their own role. A membership role-transition trigger was not added. Role changes after a visit exists are not re-checked by the visit trigger. Ordinary users cannot make that change, because the table grant does not include `UPDATE`.

## Patient model

`patient_id` is the internal UUID. `patient_number` is the clinic-facing identifier, unique per clinic, so `P0001` in one clinic does not collide with `P0001` in another. Name is required. Date of birth, gender, and phone are optional.

A patient belongs to exactly one clinic. Composite uniqueness of `(clinic_id, patient_id)` lets a visit foreign key require the patient and the visit to share a clinic.

Doctor, assistant, and admin members of that clinic may select, insert, and update patients. None of them may delete a patient. An update cannot move the patient into a clinic where the caller is not a member.

## Visit model

A visit is the encounter container. It records the clinic, the patient, the assigned doctor, the member who created the row, a note, and the visit date.

The assigned doctor must be a member of the visit clinic, and that membership role must be `doctor`. An assistant or admin can create the visit and can be `created_by`. They cannot be `doctor_id`. A doctor from another clinic cannot be assigned.

Doctor, assistant, and admin members of the clinic may select, insert, and update visits. None of them may delete a visit. An update cannot move the visit into a clinic the caller does not belong to. The doctor-role rule stays in the visit trigger. Row-level security does not repeat it.

## Prescription model

One visit has many prescriptions. Each has a positive `sequence_number`, unique within the visit. A visit can hold several finalized prescriptions and a later draft. Sequence is an ordering key for that visit. It is not a supersession, replacement, or “current prescription” pointer.

The author of a prescription is the doctor assigned to the visit (`visits.doctor_id`). Prescriptions do not have a `created_by` column.

A prescription is created as a draft: `is_finalized` is false and `finalized_at` is null. Finalization sets both `is_finalized` and `finalized_at`. The check constraint requires those two states to stay paired.

If another prescription is needed after one is finalized, the product creates another prescription on the same visit. Phase 1 does not implement unfinalize, in-place correction, supersession, or an effective/latest prescription.

## Prescription-item model

An item belongs to one prescription and references one medicine by `med_id`. Instruction fields are nullable text:

- `dose_text` and the generated `dose_normalized`
- `frequency_code`, `timing_code`, `duration_code`, `route_code`
- `duration_note` when the duration code is `CUSTOM`
- `notes`
- `order_index`, starting at zero

Items store canonical codes such as `BD`, `AFTER_FOOD`, `5D`, and `ORAL`. Display labels live on `clinical_codes` and are not copied into the item.

A blank instruction code is rejected. A null instruction code is allowed, so a draft item can be incomplete. Empty prescriptions can be finalized. Phase 1 has no completeness rule.

## Clinical-code model

`clinical_codes` holds frequency, timing, duration, and route vocabulary. `code` is the stable machine value. `label` is the presentation text.

System codes have `clinic_id` null. The partial unique index allows one system row per `(code_type, code)`. Clinic-specific rows are allowed by the schema and are unique per `(clinic_id, code_type, code)`. The development seed loads system codes only. Tests create clinic-specific rows inside a transaction and roll them back.

Prescription-item validation accepts a code only when a system row of the matching type exists. A clinic-only code, a code of the wrong type, and an unknown code are rejected. There is no `is_active` flag and no MVP lifecycle for retiring a code.

The seeded system vocabulary is an MVP development set, not a full terminology:

| Type | Codes |
| --- | --- |
| Frequency | `OD`, `BD`, `TDS`, `QID`, `PRN` |
| Timing | `BEFORE_FOOD`, `AFTER_FOOD`, `WITH_FOOD`, `BEDTIME` |
| Duration | `5D`, `7D`, `10D`, `2W`, `1M`, `CONTINUE`, `UNTIL_REVIEW`, `CUSTOM` |
| Route | `ORAL`, `TOPICAL`, `INHALATION`, `NASAL`, `OPHTHALMIC`, `OTIC` |

`5D` is included because the development prescription history uses a five-day duration.

## Medicine model

`medicines` is a global catalogue keyed by `med_id`. The useful columns are `med_name`, `generic_name`, `strength`, and `dosage_form`. There is no catalogue status or lifecycle column.

Ordinary authenticated clinic members may read the catalogue. They cannot insert, update, or delete medicines. Catalogue administration is deferred. A medicine referenced by a prescription item is protected by the foreign key (`ON DELETE RESTRICT`). A dedicated “referenced medicine is immutable” trigger was not added.

The seed loads 20 deterministic development medicines, including tablets, capsules, syrups and a suspension, inhalers, creams, and eye, ear, and nasal drops. `Paracetamol 500 mg Tablet` (`e1100000-0000-4000-8000-000000000001`) is the medicine used for repeated prescribing history. This catalogue is for development and tests. It is not a formulary for real prescribing.

## Dose normalization

`dose_text` is the source text. `dose_normalized` is a grouping key maintained by the `prescription_items_sync_dose` trigger. The trigger calls `normalize_dose_text` and overwrites `dose_normalized` on insert and whenever `dose_text` or `dose_normalized` is updated. A caller cannot persist a different normalized value.

The function is conservative:

- null stays null
- the text is Unicode NFC-normalized
- ordinary and non-breaking Unicode spaces become a normal space
- repeated whitespace collapses to one space
- leading and trailing space is removed
- the result is lowercased

`"1 Tablet"` becomes `"1 tablet"`. `"  5   mL "` becomes `"5 ml"`. `"½ Tablet"` becomes `"½ tablet"`. A blank dose is rejected. Semantic aliases, unit conversion, and splitting the dose into a number and a unit are intentionally unsupported. Changing `dose_text` recalculates the normalized value.

`normalize_dose_text` is executable by `authenticated` and `service_role` because the dose trigger is an invoker trigger and calls the function as the writing user. Direct execution of the trigger function is revoked from application roles. PostgreSQL does not check `EXECUTE` on a trigger function when the trigger fires.

## Duration/CUSTOM rule

`duration_note` is allowed only with `duration_code = 'CUSTOM'`, and then it must contain non-blank text after trimming. Any other duration code, including null, requires `duration_note` to be null.

Two custom notes are different values when their text differs. The database does not fold `"Every alternate day for three weeks"` and `"For ten days, then review"` into one duration.

## Finalization

`public.finalize_prescription(uuid)` is the application path from draft to finalized. It is `SECURITY DEFINER`, owned by the database owner, with an empty `search_path`. `EXECUTE` is granted to `authenticated` and `service_role`.

The function:

1. Locks the prescription with `SELECT … FOR UPDATE`.
2. Requires `auth.uid()` to equal `visits.doctor_id`.
3. Returns the existing row, including the original `finalized_at`, when the prescription is already finalized and the caller is still the assigned doctor.
4. Otherwise inserts a short-lived marker in `private.prescription_finalization`, sets `is_finalized` and `finalized_at = clock_timestamp()`, then deletes the marker.

The lifecycle trigger `enforce_prescription_lifecycle` is an invoker trigger so `current_user` is the role that issued the write. Application roles (`anon`, `authenticated`, `service_role`) cannot insert an already-finalized prescription and cannot change finalization columns. The controlled function’s update runs as the owner, which is not one of those roles, and the marker records that the update came from the function. Once `is_finalized` is true, any role’s update or delete of that prescription raises `55000`.

The item trigger `enforce_finalized_prescription_items` is `SECURITY DEFINER`. It locks the parent prescription, and both parents when an item moves, in UUID order, with `FOR UPDATE`. An insert, update, or delete against a finalized parent raises `55000`. A move between two drafts of the assigned doctor is allowed. The parent lock is what serializes an item write with finalization.

Seed reconstruction does not call `finalize_prescription`. Seed SQL runs as the database owner and has no `auth.uid()`, and the historical timestamps need to stay fixed. The seed inserts prescriptions as drafts, inserts their items, then updates `is_finalized` and `finalized_at` as the owner. The item trigger would reject those items if the parent were already finalized. The lifecycle trigger allows that owner update because the owner is not an application role. No trigger is disabled, and no application function can repeat this path. After the update, the rows match the finalized check constraint and the immutability trigger applies.

## RLS model

Row-level security is enabled on `profiles`, `clinics`, `clinic_members`, `patients`, `visits`, `medicines`, `clinical_codes`, `prescriptions`, and `prescription_items`. Policies are `TO authenticated`. `FORCE ROW LEVEL SECURITY` is off, so the table owner and roles with `BYPASSRLS` are not subject to these policies.

`anon` has no `SELECT`, `INSERT`, `UPDATE`, or `DELETE` on those tables and cannot execute `finalize_prescription`.

`authenticated` grants:

| Table | Commands |
| --- | --- |
| `profiles`, `clinics`, `clinic_members`, `medicines`, `clinical_codes` | `SELECT` |
| `patients`, `visits` | `SELECT`, `INSERT`, `UPDATE` |
| `prescriptions`, `prescription_items` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` |

Row behavior for an authenticated user:

| Data | Doctor | Assistant | Admin |
| --- | --- | --- | --- |
| Own profile, and profiles of people who share a clinic | Read | Read | Read |
| Own clinics and memberships | Read | Read | Read |
| Same-clinic patients | Read, insert, update | Read, insert, update | Read, insert, update |
| Same-clinic visits | Read, insert, update | Read, insert, update | Read, insert, update |
| Medicines | Read | Read | Read |
| System clinical codes, and codes for their clinics | Read | Read | Read |
| Draft prescription and items on a visit assigned to them | Read, insert, update, delete | No access | No access |
| Draft prescription and items on another doctor’s visit | No access | No access | No access |
| Finalized prescription and items in their clinic | Read | Read | Read |
| Finalized prescription and items | No ordinary mutation | No ordinary mutation | No ordinary mutation |
| `finalize_prescription` | Only when `auth.uid()` is the visit’s assigned doctor | Denied | Denied |

A same-clinic doctor who is not the assigned doctor has the same draft restriction as an assistant or admin. Outside-clinic users cannot read the clinic, its patients, visits, drafts, or finalized history. Clinic-specific clinical codes are visible only to members of that clinic. System codes are visible to any clinic member.

Prescription update policy allows the assigned doctor to update a draft, and the `WITH CHECK` requires the resulting visit to still be assigned to `auth.uid()`. The policy does not require the row to remain a draft after the update, so a direct finalization write is still attempted and then rejected by the lifecycle trigger. Item `WITH CHECK` uses the destination prescription, so an item can move between two editable drafts of the same assigned doctor and cannot move onto another doctor’s draft or a finalized prescription.

Deleting patients, visits, memberships, profiles, clinics, medicines, and clinical codes is not granted to ordinary authenticated users.

## Security helper strategy

Helpers live in the `private` schema. They are `SECURITY DEFINER`, `STABLE`, boolean, and have an empty `search_path`. They only read membership, visit assignment, and prescription state. They do not mutate rows and they do not build dynamic SQL. Definer rights let a policy read `clinic_members` and `visits` without the policy’s own `SELECT` recursing through row-level security.

The helpers are `is_clinic_member`, `is_any_clinic_member`, `shares_clinic`, `is_assigned_doctor`, `can_read_prescription`, `can_read_prescription_item`, and `can_edit_prescription_item`. There is no `has_clinic_role` helper. Patient and visit rights are shared by every membership role. Prescribing rights follow visit assignment.

`authenticated` has `USAGE` on `private` and `EXECUTE` on the helpers. `anon` has neither. The finalization marker table remains revoked from application roles.

`finalize_prescription` and the item immutability trigger are `SECURITY DEFINER` with an empty `search_path`. The lifecycle trigger and the dose trigger are invokers. The lifecycle trigger must see `current_user` of the writing role. The dose trigger must call `normalize_dose_text` as that role. Trigger-function `EXECUTE` is revoked from `public`, `anon`, `authenticated`, and `service_role`. Firing a trigger does not consult that privilege.

Identity inside policies and `finalize_prescription` is `auth.uid()`, which reads the request JWT subject.

## Seed-data model

`supabase db reset` loads, in order:

1. `supabase/seeds/01_clinical_codes.sql` — 23 system codes.
2. `supabase/seeds/02_medicines.sql` — 20 catalogue rows.
3. `supabase/seeds/03_synthetic_clinic.sql` — one fictional clinic and its workflow.

The workflow seed creates:

- **Demo Clinic**, `c1100000-0000-4000-8000-000000000001`.
- Four auth users and matching profiles: Doctor A, Doctor B, Assistant A, and Admin A. Emails are `doctor.a@demo.clinic.local`, `doctor.b@demo.clinic.local`, `assistant.a@demo.clinic.local`, and `admin.a@demo.clinic.local`.
- One membership each: doctor, doctor, assistant, admin.
- Five fictional patients, `P0001` through `P0005`, with mixed date of birth and phone values. Phone numbers use the `555-010` range.
- Eight visits. Patient `P0001` has three visits. Doctor A has six visits. Doctor B has two.
- Twelve prescriptions: ten finalized and two drafts. Visit `d1100000-0000-4000-8000-000000000001` has two finalized prescriptions and one draft that contains an item. Visit `d1100000-0000-4000-8000-000000000002` has one finalized prescription and one empty draft.
- Nineteen prescription items.

Doctor A’s finalized history for Paracetamol 500 mg Tablet repeats three instruction combinations: `1 tablet` / `BD` / `AFTER_FOOD` / `5D` / `ORAL` four times, the same combination with `TDS` twice, and the `BD` combination with `7D` once. Doctor B uses the same medicine as `OD` / `BEFORE_FOOD` / `7D` / `ORAL` twice. That split is the source data for a later doctor-specific “Commonly used by you” view. Phase 1 does not calculate presets and does not create a preset table.

Two finalized items use `CUSTOM` with different notes: “Every alternate day for three weeks” and “For ten days, then review”. Dose source text includes `1 Tablet`, `  5   mL `, and `½ Tablet`. The trigger stores `1 tablet`, `5 ml`, and `½ tablet`.

The password for every seeded auth user is `demo-local-only`. That password is **LOCAL DEVELOPMENT ONLY**.

Identifiers are fixed UUIDs so tests and later UI work can refer to the same rows after every reset. `auth.identities.email` is generated from `identity_data` and is not inserted directly.

## Automated testing strategy

Tests are pgTAP files in `supabase/tests`. `supabase test db` runs them. Each file starts a transaction and rolls it back, so one test does not leave rows for the next file. Authorization tests set `request.jwt.claim.sub` and then `SET LOCAL ROLE` to `authenticated` or `anon`, which is what `auth.uid()` and the table policies see. The helper functions that do this are security invokers. PostgreSQL refuses `SET ROLE` inside a security-definer function.

| File | What it covers |
| --- | --- |
| `01_seed_shape.sql` | Demo Clinic, four staff roles, system `CUSTOM`, catalogue size, patient and visit counts, Doctor A history counts, Doctor B’s different combination, both custom notes, dose normalization, and RLS enabled |
| `02_schema_integrity.sql` | Profile/auth link, one membership per clinic, role enum, patient-number uniqueness, same-clinic visit patient and doctor, doctor role on the visit, positive unique sequence, non-negative unique item order |
| `03_clinical_codes.sql` | Accepted system codes, unknown code, wrong type, clinic-only code, blank code, null codes |
| `04_dose_and_duration.sql` | Normalization examples, null dose, blank dose, overwrite of a caller-supplied normalized value, recalculation on update, valid and invalid duration/note pairs, distinct custom notes |
| `05_lifecycle.sql` | Draft edit, direct finalization write, assigned-doctor finalization, stable second finalization timestamp, unauthorized doctor, assistant, admin, and anonymous finalization, finalized update and delete, item insert, update, and delete |
| `06_rls_authorization.sql` | Anonymous denial, two-clinic isolation, patient and visit permissions, draft privacy, finalized visibility, item edit/reorder/move under RLS, reference-data mutation denial, membership self-promotion denial |

`supabase/manual/finalization_concurrency.sql` documents a two-session lock check. It is not executed by `supabase test db`. One pgTAP session cannot show two transactions waiting on the same row. The procedure uses the seeded Doctor A draft and expects `55P03` when `lock_timeout` expires. Both sessions roll back. That script is the concurrency evidence available in this repository. The automated suite does not claim to have proved the wait.

## Explicit MVP non-goals / deferred decisions

These are left for later phases or later product decisions:

- staff onboarding workflow
- role editing workflow
- clinic provisioning
- profile editing
- medicine catalogue administration
- clinical-code administration
- clinic-specific code-management UI
- code lifecycle state
- offline clinical writes
- prescription supersession
- correction workflow
- copy previous prescription
- preset table
- machine-learning ranking
- dose value/unit structuring

The schema already has room for several of those additions. Clinic-specific codes can be inserted later. Another prescription on the same visit is the current way to record a further prescription. Preset ranking can aggregate finalized items by assigned doctor, medicine, normalized dose, and instruction codes.

## Accepted limitations

These are deliberate boundaries of the MVP database, not open defects:

- `postgres` and `supabase_admin` own objects and bypass row-level security. `service_role` also has `BYPASSRLS` and retains full table privileges so server-side maintenance and the local service role keep working. Application users are `anon` and `authenticated`.
- A privileged session can still update `clinic_members.role` or change a system clinical code. Ordinary grants block that. A privileged rename of a code would change how historical item text is interpreted, because items store the code text rather than a code id.
- New tables created in `public` by `postgres` or `supabase_admin` still inherit Supabase’s broad default privileges for `anon`, `authenticated`, and `service_role`. Phase 1 revokes and re-grants the nine application tables explicitly. A future public table needs the same explicit grant review. Default privileges were left unchanged.
- `FORCE ROW LEVEL SECURITY` is off. Policies apply to `authenticated` through the policies’ `TO authenticated` clause and the table grants. They are not a barrier for the table owner.
- The visit-doctor trigger does not re-check role when a membership changes later. Ordinary users cannot update memberships.
- Finalization concurrency across two sessions is documented for manual execution. The pgTAP suite does not start two connections.

## Future improvement hooks

Later work can add, without replacing this model:

- staff onboarding and clinic-provisioning functions that write profiles, clinics, and memberships under a controlled owner path
- medicine import or catalogue administration
- clinic-specific vocabulary and a management UI, with item validation still able to decide which codes are legal
- a derived preset summary if live aggregation of finalized items becomes slow
- richer auditing around finalization and privileged maintenance

The prescription author remains the visit’s assigned doctor. A later correction workflow should add a new prescription rather than edit a finalized one.

## Migration/task history

| Task | Migration | Decision that remains |
| --- | --- | --- |
| 1.1–1.2 | `20261010070049_create_identity_and_clinic_tables.sql` | Profiles share auth UUIDs. Role lives on `clinic_members`. Roles are doctor, assistant, and admin. |
| 1.3 | `20261012082816_create_patients_and_visits.sql` | Clinic-scoped patient numbers. Visits bind patient, doctor, and creator to the same clinic. |
| 1.4 | `20261013044111_create_medicines_and_clinical_codes.sql` | Global medicines. System codes use a null clinic. Labels are separate from codes. |
| 1.5 | `20261013050325_create_prescriptions_and_prescription_items.sql` | Many prescriptions per visit. Positive unique sequence. Zero-based unique order. No `prescriptions.created_by`. |
| 1.6–1.7 | `20261019123300_add_clinical_integrity_constraints.sql` | Assigned visit doctor must have the doctor role. Item codes must match system codes of the right type. |
| 1.8 | `20261019143829_add_dose_normalization_and_duration_rules.sql` | Conservative dose normalization. `CUSTOM` requires a real note. Other durations reject a note. |
| 1.9 | `20261019160703_add_prescription_finalization_and_immutability.sql` | `finalize_prescription` is the only application finalization path. Finalized prescriptions and items are immutable. Parent-row locks serialize item writes with finalization. |
| 1.10 | `20261020145904_add_row_level_security_and_mvp_permissions.sql` | Table grants plus RLS. Drafts belong to the assigned doctor. Finalized rows are readable by the same clinic. Reference data and memberships are read-only for ordinary users. |
| 1.11 | `supabase/seeds/` | Deterministic synthetic reference data and workflow fixtures, loaded by `supabase db reset`. |
| 1.12 | `supabase/tests/`, `supabase/manual/finalization_concurrency.sql` | pgTAP coverage of integrity, lifecycle, and authorization. Two-session locking stays a manual procedure. |

## Documentation convention

After each major roadmap phase is completed and reviewed, add one durable technical document under `documents/`. Suggested names:

```text
documents/
  phase-1-database-foundation.md
  phase-2-prescription-workspace.md
  phase-3-authentication-clinic-access.md
  phase-4-patient-management.md
  phase-5-visit-management.md
  phase-6-workflow-integration.md
  phase-7-usability-reliability.md
  phase-8-trial-readiness.md
```

Later documents should record the implemented architecture, major decisions, important logic, rejected alternatives, security assumptions, known limitations, deferred work, the testing approach, and hooks for future versions. Add a file when that phase is actually complete. Do not add empty placeholders ahead of the work.
