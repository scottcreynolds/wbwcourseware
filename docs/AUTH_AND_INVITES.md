# Authentication and Invitations

## Auth

- Supabase email/password.
- Email verification required before enrollment activation.
- Login, logout, forgot password, password reset, expired-link handling.
- Global role lives in protected `profiles.role`; client metadata is not authoritative.

## Teacher bootstrap

Provide one idempotent documented command or protected function accepting teacher email. It creates/updates only intended first teacher. Disable path after bootstrap or require explicit server secret.

## Student flow

1. Teacher creates cohort invitation.
2. Function creates secure token and emails link.
3. Student signs up with invited email.
4. After verification/authentication, activation function compares normalized authenticated email with valid invitation.
5. Function marks invitation accepted and creates active enrollment atomically.

Do not rely on Supabase's generic signup allow/deny setting alone. Application invitation table is source of cohort eligibility.

## Edge cases

- Existing student invited to another cohort: accept while authenticated; no new account.
- Signup email differs: no cohort access; show non-enumerating recovery message.
- Duplicate invite: resend/reissue existing pending invite rather than duplicate.
- Expired/revoked invite: teacher can issue replacement.
- Removed student: old invite cannot reactivate enrollment.
- Teacher email submitted to student signup: reject role conflict.

