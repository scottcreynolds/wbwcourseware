# Operations Runbook

## Backup and restore drill

1. Create an encrypted logical database backup with Supabase-supported `pg_dump` tooling. For local
   data-only restores, explicitly exclude `storage.*`; migrations recreate bucket configuration and
   Storage objects are exported separately in the next step.
2. Export private Storage objects through an authenticated administrative process; database backup alone does not contain submitted PDFs.
3. Record migration commit, backup timestamp, object count, and byte total without student filenames.
4. Restore database into an isolated temporary Supabase project.
   After a data-only Auth restore, synchronize `auth.refresh_tokens_id_seq` to the maximum restored token
   ID before testing login; COPY-based restores do not reliably advance this sequence.
5. Restore Storage objects into private `submissions` bucket.
6. Run `pnpm test:db`, then verify one course, cohort, invitation, submission version, announcement, and discussion.
7. Confirm removed students remain denied and signed file downloads require authorization.
8. Delete temporary restore project after approval.

Do not claim a restore drill succeeded until these steps run against real staging infrastructure. Local validation proves procedure shape, not managed backups.

## Incident response

- Revoke affected sessions and rotate exposed keys immediately.
- Disable compromised Edge Function or Vercel deployment while preserving logs.
- Record time window and affected cohorts; avoid copying student content into incident tickets.
- Restore service from a verified deployment/database point.
- Notify affected users based on legal and contractual requirements.

## Routine checks

- Weekly: failed announcement deliveries, Edge Function errors, Auth anomalies, and storage growth.
- Monthly: dependency updates, RLS regression suite, restore readiness, and inactive invitations.
- Before each cohort: invite flow, email sender, module timezone schedule, and upload/download smoke test.
