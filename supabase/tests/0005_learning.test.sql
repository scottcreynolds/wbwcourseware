begin;
select plan(6);
select has_function('public','get_student_course_outline',array['uuid'],'safe student outline exists');
select policies_are('public','courses',array['student reads own enrolled course','teacher manages own courses'],'course metadata access is explicit');
select function_privs_are('public','get_student_course_outline',array['uuid'],'authenticated',array['EXECUTE'],'students may request authorized outline');
select has_function('public','get_student_course_item',array['uuid','uuid'],'safe single-item fetch exists');

-- There is no template/instance split any more, so publishing an item is
-- immediately visible to enrolled students with no separate sync step.
insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values
  ('55555555-5555-5555-5555-555555555551','learning-test-teacher@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated'),
  ('55555555-5555-5555-5555-555555555552','learning-test-student@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='teacher', display_name='Learning Test Teacher' where id='55555555-5555-5555-5555-555555555551';
update public.profiles set role='student', display_name='Learning Test Student', email_normalized='learning-test-student@example.com' where id='55555555-5555-5555-5555-555555555552';
insert into public.courses(id, teacher_id, title, status, start_date, end_date, timezone)
values ('55555555-5555-5555-5555-555555555553','55555555-5555-5555-5555-555555555551','Learning Test Course','active','2026-01-01','2026-06-01','UTC');
insert into public.course_modules(id, course_id, title, position, release_mode, manually_released_at)
values ('55555555-5555-5555-5555-555555555554','55555555-5555-5555-5555-555555555553','Module One',0,'manual',now());
insert into public.course_items(id, course_id, kind, title, slug, body_markdown, publication_status)
values ('55555555-5555-5555-5555-555555555555','55555555-5555-5555-5555-555555555553','lecture','Lecture One','lecture-one','Real content','draft');
insert into public.course_module_items(module_id, item_id, position)
values ('55555555-5555-5555-5555-555555555554','55555555-5555-5555-5555-555555555555',0);
insert into public.course_enrollments(id, course_id, student_id, status)
values ('55555555-5555-5555-5555-555555555556','55555555-5555-5555-5555-555555555553','55555555-5555-5555-5555-555555555552','active');

set local role authenticated;
set local request.jwt.claims = '{"sub":"55555555-5555-5555-5555-555555555552","role":"authenticated"}';
select is(
  (select jsonb_array_length(m.value -> 'items') from jsonb_array_elements(
    public.get_student_course_outline('55555555-5555-5555-5555-555555555553') -> 'modules'
  ) m),
  0,
  'a draft item is absent from the outline'
);
reset role;

update public.course_items set publication_status = 'published' where id = '55555555-5555-5555-5555-555555555555';

set local role authenticated;
set local request.jwt.claims = '{"sub":"55555555-5555-5555-5555-555555555552","role":"authenticated"}';
select is(
  (select jsonb_array_length(m.value -> 'items') from jsonb_array_elements(
    public.get_student_course_outline('55555555-5555-5555-5555-555555555553') -> 'modules'
  ) m),
  1,
  'publishing on the course makes the item visible immediately -- no sync step exists any more'
);
reset role;

select * from finish();rollback;
