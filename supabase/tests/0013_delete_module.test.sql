begin;
select plan(7);

insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values
  ('77777777-7777-7777-7777-777777777701','delmod-teacher@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated'),
  ('77777777-7777-7777-7777-777777777702','delmod-student@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='teacher', display_name='Delete Module Teacher' where id='77777777-7777-7777-7777-777777777701';
update public.profiles set role='student', display_name='Delete Module Student', email_normalized='delmod-student@example.com' where id='77777777-7777-7777-7777-777777777702';
insert into public.courses(id, teacher_id, title, status, start_date, end_date, timezone)
values ('77777777-7777-7777-7777-777777777710','77777777-7777-7777-7777-777777777701','Delete Module Course','active','2026-01-01','2026-06-01','UTC');
insert into public.course_modules(id, course_id, title, position, release_mode, manually_released_at) values
  ('77777777-7777-7777-7777-777777777720','77777777-7777-7777-7777-777777777710','Doomed',0,'manual',now()),
  ('77777777-7777-7777-7777-777777777721','77777777-7777-7777-7777-777777777710','Kept',1,'manual',now()),
  ('77777777-7777-7777-7777-777777777722','77777777-7777-7777-7777-777777777710','Has submissions',2,'manual',now());
insert into public.course_items(id, course_id, kind, title, slug) values
  ('77777777-7777-7777-7777-777777777730','77777777-7777-7777-7777-777777777710','lecture','Only in doomed','only-in-doomed'),
  ('77777777-7777-7777-7777-777777777731','77777777-7777-7777-7777-777777777710','lecture','Shared','shared'),
  ('77777777-7777-7777-7777-777777777732','77777777-7777-7777-7777-777777777710','assignment','Submitted work','submitted-work');
insert into public.course_module_items(module_id, item_id, position) values
  ('77777777-7777-7777-7777-777777777720','77777777-7777-7777-7777-777777777730',0),
  ('77777777-7777-7777-7777-777777777720','77777777-7777-7777-7777-777777777731',1),
  ('77777777-7777-7777-7777-777777777721','77777777-7777-7777-7777-777777777731',0),
  ('77777777-7777-7777-7777-777777777722','77777777-7777-7777-7777-777777777732',0);
insert into public.course_enrollments(id, course_id, student_id, status)
values ('77777777-7777-7777-7777-777777777740','77777777-7777-7777-7777-777777777710','77777777-7777-7777-7777-777777777702','active');
insert into public.submissions(id, course_item_id, student_id)
values ('77777777-7777-7777-7777-777777777750','77777777-7777-7777-7777-777777777732','77777777-7777-7777-7777-777777777702');

set local role authenticated;
set local request.jwt.claims = '{"sub":"77777777-7777-7777-7777-777777777702","role":"authenticated"}';
select throws_ok(
  $$select public.delete_course_module('77777777-7777-7777-7777-777777777720')$$,
  'not authorized',
  'a student cannot delete a module'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"77777777-7777-7777-7777-777777777701","role":"authenticated"}';
select lives_ok(
  $$select public.delete_course_module('77777777-7777-7777-7777-777777777720')$$,
  'the owning teacher can delete a module that still has module-only items'
);
select throws_like(
  $$select public.delete_course_module('77777777-7777-7777-7777-777777777722')$$,
  '%student submissions%',
  'a module whose only-placed assignment has submissions cannot be deleted'
);
reset role;

select is((select count(*)::int from public.course_modules where id = '77777777-7777-7777-7777-777777777720'), 0, 'the module is gone');
select is((select count(*)::int from public.course_items where id = '77777777-7777-7777-7777-777777777730'), 0, 'its module-only item is deleted with it');
select is(
  (select array_agg(module_id) from public.course_module_items where item_id = '77777777-7777-7777-7777-777777777731'),
  array['77777777-7777-7777-7777-777777777721'::uuid],
  'an item also placed in another module survives with only that placement'
);
select is(
  (select count(*)::int from public.course_modules where id = '77777777-7777-7777-7777-777777777722'),
  1,
  'the blocked module and its assignment are untouched'
);

select * from finish();
rollback;
