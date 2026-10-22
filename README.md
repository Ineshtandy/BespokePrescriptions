# Bespoke Prescriptions

This repository currently contains the local Supabase development environment. Schema changes belong in version-controlled SQL migrations under `supabase/migrations`.

## Prerequisites

- Docker Desktop, with the Docker daemon running
- Supabase CLI

Install the CLI with Homebrew:

```bash
brew install supabase/tap/supabase
```

This environment was initialized with Supabase CLI 2.120.0. If Homebrew cannot install the formula, download the matching macOS release from the [Supabase CLI releases](https://github.com/supabase/cli/releases) and place the `supabase` binary on your `PATH`.

## Local Supabase

From the repository root:

```bash
supabase start
supabase status
supabase stop
```

`supabase status` prints local service URLs and development keys. Keep those values out of git. Do not commit `.env`, `.env.local`, service-role keys, or other secrets.

## Database development

Version-controlled SQL migrations in `supabase/migrations` are the schema source of truth. That includes tables, columns, indexes, constraints, functions, triggers, types, Row-Level Security, policies, grants, and other persistent database objects.

`supabase db reset` is the local rebuild. It recreates the local database, applies every migration, then loads the seed files listed in `[db.seed].sql_paths` in `supabase/config.toml`.

### Create a migration

Use one migration for one logical database change. From the repository root, let the CLI choose the timestamp:

```bash
supabase migration new <migration_name>
```

Example:

```bash
supabase migration new add_clinics
```

Edit the SQL file the CLI creates under `supabase/migrations`. Review that SQL, then run `supabase db reset` and confirm the database rebuilds from a clean state.

While a migration is still being implemented or reviewed, correct that same file. After it is accepted into project history, leave it unchanged. Later schema changes belong in a new migration created with `supabase migration new`.

### Phase 1 local workflow

From the repository root, with Docker running:

```bash
supabase start
supabase db reset
supabase test db
```

`supabase db reset` applies the Phase 1 migrations and then the development seed. `supabase test db` runs the pgTAP suite in `supabase/tests`. Run the reset before the tests when you want the suite to see a freshly seeded database. The seed-shape tests expect that seeded state.

### Seed data

Migrations define structure and database behavior. Development data lives in `supabase/seeds/` and is applied, in order, by `supabase db reset`:

- `01_clinical_codes.sql` — system clinical vocabulary
- `02_medicines.sql` — development medicine catalogue
- `03_synthetic_clinic.sql` — fictional clinic, staff, patients, visits, and prescriptions

Every person, phone number, and prescription in those files is synthetic. The local sign-in password for the four seeded staff accounts is `demo-local-only`. That value is **LOCAL DEVELOPMENT ONLY**. It is not a production credential.

### Database tests

`supabase/tests` holds the automated integrity and authorization suite. `supabase/manual/finalization_concurrency.sql` is a two-session locking procedure and is not part of `supabase test db`.

### Documentation

Durable phase records live in `documents/`. Phase 1 is `documents/phase-1-database-foundation.md`. After each later roadmap phase is completed and reviewed, add the next document there. Do not add empty placeholders ahead of the work.

### Studio

Supabase Studio is for inspecting tables and data, debugging, and development visibility. `supabase status` prints its URL. Persistent schema changes belong in a migration, then get verified with `supabase db reset`. Studio state is not the schema source of truth.
