# Claude Code Instructions

## Authority

Read this file and relevant source docs before editing. Implement only the authorized milestone. Do not silently expand scope.

Priority order:

1. User's current instruction
2. `CLAUDE.md`
3. Accepted ADRs
4. Product and architecture docs
5. Milestone file

If sources conflict, stop and report conflict.

## Required workflow

1. Inspect repository and working tree.
2. Read milestone and linked docs.
3. State short plan and files expected to change.
4. Implement smallest complete vertical slice.
5. Run relevant typecheck, lint, unit, integration, and E2E checks.
6. Review security, RLS, accessibility, error states, and loading states.
7. Update docs and ADRs when a decision changes.
8. Report outcome, tests, known gaps, and next milestone. Do not begin next milestone.

## Hard rules

- TypeScript throughout. Avoid `any`; narrow unknown data at boundaries.
- Vue Composition API with `<script setup lang="ts">`.
- No Tailwind. Use Vuetify and plain/scoped CSS.
- Keep domain logic out of Vue components.
- Treat browser as untrusted. Authorization belongs in Postgres RLS and trusted functions.
- Never expose Supabase service-role key or Resend key to client.
- Every exposed table must have RLS enabled and tested.
- Use SQL migrations; never rely on dashboard-only schema changes.
- Privileged workflows run in Supabase Edge Functions.
- Validate input at function boundary and database boundary.
- Store UTC timestamps; store cohort timezone as IANA name.
- Markdown/HTML rendering must use shared sanitization policy. Never render unsanitized HTML.
- Submission files stay private. Access uses authorization checks and short-lived signed URLs.
- No public bucket for student work.
- Preserve cohort-specific due dates, release settings, and publication state when syncing course content.
- Deletion defaults to soft state changes where records affect audit/history.
- Meet WCAG 2.2 AA for core flows.
- Avoid speculative abstraction and premature generic frameworks.

## Testing minimum

- Unit tests for pure domain rules.
- Database integration tests for RLS and trusted SQL functions.
- Edge Function integration tests for invitations, announcements, and signed URLs.
- Playwright only for critical user journeys.
- Every bug fix gets a regression test when practical.

## Definition of done

- Acceptance criteria pass.
- Unauthorized variants are tested, not assumed.
- Empty/loading/error/success states exist.
- Keyboard and screen-reader basics pass.
- No secrets or personal data logged.
- Generated types and docs updated where affected.
- Commands and results reported accurately.

