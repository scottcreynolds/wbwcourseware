# Architecture

## System

```text
Vue SPA on Vercel
  -> Supabase Auth
  -> PostgREST under RLS
  -> Private Supabase Storage
  -> Supabase Edge Functions
       -> trusted SQL/RPC
       -> Resend
```

## Frontend boundaries

- `src/app`: app boot, router, Vuetify, global providers
- `src/features`: feature-owned pages/components/composables/services
- `src/domain`: pure types, rules, parsers, selectors
- `src/lib`: Supabase client, Markdown renderer, validation, dates
- `src/shared`: reusable presentation components

Do not create a global API wrapper that hides authorization semantics. Keep queries near feature services and return typed domain results.

## Backend boundaries

- `supabase/migrations`: schema, constraints, RLS, SQL functions
- `supabase/functions`: privileged Edge Functions
- `supabase/tests`: pgTAP/database integration tests
- `supabase/seed.sql`: deterministic local fixtures only

## Data access

- Ordinary authorized CRUD may use client Supabase SDK under RLS.
- Multi-row invariants use trusted SQL functions with explicit authorization.
- Service-role operations exist only inside Edge Functions.
- Functions using elevated privileges set safe `search_path`, validate caller, and expose minimum grants.

## Server responsibilities

- Teacher bootstrap
- Invite creation/revocation and email
- Invite-to-enrollment activation
- Atomic cohort snapshot
- Course change application to selected cohorts
- Submission finalize and signed file access
- Announcement publishing/email outbox

## PDF export

Use print route/layout and browser print-to-PDF for MVP. See `PDF_EXPORT.md`.

## Environments

- Local: Supabase CLI/Docker, local app, Mailpit
- Staging: separate Supabase/Vercel/Resend test configuration
- Production: separate projects and secrets

Never share database, auth users, buckets, or secrets across environments.

