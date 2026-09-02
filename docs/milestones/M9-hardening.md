# M9: Hardening and Deployment Readiness

## Outcome

MVP ready for controlled production launch.

## Scope

- Full RLS/security review and adversarial tests.
- Accessibility audit/fixes.
- Performance and database index review.
- Error monitoring/log redaction strategy.
- Backup/restore drill and operational runbook.
- Staging email/domain verification.
- Vercel SPA configuration and production checklist.

## Acceptance

- `pnpm verify` and critical E2E suite pass.
- No known high-severity authorization/XSS/file exposure issues.
- Restore procedure demonstrated.
- Production secrets/config documented without secret values.
- Deployment occurs only with explicit authorization.

