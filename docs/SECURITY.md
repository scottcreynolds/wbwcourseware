# Security

## Threat model

Protect student identities, invitations, unpublished curriculum, workshop drafts, and uploaded scripts against other cohorts, removed users, anonymous users, and compromised client code.

## Authorization

- RLS is primary control for data access.
- Route guards are UX only.
- Teacher ownership and active enrollment checked at database/function boundary.
- Global role assigned by trusted bootstrap/profile creation path only.
- Never accept owner ID, role, student ID, late flag, or storage path authority from client without server derivation.

## Invitations

- Normalize email consistently.
- Store random token hash, not plaintext token.
- Single-use, expiring, revocable tokens.
- Rate-limit invite creation/resend and signup attempts.
- Avoid revealing whether arbitrary email is invited.
- Enrollment activation requires authenticated verified email match.

## HTML safety

Teacher content is still untrusted input.

- Sanitize rendered output using central allowlist.
- Allow broad presentational HTML and approved video iframes.
- Block scripts, event attributes, forms, `javascript:`/unsafe data URLs, active objects, meta refresh, and unknown iframes.
- Apply Content Security Policy compatible with allowlist.
- Test stored-XSS payloads.

## Files

- Private buckets only, with one deliberate exception: `curriculum-assets`
  (see ADR-007) is public-read because teacher-authored lesson images/PDFs
  must render for every enrolled student on every page view from a URL
  stored in Markdown — a short-lived signed URL cannot support that.
  Writes to it are still teacher-only and authorized server-side; only
  reads are unauthenticated.
- Random server-controlled paths; never trust original filename as path.
- Validate PDF MIME, extension, magic bytes where feasible, and size.
- Signed URLs short-lived and issued only after authorization (applies
  to uploads on every bucket, and to downloads on private buckets).
- Consider malware scanning as production hardening/fast follow.
- Set safe content disposition and headers.

## Email

- Escape or sanitize content in HTML templates.
- Do not log full recipient lists or message bodies.
- Verify Resend webhook signatures if webhooks added.
- Rate-limit announcement send and invitation resend.

## Secrets

- Local secrets in ignored env files.
- Production secrets in deployment secret stores.
- Client receives only public Supabase URL and anon key.
- Rotate secrets after accidental exposure; deleting from latest commit is insufficient.

## Audit-relevant events

Record teacher invitation actions, enrollment removal, course-to-cohort sync, announcement publication, discussion moderation, and submission finalization without logging document contents.

