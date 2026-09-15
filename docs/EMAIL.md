# Email

## Provider

- Production: Resend
- Local: Mailpit

## Messages

- Student invitation
- Invitation resend/replacement
- Announcement publication
- Teacher notification of a new student discussion topic
- Teacher notification of an assignment submission
- Password/reset emails remain Supabase Auth responsibility unless deliberately customized

## Announcement delivery

Use transactional outbox semantics:

1. Publish announcement and create recipient delivery rows atomically.
2. Edge Function sends individual or privacy-safe batched messages.
3. Store provider ID/status per recipient.
4. Retry transient failures with capped attempts and backoff.
5. Publishing succeeds even when delivery partly fails.

Teacher sees sent/pending/failed counts, not noisy provider internals.

## Teacher notifications

The teacher receives an email whenever a student posts a new top-level
discussion topic, or submits an assignment. Only the single global teacher
account is notified (`courses.teacher_id`); replies and the teacher's own
posts never trigger a notification.

Mechanism (see `supabase/migrations/20260914000200_teacher_notifications.sql`):

1. A trusted write queues a `pending` row in `teacher_notifications`: a
   database trigger on `discussion_topics` insert for discussion topics, and
   the `finalize_submission` RPC directly for submissions (it already runs
   as `service_role` and has every id in scope).
2. An `AFTER INSERT` trigger on `teacher_notifications` uses the `pg_net`
   extension to fire an async HTTP call to the `notify-teacher` Edge
   Function, authenticated with the service-role key.
3. `notify-teacher` loads the notification's content, sends via Resend (or
   marks `sent` immediately in local development when `RESEND_API_KEY` is
   unset), and records `status`/`provider_message_id`/`last_error_code` back
   onto the row — the same delivery-status shape as `announcement_deliveries`.
4. A `pending` row that never dispatches (missing Vault secrets, or a
   `net.http_post` failure) stays visible to the teacher via
   `teacher_notifications`' own `select` RLS policy; there is no automatic
   retry loop yet (see `docs/BACKLOG.md`).

### One-time Vault secret setup

`pg_net` calls carry no secrets of their own, so the dispatch trigger reads
the Edge Function URL and the service-role key from Supabase Vault rather
than from migration SQL. This must be set once per environment (local and
production are separate Vault stores) via the SQL editor or `psql`:

```sql
select vault.create_secret('http://kong:8000/functions/v1/notify-teacher', 'notify_teacher_function_url');
select vault.create_secret('<service-role-key-from-supabase-status>', 'notify_teacher_service_key');
```

Locally, `pg_net` calls out from inside the database container, which sits on
the project's own Docker network alongside Kong (the API gateway) — the
host-exposed `127.0.0.1:55321` is not reachable from inside that network, so
the URL must be the internal `kong:8000` address shown above, not the
`APP_ORIGIN`/`FUNCTIONS_URL` value used everywhere else. For production,
substitute the deployed function URL
(`https://<project-ref>.supabase.co/functions/v1/notify-teacher`) and the
production service-role key. Until both secrets exist, notification rows are
queued but never dispatched — check `teacher_notifications` for stuck
`pending` rows if this step was skipped.

### Local development requires `functions serve` running

`supabase start` alone does not serve Edge Functions locally; Kong has
nothing behind `/functions/v1/*` until `supabase functions serve` is running
separately (this also applies to `pnpm test:functions`). Run it with
`--env-file supabase/.env` so `APP_ENV`/`RESEND_API_KEY`/`EMAIL_FROM` are
actually available to the function — without `--env-file`, `functions serve`
only reads `supabase/functions/.env`, which does not exist in this repo, and
every local notification will fail with `email_not_configured` instead of
following the local `sent`-without-Resend path.

## Safety

- Never place cohort recipients in visible `To`/`CC` list together.
- Links use configured canonical app origin.
- Sanitize rendered announcement content.
- Include course/cohort identity and unsubscribe/legal handling as applicable before production launch.
- Local environment must not send to real students.

