# Submission Storage

## Policy

- Supabase private bucket: `submissions`.
- PDF only.
- Maximum 25 MB per file.
- One or more files per immutable submission version.
- Original filename retained as metadata, not storage authority.

## Path convention

`cohorts/{cohort_id}/assignments/{item_id}/students/{student_id}/versions/{version_id}/{random_id}.pdf`

IDs and final paths are server-derived. Bucket listing is not exposed to students.

## Upload protocol

1. Request upload authorization for visible assignment and active enrollment.
2. Create pending version/upload intent.
3. Upload to authorized private path.
4. Finalize through trusted function.
5. Function validates objects and creates version/file rows atomically.
6. Abandoned uploads are cleaned by scheduled maintenance.

## Download protocol

1. User requests specific file.
2. Function verifies teacher ownership or active enrollment in same cohort.
3. Return short-lived signed URL or stream with safe headers.

Do not expose permanent public URLs.

## Cost controls

- Surface per-file limits before upload.
- Prevent duplicate finalize calls.
- Track bytes by cohort.
- Add retention/quotas only after real usage data; never delete student work silently.

