# Project Status

## Current milestone

M1: Authentication and Roles — complete

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

## Verification

- `pnpm typecheck`: pass
- `pnpm lint`: pass
- `pnpm test`: pass — 6 tests
- `pnpm build`: pass
- `pnpm test:e2e`: configured; local browser binary download required
- Supabase Docker startup: requires local Docker environment

## Next authorized milestone

M2: Course Authoring
