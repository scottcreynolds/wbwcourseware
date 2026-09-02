# Database and RLS Plan

## Tables

### Identity

- `profiles(id -> auth.users, email_normalized, display_name, role, created_at)`

### Course templates

- `courses(id, teacher_id, title, description, status, branding_json, timestamps)`
- `course_modules(id, course_id, title, description, position, timestamps)`
- `course_items(id, course_id, kind, title, slug, body_markdown, publication_status, timestamps)`
- `course_module_items(module_id, item_id, position)`
- `course_item_resources(id, item_id, title, url, description, position)`

### Cohorts and snapshots

- `cohorts(id, course_id, teacher_id, title, start_date, end_date, timezone, status, timestamps)`
- `cohort_modules(id, cohort_id, source_module_id, title, description, position, release_mode, release_at, manually_released_at, timestamps)`
- `cohort_items(id, cohort_id, source_item_id, kind, title, slug, body_markdown, publication_status, due_at, timestamps)`
- `cohort_module_items(module_id, item_id, position)`
- `cohort_item_resources(id, item_id, source_resource_id, title, url, description, position)`

### Membership

- `cohort_invitations(id, cohort_id, email_normalized, token_hash, status, expires_at, invited_by, accepted_at, timestamps)`
- `cohort_enrollments(id, cohort_id, student_id, invitation_id, status, activated_at, removed_at, timestamps)`

### Work

- `submissions(id, cohort_item_id, student_id, timestamps)`
- `submission_versions(id, submission_id, version_number, submitted_at, is_late)`
- `submission_files(id, version_id, storage_path, original_name, mime_type, byte_size, checksum, timestamps)`

### Communication

- `announcements(id, cohort_id, author_id, title, body_markdown, status, published_at, timestamps)`
- `announcement_deliveries(id, announcement_id, enrollment_id, email_normalized, status, provider_message_id, attempt_count, last_error_code, timestamps)`
- `discussion_topics(id, cohort_id, author_id, title, body_markdown, deleted_at, timestamps)`
- `discussion_replies(id, topic_id, author_id, body_markdown, deleted_at, timestamps)`

## Constraints

- Global role enum: teacher/student.
- Unique active/pending invitation per cohort/email.
- Unique enrollment per cohort/student.
- Course/cohort ownership foreign keys must agree through transaction checks.
- Item kind immutable after submissions exist.
- Unique submission per cohort assignment/student.
- Unique version number per submission.
- File MIME exactly `application/pdf`, size `1..26214400`.
- Position nonnegative; reorder transaction normalizes positions.

## RLS policy matrix

| Resource | Teacher | Active student | Removed/invited |
| --- | --- | --- | --- |
| Course templates | Own CRUD | None | None |
| Cohort admin rows | Own CRUD | Visible projection only | None |
| Visible modules/items | Own CRUD | Read released/published | None |
| Enrollment roster | Own CRUD | Minimal peer display only | None |
| Submission metadata/files | Own read | Own write; cohort read | None |
| Announcements | Own CRUD | Read published | None |
| Discussions | Moderate | Cohort CRUD under rules | None |

Use dedicated safe views/RPCs for peer names and submission listings. Never expose invitation tokens, raw emails, provider errors, or private profile data to students.

## Required database tests

- Cross-teacher isolation
- Cross-cohort student isolation
- Removed student denial
- Draft/unreleased content denial
- Student cannot mutate due dates, roles, ownership, publication, or other submissions
- Signed URL authorization checks same rules as metadata
- Direct object ID guessing fails

