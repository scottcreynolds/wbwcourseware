begin;
select plan(5);

select has_table('public', 'course_module_notes', 'module notes table exists');
select has_column('public', 'course_module_notes', 'notes_markdown', 'notes carry markdown content');
select policies_are(
  'public', 'course_module_notes', array['teacher manages own module notes'],
  'no student-facing policy exists -- a student role can never match any row'
);

-- This system enforces exactly one global teacher account (see
-- profiles_single_teacher_unique in 0001_profiles.test.sql), so the
-- meaningful negative case here is student access, not a second teacher.
-- The bootstrapped teacher owns the course/module; the student is actively
-- enrolled. Notes must be readable by the teacher and by nobody else.
insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values
  ('66666666-6666-6666-6666-666666666661','notes-test-teacher@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated'),
  ('66666666-6666-6666-6666-666666666663','notes-test-student@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='teacher', display_name='Notes Test Teacher' where id='66666666-6666-6666-6666-666666666661';
update public.profiles set role='student', display_name='Notes Test Student', email_normalized='notes-test-student@example.com' where id='66666666-6666-6666-6666-666666666663';
insert into public.courses(id, teacher_id, title, status, start_date, end_date, timezone)
values ('66666666-6666-6666-6666-666666666664','66666666-6666-6666-6666-666666666661','Notes Test Course','active','2026-01-01','2026-06-01','UTC');
insert into public.course_modules(id, course_id, title, position, release_mode, manually_released_at)
values ('66666666-6666-6666-6666-666666666665','66666666-6666-6666-6666-666666666664','Module One',0,'manual',now());
insert into public.course_enrollments(id, course_id, student_id, status)
values ('66666666-6666-6666-6666-666666666666','66666666-6666-6666-6666-666666666664','66666666-6666-6666-6666-666666666663','active');
insert into public.course_module_notes(module_id, notes_markdown)
values ('66666666-6666-6666-6666-666666666665','Talking points for scene structure.');

set local role authenticated;
set local request.jwt.claims = '{"sub":"66666666-6666-6666-6666-666666666661","role":"authenticated"}';
select is(
  (select notes_markdown from public.course_module_notes where module_id = '66666666-6666-6666-6666-666666666665'),
  'Talking points for scene structure.',
  'the owning teacher can read their own module notes'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"66666666-6666-6666-6666-666666666663","role":"authenticated"}';
select is(
  (select count(*)::int from public.course_module_notes where module_id = '66666666-6666-6666-6666-666666666665'),
  0,
  'an actively enrolled student cannot read instructor-only teaching notes'
);
reset role;

select * from finish();
rollback;
