# Writers Be Writing Courseware

Private, cohort-based courseware for workshop-style writing classes.

## Product shape

`Course -> Cohort -> Enrollment`

- Courses own reusable curriculum.
- Cohorts are teaching instances with copied curriculum, dates, students, submissions, announcements, and discussions.
- Course changes reach active cohorts only when teacher selects cohorts and applies the change.
- One global `teacher` account owns all courses and cohorts. Student accounts are invite-only.

## Stack

- Vue 3, Vite, Vuetify, TypeScript
- Vue Router; Pinia only for cross-route client state
- Supabase Postgres, Auth, Storage, RLS, Edge Functions
- Resend for production email; Mailpit locally
- `pnpm`, Vitest, Vue Test Utils, Playwright
- Vercel SPA hosting

## Start here

1. Read `CLAUDE.md`.
2. Read `docs/PRD.md`, `docs/DOMAIN_MODEL.md`, and `docs/ARCHITECTURE.md`.
3. Run only the milestone explicitly authorized by the user.
4. Use `docs/TASK_TEMPLATE.md` for implementation plans.

## Local setup

Prerequisites: Node 22+, `pnpm`, Docker Desktop, and Supabase CLI dependencies.

```bash
pnpm install
cp .env.example .env.local
pnpm supabase:start
```

Copy local API URL and anon key from Supabase output into `.env.local`, then:

```bash
pnpm dev
```

Quality checks:

```bash
pnpm verify
pnpm test:e2e
```

Database and Edge Function checks require running local Supabase:

```bash
pnpm test:db
pnpm test:functions
```

Stop local services with `pnpm supabase:stop`.

## Bootstrap teacher

After local Supabase starts, copy `supabase/.env.example` to `supabase/.env`, set the bootstrap identity and
long random `BOOTSTRAP_TEACHER_SECRET`, and serve functions with that env file. Run `pnpm bootstrap:teacher`
and choose `local` or `production`; all values are read from the env files. Repeating the same email is safe;
a different second teacher is rejected.

Never place bootstrap secret in frontend environment variables or commit it.

## Student invitation email

Local mode returns an invitation URL in teacher dashboard and sends no external email. Production requires
`APP_ORIGIN`, `RESEND_API_KEY`, and verified `EMAIL_FROM` secrets for Edge Functions. Invitation links expire
after 14 days and can be revoked or replaced from cohort dashboard.

## Document map

- Product: `docs/PRD.md`, `docs/USER_FLOWS.md`, `docs/CONTENT_MODEL.md`
- Engineering: `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/SECURITY.md`
- Operations: `docs/AUTH_AND_INVITES.md`, `docs/STORAGE.md`, `docs/EMAIL.md`, `docs/PDF_EXPORT.md`, `docs/OPERATIONS.md`, `docs/OBSERVABILITY.md`, `docs/DEPLOYMENT.md`
- Delivery: `docs/TEST_PLAN.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/BACKLOG.md`
- Decisions: `docs/decisions/`
- Executable milestones: `docs/milestones/`
