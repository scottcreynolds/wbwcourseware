# ADR-007: Public Curriculum Asset Storage

Status: Accepted

Store teacher-uploaded lesson images and PDFs in a new public Supabase Storage bucket (`curriculum-assets`), separate from the private `submissions` bucket. Uploads require teacher authorization via a trusted Edge Function issuing a signed upload URL and a random server-generated path; reads are unauthenticated.

Rationale: ADR-004 established private buckets for submission files because workshop drafts are private cohort data. Curriculum assets are the opposite case — teacher-authored content meant to render inline for every enrolled student on every page view, referenced by a plain URL embedded in stored Markdown. A short-lived signed URL cannot support that: it would expire while still referenced from saved lesson content. Making this one bucket public, with write access still gated to teachers, is a narrower and more honest fit than forcing a private-bucket pattern designed for a different threat model.
