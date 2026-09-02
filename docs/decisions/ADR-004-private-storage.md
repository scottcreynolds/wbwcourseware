# ADR-004: Private PDF Submission Storage

Status: Accepted

Store submission PDFs in private Supabase Storage. Allow multiple files, maximum 25 MB each. Every resubmission creates immutable visible version. Downloads require authorization and short-lived signed URL.

Rationale: Workshop drafts are private cohort data. Permanent public links are unacceptable.

