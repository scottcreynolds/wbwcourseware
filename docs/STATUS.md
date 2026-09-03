# Project Status

## Current milestone

M9: Hardening and Deployment Readiness — implementation complete

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
- Expiring, revocable, single-use cohort invitations
- Rate-limited teacher invitation Edge Function with Resend delivery
- Local-development invitation links when email is disabled
- Invitation acceptance for new or existing student accounts
- Atomic enrollment activation bound to invited email
- Teacher roster with pending/accepted/revoked invitations
- Student removal that retains records and immediately ends access
- Student dashboard limited to active invited cohorts
- Student RLS for active membership and released/published curriculum
- Student cohort pages with released and scheduled-module navigation
- Locked-module summaries that hide unpublished curriculum details
- Published lecture and assignment pages with ordered resources
- Cohort-local due dates with timezone-aware display
- Branded, print-optimized curriculum views for browser PDF export
- Security-definer student outline query that avoids locked-content leakage
- Private, PDF-only submission storage with 25 MB file limits
- Signed upload intents and short-lived authorized download links
- Immutable submission versions with server-derived late labels
- Immediate peer submission visibility within active cohort membership
- Teacher assignment review panels with submission version history
- Cohort announcement drafts and publish-now workflow
- Idempotent active-student recipient resolution
- Resend delivery with per-recipient sent/failed tracking
- Local email simulation for Docker development
- Published announcement display for active students
- Cohort discussion topics with one-level replies
- Markdown discussion content with shared sanitization
- Author edit and soft-delete controls
- Teacher moderation across cohort content
- Safe display-name projection without exposing student email
- Released-item checks on peer submission metadata and signed downloads
- Teacher missing/on-time/late submission overview support
- Deleted discussion bodies hidden from students and made immutable
- Restricted Edge Function CORS origin and production browser security headers
- Database indexes for ownership, release, due-date, enrollment, and rate-limit paths
- Route focus management and visible keyboard focus
- Deployment, observability, incident, backup, and restore runbooks

## Verification

- `pnpm typecheck`: pass
- `pnpm lint`: pass
- `pnpm test`: pass — 16 tests
- `pnpm build`: pass
- `pnpm test:e2e`: configured; local browser binary download required
- Supabase Docker startup: requires local Docker environment

## Remaining launch gates

- Run database, Edge Function, and browser integration suites with Docker and Playwright browsers.
- Complete staging email/domain verification and real backup/restore drill.
- Perform manual keyboard, zoom/reflow, and screen-reader checks.
- Deploy only with explicit user authorization.
