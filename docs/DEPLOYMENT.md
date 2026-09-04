# Deployment Checklist

Production deployment requires explicit authorization. The current staging environment is the isolated
local Supabase/Vite stack; managed Supabase, Vercel, and Resend checks remain production cutover gates.

## Staging verification

- [x] Run `pnpm verify`, `pnpm test:db`, and `pnpm test:functions`.
- [x] Run public axe/keyboard/reflow checks with `pnpm test:e2e`.
- [x] Run the authenticated local-staging teacher/student journey with disposable credentials.
- [x] Exercise local PDF submission, announcement simulation, discussion creation, and student removal.
- [x] Complete local database/Auth restore rehearsal; keep Storage export separate from the DB dump.
- [ ] Exercise cross-cohort denial, peer submission visibility/download, and signed URL expiry.
- [ ] Add authenticated discussion edit/delete/moderation browser checks.
- [ ] Perform authenticated screen-reader and 200%/400% zoom passes.

## Release gate

- [x] Exercise teacher, student, and removed-student paths in local staging.
- [ ] Exercise cross-cohort negative paths.
- [x] Upload a PDF and verify teacher-side submission visibility.
- [ ] Download a PDF and confirm signed URL expiry.
- [x] Publish an announcement using local delivery simulation.
- [ ] Verify production Resend domain, sender, SPF, DKIM, and DMARC.
- [x] Check public keyboard navigation, mobile reflow, and automated WCAG A/AA rules.
- [ ] Complete authenticated keyboard, zoom, and screen-reader passes.
- [ ] Validate CSP and security headers through the deployed Vercel response.
- [x] Complete local database/Auth backup/restore rehearsal.
- [ ] Complete managed backup/restore drill before production use.
- [ ] Enable Vercel and Supabase logs without recording secrets, tokens, email bodies, or filenames.

## Production configuration

- Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in Vercel.
- Set Edge Function secrets: `APP_ORIGIN`, `APP_ENV`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `SUPABASE_SERVICE_ROLE_KEY`, `BOOTSTRAP_TEACHER_SECRET`, `RESEND_API_KEY`, and `EMAIL_FROM`.
- Confirm Supabase Auth site URL and redirect allowlist match the canonical HTTPS origin.
- Confirm public signup remains disabled and bootstrap the first teacher once.

## Rollback

Frontend rollback uses a prior Vercel deployment. Database migrations are forward-only: restore to a separate project, verify it, then redirect traffic. Never improvise destructive rollback SQL against production.
