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
- Set only these Edge Function secrets: `APP_ORIGIN`, `APP_ENV`, `BOOTSTRAP_TEACHER_SECRET`,
  `RESEND_API_KEY`, and `EMAIL_FROM`.
- Do not configure `SUPABASE_URL`, `SUPABASE_ANON_KEY`, or `SUPABASE_SERVICE_ROLE_KEY` manually;
  Supabase injects those runtime variables into Edge Functions.
- Confirm Supabase Auth site URL and redirect allowlist match the canonical HTTPS origin.
- Confirm public signup remains disabled and bootstrap the first teacher once.

## Environment variable ownership

Frontend variables belong in Vercel (and local `.env.local`); Edge Function variables belong in Supabase
Function secrets (and local `supabase/.env`). The bootstrap command also reads its operator-only values from
the env files; it never exposes them to the browser.

| Variable | Purpose | Set in | Required |
| --- | --- | --- | --- |
| `VITE_APP_NAME` | Browser page and header name. | Vercel; local `.env.local` | No; defaults to `Writers Be Writing`. |
| `VITE_SUPABASE_URL` | Public Supabase API URL used by the browser client. | Vercel; local `.env.local` | Yes |
| `VITE_SUPABASE_ANON_KEY` | Public browser client key; never use the service-role key here. | Vercel; local `.env.local` | Yes |
| `APP_ORIGIN` | Canonical browser origin for CORS and invitation/password links. | Supabase Function secrets; local `supabase/.env` | Yes |
| `APP_ENV` | Selects local Mailpit behavior versus production email delivery. | Supabase Function secrets; local `supabase/.env` | Yes |
| `BOOTSTRAP_TEACHER_SECRET` | Shared secret authorizing first-teacher provisioning. | Supabase Function secrets and ignored operator env file | Bootstrap only; rotate/remove afterward. |
| `BOOTSTRAP_TEACHER_EMAIL` | Email address invited by `pnpm bootstrap:teacher`. | Ignored operator env file only | Bootstrap only |
| `BOOTSTRAP_TEACHER_DISPLAY_NAME` | Optional display name sent by the bootstrap command. | Ignored operator env file only | No |
| `LOCAL_FUNCTION_URL` | Optional local bootstrap endpoint override. | Ignored operator env file | No; defaults to local port 55321. |
| `SUPABASE_FUNCTION_URL` | Production bootstrap endpoint used by the command. | Ignored operator env file only | Production bootstrap |
| `RESEND_API_KEY` | Resend API credential for production invitation email. | Supabase Function secrets; local `supabase/.env` may be empty | Production |
| `EMAIL_FROM` | Verified sender identity for Resend email. | Supabase Function secrets; local `supabase/.env` | Production |
| `SUPABASE_URL` | Supabase URL supplied automatically to Edge Functions. | Supabase runtime | Automatic; do not set manually. |
| `SUPABASE_ANON_KEY` | Supabase anonymous key supplied automatically to Edge Functions. | Supabase runtime | Automatic; do not set manually. |
| `SUPABASE_SERVICE_ROLE_KEY` | Privileged server-only key used by Edge Functions. | Supabase runtime | Automatic; never expose to Vercel/browser. |
| `FUNCTIONS_URL` | Optional base URL for Edge Function tests. | Test shell/CI only | No |
| `E2E_TEACHER_EMAIL` | Disposable teacher fixture email for authenticated E2E tests. | Test shell/CI only | Authenticated E2E only |
| `E2E_TEACHER_PASSWORD` | Disposable teacher fixture password for authenticated E2E tests. | Test shell/CI only | Authenticated E2E only |

## First teacher provisioning

The first `teacher` profile is the admin-equivalent account. There is no separate admin role. Provision it
once through the protected `bootstrap-teacher` Edge Function; do not insert a role directly from the browser
or dashboard.

### Local staging

1. Start the isolated local Supabase stack:

   ```bash
   pnpm supabase:start
   ```

2. Copy `supabase/.env.example` to `supabase/.env` and set `BOOTSTRAP_TEACHER_SECRET`,
   `BOOTSTRAP_TEACHER_EMAIL`, and (optionally) `BOOTSTRAP_TEACHER_DISPLAY_NAME`. Keep this file ignored and
   never put the secret in frontend variables.

3. Serve the functions with that environment:

   ```bash
   pnpm exec supabase functions serve --env-file supabase/.env
   ```

4. Run the provisioning command and choose `local` when prompted. All other values come from
   `supabase/.env`; the secret is not entered on the command line:

   ```bash
   pnpm bootstrap:teacher
   ```

   Alternatively, call the bootstrap function directly:

   ```bash
   curl -X POST http://127.0.0.1:55321/functions/v1/bootstrap-teacher \
     -H "content-type: application/json" \
     -H "x-bootstrap-secret: YOUR_BOOTSTRAP_SECRET" \
     -d '{"email":"you@example.com","displayName":"Your Name","redirectTo":"http://127.0.0.1:5173/update-password"}'
   ```

5. Open the invitation email in local Mailpit, complete password setup, and sign in at the local app.

### Production

1. Deploy the Edge Functions and configure `BOOTSTRAP_TEACHER_SECRET` in the Supabase Function secrets
   store. In an ignored operator env file, set `SUPABASE_FUNCTION_URL`, `APP_ORIGIN`,
   `BOOTSTRAP_TEACHER_EMAIL`, and (optionally) `BOOTSTRAP_TEACHER_DISPLAY_NAME`.
2. Run `pnpm bootstrap:teacher` and choose `production`. The command reads the URL, identity, redirect, and
   secret from the env files. Alternatively,
   call the deployed function over HTTPS; never put the bootstrap secret in source control, Vercel
   browser variables, shell history, or issue tickets:

   ```bash
   curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/bootstrap-teacher \
     -H "content-type: application/json" \
     -H "x-bootstrap-secret: YOUR_BOOTSTRAP_SECRET" \
     -d '{"email":"you@example.com","displayName":"Your Name","redirectTo":"https://YOUR_APP_ORIGIN/update-password"}'
   ```

3. Open the delivered invitation email, complete password setup, and verify teacher login.
4. Repeat calls for the same email only when checking idempotency. A different second teacher is rejected.
5. Rotate or remove the bootstrap secret after the first teacher is provisioned where the operational
   setup permits it.

## Rollback

Frontend rollback uses a prior Vercel deployment. Database migrations are forward-only: restore to a separate project, verify it, then redirect traffic. Never improvise destructive rollback SQL against production.
