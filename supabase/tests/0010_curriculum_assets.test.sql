begin;
select plan(3);

select results_eq(
  $$select public from storage.buckets where id = 'curriculum-assets'$$,
  $$select true$$,
  'curriculum-assets bucket is public'
);
select results_eq(
  $$select file_size_limit from storage.buckets where id = 'curriculum-assets'$$,
  $$select 10485760::bigint$$,
  'curriculum-assets bucket caps files at 10 MB'
);
select results_eq(
  $$select allowed_mime_types from storage.buckets where id = 'curriculum-assets'$$,
  $$select array['image/png','image/jpeg','image/gif','image/webp','application/pdf']$$,
  'curriculum-assets bucket allows only images and PDFs'
);

select * from finish();
rollback;
