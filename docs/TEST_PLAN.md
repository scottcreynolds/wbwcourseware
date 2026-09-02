# Test Plan

## Philosophy

Focus on integration boundaries and permission failures. Avoid coverage targets and low-value snapshot tests.

## Unit tests: Vitest

- Outline parser and validation
- Module/item ordering helpers
- Release visibility calculations
- Late-state display calculations
- Markdown/HTML sanitizer policy
- File validation
- Date/timezone formatting

## Component tests

- Markdown editor/preview
- Outline import preview
- Module release controls
- Submission version list
- Discussion topic/reply controls
- Empty/error/loading states

## Database integration

- RLS matrix from `DATABASE.md`
- Cohort snapshot transaction
- Course-to-cohort sync preservation rules
- Invitation acceptance races and duplicates
- Submission version numbering/finalization
- Announcement outbox creation
- Reorder atomicity

## Edge Function integration

- Auth and role enforcement
- Invite create/revoke/accept
- Announcement publish/retry
- Signed file URL authorization
- Validation and safe error responses

## Playwright critical journeys

1. Teacher login -> create course from outline -> edit/publish curriculum.
2. Create cohort -> configure releases/due dates -> invite student.
3. Student signup -> dashboard -> read released module.
4. Student submits PDFs -> submits later version -> peer reads both.
5. Teacher views missing/on-time/late dashboard.
6. Teacher publishes announcement.
7. Student creates/edits/deletes discussion content; teacher moderates.
8. Teacher removes student; student immediately loses access.
9. Print view contains branded content/resources.

## Commands expected

Define scripts for `typecheck`, `lint`, `test`, `test:db`, `test:functions`, `test:e2e`, and `verify`.

