# Deployment Readiness

Last reviewed: 2026-09-15

## Completed locally

- `pnpm verify`: typecheck, lint, 25 unit tests, and production build pass.
- `pnpm test:db`: 106 database/RLS assertions pass against an isolated local Supabase stack.
- `pnpm test:functions`: 13 live Edge Function boundary assertions pass against local Supabase.
- `pnpm test:e2e`: 9 public Chromium checks pass, plus an authenticated local-staging teacher journey
  (1 related check intentionally skipped).
- Authenticated local-staging journey passes for teacher login, course creation, outline import, cohort
  snapshot/release, invitation acceptance, student login and curriculum visibility, PDF submission,
  teacher submission visibility, announcement delivery, discussion creation, student removal, and
  immediate loss of cohort access.
- Axe reports no WCAG A/AA violations on the home, sign-in, forgot-password, and invitation pages.
- Keyboard skip navigation and 400%-equivalent public-page reflow pass.
- Production security-header policy is defined in `vercel.json`.
- Local database backup/restore rehearsal (last performed 2026-09-04, against 70 assertions at the time)
  passes with Auth and application data restored, record counts verified, and the full database/RLS suite
  rerun. Storage metadata is intentionally excluded from the database dump and handled by the separate
  private-object export path. Rerun against the current 106-assertion suite before relying on this gate
  for launch.

## Local staging policy

For the initial deployment, the isolated local Supabase stack and local application preview are the
staging environment. Managed-provider checks remain production cutover checks where no local equivalent
exists.

## Open launch gates

- Finish cross-cohort and peer-submission browser paths from `TEST_PLAN.md` against local staging.
- Add browser checks for discussion edit/delete/moderation and signed-download expiry.
- Verify a private PDF upload/download and signed URL expiry in staging.
- Publish an invitation and announcement through the verified Resend domain and inspect delivery totals.
- Validate the deployed CSP and other response headers; Vite preview does not apply `vercel.json`.
- Complete keyboard, zoom/reflow, and screen-reader passes on authenticated teacher and student flows.
- Complete a local database and private Storage backup/restore rehearsal. A managed backup/restore drill
  remains a production cutover check.

Do not treat local database reset/dump testing as completion of the managed backup/restore gate.
