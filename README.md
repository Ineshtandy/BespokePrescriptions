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

`supabase db reset` is the local rebuild. It recreates the local database, applies migrations, then runs `supabase/seed.sql` (`[db.seed].sql_paths` in `supabase/config.toml`).

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

### Seed data

Migrations define structure and database behavior. `supabase/seed.sql` inserts development and reference data. It is applied only after migrations during `supabase db reset`, and it is safe to run on every reset.

Seed files stay free of real patient data, real clinical records, production credentials, real private staff information, and production secrets.

Two kinds of seed data will be added in later tasks:

- **Reference data** the application relies on in development, such as clinical frequency, timing, duration, and route codes, and development medicine catalogue entries.
- **Synthetic workflow data** for exercising workflows and tests: a fictional clinic, doctor, assistant, patients, visits, and prescriptions. Those records must be obviously fictional.

Neither category is populated yet.

### Studio

Supabase Studio is for inspecting tables and data, debugging, and development visibility. `supabase status` prints its URL. Persistent schema changes belong in a migration, then get verified with `supabase db reset`. Studio state is not the schema source of truth.
