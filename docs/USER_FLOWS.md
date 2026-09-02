# User Flows

## Bootstrap teacher

1. Run documented one-time bootstrap command/function with teacher email.
2. Create Auth user through secure admin path.
3. Create profile with immutable teacher role.
4. Force password setup/reset flow.
5. Disable general teacher creation.

## Create course from outline

1. Teacher creates course shell.
2. Opens outline importer.
3. Pastes supported Markdown outline.
4. Reviews parsed modules/items on same page.
5. Reorders/renames/changes types.
6. Confirms atomic creation.
7. Edits bodies/resources later.

## Create cohort

1. Teacher selects course.
2. Enters cohort dates/timezone/name.
3. System copies curriculum snapshot atomically.
4. Teacher assigns due dates and module release rules.
5. Cohort remains draft until teacher activates it.

## Invite student

1. Teacher enters email.
2. Server normalizes email and creates/reuses pending invitation.
3. Resend sends app signup link.
4. Student signs up using same verified email.
5. Trusted activation process creates active enrollment.
6. Student dashboard shows cohort.

## Submit assignment

1. Student opens visible published assignment.
2. Selects one or more PDFs.
3. Client validates type/size for fast feedback.
4. Server/storage rules validate again.
5. Files upload to private staging path.
6. Trusted finalize transaction creates immutable version and file rows.
7. Version becomes visible to active cohort immediately.
8. Late label derives from server receipt time.

## Publish announcement

1. Teacher drafts announcement.
2. Publishing transaction records `published_at` and email job/outbox.
3. Edge Function sends to active students.
4. Delivery results update individually.
5. Failed sends remain retryable; announcement stays published.

## Remove student

1. Teacher confirms removal.
2. Enrollment becomes removed.
3. RLS blocks all cohort access immediately.
4. Submission and discussion records remain.

