# Email

## Provider

- Production: Resend
- Local: Mailpit

## Messages

- Student invitation
- Invitation resend/replacement
- Announcement publication
- Password/reset emails remain Supabase Auth responsibility unless deliberately customized

## Announcement delivery

Use transactional outbox semantics:

1. Publish announcement and create recipient delivery rows atomically.
2. Edge Function sends individual or privacy-safe batched messages.
3. Store provider ID/status per recipient.
4. Retry transient failures with capped attempts and backoff.
5. Publishing succeeds even when delivery partly fails.

Teacher sees sent/pending/failed counts, not noisy provider internals.

## Safety

- Never place cohort recipients in visible `To`/`CC` list together.
- Links use configured canonical app origin.
- Sanitize rendered announcement content.
- Include course/cohort identity and unsubscribe/legal handling as applicable before production launch.
- Local environment must not send to real students.

