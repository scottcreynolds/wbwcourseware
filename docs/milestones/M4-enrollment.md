# M4: Invitations and Enrollment

## Outcome

Teacher invites students; invited signup gains only intended cohort.

## Scope

- Invitation/enrollment schema and RLS.
- Invite/revoke/resend Edge Functions.
- Resend abstraction with Mailpit local behavior.
- Signup/acceptance activation flow.
- Teacher roster and student cohort dashboard.
- Student removal retaining records.

## Acceptance

- Verified invited email activates automatically.
- Duplicate/raced acceptance stays idempotent.
- Removed student loses access immediately.
- Cross-cohort and token-guessing tests fail safely.

