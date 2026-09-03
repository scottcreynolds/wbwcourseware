begin;
select plan(9);

select has_table('public', 'submissions', 'submissions table exists');
select has_table('public', 'submission_versions', 'submission versions table exists');
select has_table('public', 'submission_files', 'submission files table exists');
select col_is_unique('public', 'submission_files', 'storage_path', 'storage paths are unique');
select col_has_check('public', 'submission_files', 'mime_type', 'file MIME has check');
select col_has_check('public', 'submission_files', 'byte_size', 'file size has check');
select isnt_empty(
  $$select 1 from pg_policies where schemaname='public' and tablename='submissions'$$,
  'submissions have RLS policies'
);
select function_privs_are(
  'public', 'finalize_submission', array['uuid','uuid','jsonb'], 'authenticated', array[]::text[],
  'authenticated cannot finalize directly'
);
select table_privs_are('public', 'submission_files', 'authenticated', array[]::text[], 'raw file table is not exposed');

select * from finish();
rollback;
