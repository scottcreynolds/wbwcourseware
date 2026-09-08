begin;
select plan(11);
select has_table('public', 'announcements', 'announcements table exists');
select has_table('public', 'announcement_deliveries', 'deliveries table exists');
select col_has_check('public', 'announcements', 'title', 'announcement title constrained');
select col_is_unique('public', 'announcement_deliveries', array['announcement_id','enrollment_id'], 'one delivery per enrollment');
select isnt_empty($$select 1 from pg_policies where tablename='announcements' and policyname='student reads published announcements'$$, 'published student policy exists');
select function_privs_are('public', 'prepare_announcement_publication', array['uuid','uuid'], 'authenticated', array[]::text[], 'publication RPC is private');
select has_index('public', 'announcement_deliveries', 'announcement_deliveries_status_idx', 'delivery status indexed');
select has_trigger('public', 'announcements', 'protect_announcement_publication_state', 'publication state is guarded by trigger');
select isnt_empty($$select 1 from pg_policies where tablename='announcements' and policyname='teacher manages announcements' and cmd='ALL' and qual='owns_course(course_id)'$$, 'teacher can manage announcements at any status');

-- A published announcement on a still-draft course must stay invisible to
-- an enrolled student -- every other student-facing read path requires
-- courses.status <> 'draft', and announcements had been the one exception.
insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values
  ('66666666-6666-6666-6666-666666666661','announcement-test-teacher@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated'),
  ('66666666-6666-6666-6666-666666666662','announcement-test-student@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='teacher', display_name='Announcement Test Teacher' where id='66666666-6666-6666-6666-666666666661';
update public.profiles set role='student', display_name='Announcement Test Student', email_normalized='announcement-test-student@example.com' where id='66666666-6666-6666-6666-666666666662';
insert into public.courses(id, teacher_id, title, status, start_date, end_date, timezone)
values ('66666666-6666-6666-6666-666666666663','66666666-6666-6666-6666-666666666661','Announcement Test Course','draft','2026-01-01','2026-06-01','UTC');
insert into public.course_enrollments(id, course_id, student_id, status)
values ('66666666-6666-6666-6666-666666666664','66666666-6666-6666-6666-666666666663','66666666-6666-6666-6666-666666666662','active');
insert into public.announcements(id, course_id, author_id, title, body_markdown, status, published_at)
values ('66666666-6666-6666-6666-666666666665','66666666-6666-6666-6666-666666666663','66666666-6666-6666-6666-666666666661','Announcement','Body','published',now());

set local role authenticated;
set local request.jwt.claims = '{"sub":"66666666-6666-6666-6666-666666666662","role":"authenticated"}';
select is(
  (select count(*)::int from public.announcements where id = '66666666-6666-6666-6666-666666666665'),
  0,
  'a published announcement on a draft course is invisible to an enrolled student'
);
reset role;

update public.courses set status = 'active' where id = '66666666-6666-6666-6666-666666666663';

set local role authenticated;
set local request.jwt.claims = '{"sub":"66666666-6666-6666-6666-666666666662","role":"authenticated"}';
select is(
  (select count(*)::int from public.announcements where id = '66666666-6666-6666-6666-666666666665'),
  1,
  'activating the course makes its published announcement visible immediately'
);
reset role;

select * from finish();
rollback;
