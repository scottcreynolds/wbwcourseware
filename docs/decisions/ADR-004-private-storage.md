# ADR-004: Private PDF Submission Storage

Status: Accepted

Store submission PDFs in private Supabase Storage. Allow multiple files, maximum 25 MB each. Every resubmission creates an immutable visible version — no version's content, files, or metadata can ever be edited in place. Downloads require authorization and short-lived signed URL.

Rationale: Workshop drafts are private cohort data. Permanent public links are unacceptable.

**Deletion (amendment):** A submission's owning student or the course's teacher may delete the entire submission (its envelope, every version, and every file), via `public.delete_submission` and the `submission-delete` Edge Function. This does not modify version content — it is a full removal, not an edit — and it is a hard delete, not a soft one: the submission and its underlying storage objects both disappear immediately for every viewer, including the teacher, since submissions have no separate audit-of-record table the way announcements do. Deleting clears the `submissions.course_item_id, student_id` uniqueness constraint so the student may submit fresh.

