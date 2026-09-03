# Deployment Checklist

Production deployment requires explicit authorization. Use separate Supabase, Vercel, and Resend environments for staging and production.

## Before staging

- Run `pnpm verify`, `pnpm test:db`, `pnpm test:functions`, and `pnpm test:e2e`.
- Apply migrations to a new staging database; never point staging at production data.
- Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in Vercel.
- Set Edge Function secrets: `APP_ORIGIN`, `APP_ENV`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `BOOTSTRAP_TEACHER_SECRET`, `RESEND_API_KEY`, and `EMAIL_FROM`.
- Verify Resend sending domain, sender, SPF, DKIM, and DMARC.
- Confirm Supabase Auth site URL and redirect allowlist match canonical HTTPS origin.
- Confirm signup remains disabled and bootstrap first teacher once.

## Release gate

- Exercise teacher, student, removed-student, and cross-cohort negative paths in staging.
- Upload and download a PDF; confirm signed URL expires.
- Publish an announcement to test recipients; inspect sent/failed totals.
- Check keyboard navigation, 200% zoom, mobile reflow, and one screen-reader pass.
- Validate CSP and security headers with browser developer tools.
- Complete backup/restore drill from `OPERATIONS.md`.
- Enable Vercel and Supabase logs without recording secrets, tokens, email bodies, or filenames.

## Rollback

Frontend rollback uses a prior Vercel deployment. Database migrations are forward-only: restore to a separate project, verify it, then redirect traffic. Never improvise destructive rollback SQL against production.
