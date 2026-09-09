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

## Curriculum Assets

Teacher-uploaded images and PDFs embedded inline in lesson Markdown
(see ADR-007). Deliberately public, unlike `submissions` above.

### Policy

- Supabase **public** bucket: `curriculum-assets`.
- PNG, JPEG, GIF, WebP, or PDF only.
- Maximum 10 MB per file.
- Random server-generated filename; original filename is not
  retained anywhere (unlike submissions, there is no metadata row —
  the object's presence in the bucket is the entire record).

### Path convention

`{random_uuid}.{extension}` — flat, no course/item/teacher scoping.
Uploads are not associated with a specific course or item in the
database; the resulting public URL is only referenced from wherever
the teacher pastes it into a lesson's Markdown.

### Upload protocol

1. Teacher requests an upload intent from
   `curriculum-asset-upload-intent`, which checks `profiles.role =
   'teacher'` and validates MIME type/size.
2. Function returns a signed upload token and the object's public URL.
3. Client uploads directly to the signed URL.
4. No finalize step — there is nothing else to record.
5. No cleanup job exists yet (same as submissions); an object that's
   never referenced from any lesson is simply unused storage.

### Read protocol

None — the bucket is public. Any URL works directly in `<img src>` or
`<a href>` with no authorization check, matching how the sanitizer
already permits both tags in lesson content.

