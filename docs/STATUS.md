# Project Status

## Current milestone

M3: Cohorts and Curriculum Snapshots — complete

## Completed

- Vue 3/Vite/Vuetify/TypeScript application shell
- Teacher and student placeholder routes
- Plain CSS theme and baseline accessible structure
- Environment validation and Supabase client boundary
- Local Supabase configuration and empty deterministic seed
- Vitest, ESLint, TypeScript, build, Playwright configuration
- CI verification workflow
- Product, architecture, security, database, testing, ADR, and milestone documents
- Protected `profiles` schema with immutable global teacher/student roles
- Self-read-only profile RLS and one-teacher database constraint
- Idempotent secret-protected teacher bootstrap Edge Function
- Auth session store and role-protected teacher/student routes
- Login, logout, email confirmation state, forgot-password, and update-password screens
- Safe client-facing auth errors and auth-domain unit tests
- Public Auth signup disabled pending invitation-gated student signup in M4
- Teacher course dashboard and course creation
- Course details and draft/active/archive states
- Ordered modules with rename, safe deletion, and accessible move controls
- Canonical lecture/assignment items with multiple module placements
- Draft/published item editing and Markdown file import
- Broad sanitized HTML with approved YouTube/Vimeo iframe handling
- Ordered resource links
- Editable Markdown outline preview with atomic module/item scaffolding
- Course curriculum schema, ownership RLS, and trusted atomic RPCs
- Atomic cohort creation with copied modules, items, placements, and resources
- Cohort dates, timezone, and lifecycle status
- Manual and scheduled module release controls
- Cohort-specific assignment due dates
- Teacher-selected course-item sync preserving cohort scheduling and publication state
- Cohort ownership RLS and snapshot/sync database operations

## Verification

- `pnpm typecheck`: pass
- `pnpm lint`: pass
- `pnpm test`: pass — 12 tests
- `pnpm build`: pass
- `pnpm test:e2e`: configured; local browser binary download required
- Supabase Docker startup: requires local Docker environment

## Next authorized milestone

M4: Invitations and Enrollment
