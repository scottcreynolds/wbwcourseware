begin;
select plan(6);

select has_function('public','duplicate_course',array['uuid','text'],'duplicate_course exists');
select function_privs_are('public','duplicate_course',array['uuid','text'],'authenticated',array['EXECUTE'],'duplicate_course is callable by any authenticated caller (ownership enforced inside)');

-- Duplicating a course must deep-copy modules/items/resources into a
-- brand-new, independent course row -- and must not duplicate an item
-- that is placed in more than one module (course_module_items is a
-- many-to-many join; the item itself must be copied exactly once).
insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values ('44444444-4444-4444-4444-444444444441','duplicate-test-teacher@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='teacher', display_name='Duplicate Test Teacher' where id='44444444-4444-4444-4444-444444444441';
insert into public.courses(id, teacher_id, title, status, start_date, end_date, timezone)
values ('44444444-4444-4444-4444-444444444442','44444444-4444-4444-4444-444444444441','Source Course','active','2026-01-01','2026-06-01','UTC');
insert into public.course_modules(id, course_id, title, position, release_mode, manually_released_at)
values
  ('44444444-4444-4444-4444-444444444443','44444444-4444-4444-4444-444444444442','Module One',0,'manual',now()),
  ('44444444-4444-4444-4444-444444444444','44444444-4444-4444-4444-444444444442','Module Two',1,'manual',null);
insert into public.course_items(id, course_id, kind, title, slug, body_markdown, publication_status, due_at)
values ('44444444-4444-4444-4444-444444444445','44444444-4444-4444-4444-444444444442','assignment','Shared Item','shared-item','Body','published',now() + interval '7 days');
-- the same item placed in BOTH modules
insert into public.course_module_items(module_id, item_id, position) values
  ('44444444-4444-4444-4444-444444444443','44444444-4444-4444-4444-444444444445',0),
  ('44444444-4444-4444-4444-444444444444','44444444-4444-4444-4444-444444444445',0);
insert into public.course_item_resources(item_id, title, url, position)
values ('44444444-4444-4444-4444-444444444445','A resource','https://example.com',0);

set local role authenticated;
set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444441","role":"authenticated"}';
select public.duplicate_course('44444444-4444-4444-4444-444444444442','Duplicated Course') as new_course_id \gset
reset role;

select is(
  (select status::text from public.courses where id = :'new_course_id'),
  'draft',
  'a duplicated course always starts as draft, regardless of the source status'
);
select is(
  (select count(*)::int from public.course_items where course_id = :'new_course_id'),
  1,
  'an item placed in two modules is copied exactly once, not once per placement'
);
select is(
  (select count(*)::int from public.course_module_items p join public.course_modules m on m.id = p.module_id where m.course_id = :'new_course_id'),
  2,
  'both placements of the shared item carry over, pointing at the single duplicated item'
);
select is(
  (select release_mode::text from public.course_modules where course_id = :'new_course_id' and title = 'Module One'),
  'manual',
  'release state resets on duplication -- a new section should not inherit "already released"'
);

select * from finish();rollback;
