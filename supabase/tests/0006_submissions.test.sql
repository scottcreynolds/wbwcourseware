begin;
select plan(17);

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

select has_function('public', 'delete_submission', array['uuid'], 'delete_submission RPC exists');
select function_privs_are(
  'public', 'delete_submission', array['uuid'], 'authenticated', array[]::text[],
  'authenticated cannot delete a submission directly -- authorization lives in the Edge Function, matching finalize_submission'
);

-- Deleting via the service-role RPC must cascade files -> versions -> the
-- submission envelope, and hand back the storage paths that were removed
-- so the Edge Function can clean up the underlying objects (no
-- storage.objects RLS policy exists for this bucket).
insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values ('22222222-2222-2222-2222-222222222221','submission-delete-teacher@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='teacher', display_name='Submission Delete Teacher' where id='22222222-2222-2222-2222-222222222221';
insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values ('22222222-2222-2222-2222-222222222222','submission-delete-student@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='student', display_name='Submission Delete Student', email_normalized='submission-delete-student@example.com' where id='22222222-2222-2222-2222-222222222222';
insert into public.courses(id, teacher_id, title, start_date, end_date, timezone)
values ('22222222-2222-2222-2222-222222222223','22222222-2222-2222-2222-222222222221','Submission Delete Course','2026-01-01','2026-02-01','UTC');
insert into public.course_items(id, course_id, kind, title, slug)
values ('22222222-2222-2222-2222-222222222224','22222222-2222-2222-2222-222222222223','assignment','Assignment','assignment');
insert into public.submissions(id, course_item_id, student_id)
values ('22222222-2222-2222-2222-222222222225','22222222-2222-2222-2222-222222222224','22222222-2222-2222-2222-222222222222');
insert into public.submission_versions(id, submission_id, version_number, is_late)
values ('22222222-2222-2222-2222-222222222226','22222222-2222-2222-2222-222222222225',1,false);
insert into public.submission_files(id, version_id, storage_path, original_name, mime_type, byte_size)
values ('22222222-2222-2222-2222-222222222227','22222222-2222-2222-2222-222222222226',
  '22222222-2222-2222-2222-222222222222/22222222-2222-2222-2222-222222222224/file.pdf','file.pdf','application/pdf',1000);

-- A pending teacher notification for this version must not survive the
-- submission being deleted -- otherwise it would dispatch later and 404
-- inside notify-teacher when it tries to look up the now-gone version.
insert into public.teacher_notifications(kind, course_id, teacher_id, source_id)
values ('submission','22222222-2222-2222-2222-222222222223','22222222-2222-2222-2222-222222222221','22222222-2222-2222-2222-222222222226');

select is(
  (select storage_path from public.delete_submission('22222222-2222-2222-2222-222222222225')),
  '22222222-2222-2222-2222-222222222222/22222222-2222-2222-2222-222222222224/file.pdf',
  'delete_submission returns the storage paths of every deleted file'
);
select is(
  (select count(*)::int from public.submissions where id = '22222222-2222-2222-2222-222222222225'),
  0,
  'delete_submission removes the submission envelope'
);
select is(
  (select count(*)::int from public.submission_versions where submission_id = '22222222-2222-2222-2222-222222222225'),
  0,
  'delete_submission removes every version'
);
select is(
  (select count(*)::int from public.submission_files where version_id = '22222222-2222-2222-2222-222222222226'),
  0,
  'delete_submission removes every file'
);
select is(
  (select count(*)::int from public.teacher_notifications where source_id = '22222222-2222-2222-2222-222222222226'),
  0,
  'delete_submission removes the pending teacher notification for the deleted version'
);
select throws_ok(
  $$select public.delete_submission('22222222-2222-2222-2222-222222222225')$$,
  'P0001',
  'submission not found',
  'deleting an already-deleted submission raises rather than silently no-opping'
);

select * from finish();
rollback;
