# M7: Announcements and Email

## Outcome

Teacher drafts or publishes cohort announcements with tracked email delivery.

## Scope

- Announcement and delivery/outbox schema.
- Draft/publish-now UI.
- Active-recipient resolution.
- Resend integration, retries, delivery summary.
- Published announcement student view.

## Acceptance

- Draft sends nothing and is teacher-only.
- Publish is idempotent and does not duplicate deliveries.
- One send failure does not unpublish announcement.
- Removed/invited-only users do not receive cohort announcement.

