-- Public bucket for teacher-uploaded curriculum images/PDFs embedded
-- inline in lesson Markdown (see ADR-007). Deliberately public, unlike
-- `submissions`: assets must render for every enrolled student on every
-- page view via a plain <img>/<a> URL stored in Markdown, which a
-- short-lived signed URL cannot support. All writes still go through
-- the curriculum-asset-upload-intent Edge Function (teacher-only,
-- server-derived random path) -- no client can write directly, so no
-- storage.objects RLS policy is needed, matching the `submissions`
-- bucket's precedent.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values(
  'curriculum-assets', 'curriculum-assets', true, 10485760,
  array['image/png','image/jpeg','image/gif','image/webp','application/pdf']
)
on conflict(id) do update set
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = array['image/png','image/jpeg','image/gif','image/webp','application/pdf'];
