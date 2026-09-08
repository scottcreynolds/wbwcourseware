begin;
select plan(16);
select has_type('public','cohort_status','cohort status exists');
select has_type('public','module_release_mode','release mode exists');
select has_table('public','cohorts','cohorts exist');
select has_column('public','cohorts','intro_markdown','cohorts have an intro markdown column');
select has_table('public','cohort_modules','cohort modules exist');
select has_table('public','cohort_items','cohort items exist');
select has_table('public','cohort_module_items','cohort placements exist');
select has_table('public','cohort_item_resources','cohort resources exist');
select has_function('public','create_cohort_from_course',array['uuid','text','date','date','text'],'snapshot function exists');
select has_function('public','sync_course_item_to_cohorts',array['uuid','uuid[]'],'sync function exists');
select has_function('public','sync_new_course_content_to_cohorts',array['uuid','uuid[]'],'new-content sync function exists');
select policies_are('public','cohorts',array['student reads accessible cohort','teacher manages own cohorts'],'cohort policies are explicit');

-- sync_new_course_content_to_cohorts: pushes course content added after
-- the cohort snapshot was already taken into that existing cohort.
insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values ('22222222-2222-2222-2222-222222222221','sync-test@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='teacher', display_name='Sync Test Teacher' where id='22222222-2222-2222-2222-222222222221';
insert into public.courses(id, teacher_id, title) values ('22222222-2222-2222-2222-222222222222','22222222-2222-2222-2222-222222222221','Sync Test Course');
insert into public.course_modules(id, course_id, title, position) values ('22222222-2222-2222-2222-222222222223','22222222-2222-2222-2222-222222222222','Existing Module',0);
insert into public.course_items(id, course_id, kind, title, slug, publication_status)
values ('22222222-2222-2222-2222-222222222224','22222222-2222-2222-2222-222222222222','lecture','Existing Lecture','existing-lecture','published');
insert into public.course_module_items(module_id, item_id, position) values ('22222222-2222-2222-2222-222222222223','22222222-2222-2222-2222-222222222224',0);
insert into public.cohorts(id, course_id, teacher_id, title, start_date, end_date, timezone)
values ('22222222-2222-2222-2222-222222222227','22222222-2222-2222-2222-222222222222','22222222-2222-2222-2222-222222222221','Sync Test Cohort','2026-01-01','2026-02-01','UTC');
insert into public.cohort_modules(id, cohort_id, source_module_id, title, position)
values ('22222222-2222-2222-2222-222222222228','22222222-2222-2222-2222-222222222227','22222222-2222-2222-2222-222222222223','Existing Module',0);
insert into public.cohort_items(id, cohort_id, source_item_id, kind, title, slug, publication_status)
values ('22222222-2222-2222-2222-222222222229','22222222-2222-2222-2222-222222222227','22222222-2222-2222-2222-222222222224','lecture','Existing Lecture','existing-lecture','published');
insert into public.cohort_module_items(module_id, item_id, position) values ('22222222-2222-2222-2222-222222222228','22222222-2222-2222-2222-222222222229',0);

-- course content added AFTER the cohort snapshot above
insert into public.course_modules(id, course_id, title, position) values ('22222222-2222-2222-2222-222222222225','22222222-2222-2222-2222-222222222222','New Module',1);
insert into public.course_items(id, course_id, kind, title, slug, publication_status)
values ('22222222-2222-2222-2222-222222222226','22222222-2222-2222-2222-222222222222','assignment','New Assignment','new-assignment','published');
insert into public.course_module_items(module_id, item_id, position) values ('22222222-2222-2222-2222-222222222225','22222222-2222-2222-2222-222222222226',0);

select is(
  (select count(*)::int from public.cohort_modules where cohort_id = '22222222-2222-2222-2222-222222222227' and title = 'New Module'),
  0,
  'new module is absent from the cohort before syncing'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222221","role":"authenticated"}';
select public.sync_new_course_content_to_cohorts('22222222-2222-2222-2222-222222222222', array['22222222-2222-2222-2222-222222222227']::uuid[]) as first_sync_count \gset
select public.sync_new_course_content_to_cohorts('22222222-2222-2222-2222-222222222222', array['22222222-2222-2222-2222-222222222227']::uuid[]) as second_sync_count \gset
reset role;
select is(
  (select count(*)::int from public.cohort_module_items p
    join public.cohort_modules cm on cm.id = p.module_id and cm.title = 'New Module'
    join public.cohort_items ci on ci.id = p.item_id and ci.title = 'New Assignment'
    where cm.cohort_id = '22222222-2222-2222-2222-222222222227'),
  1,
  'syncing adds the new module, item, and their placement together'
);
select is(:second_sync_count, 0, 'syncing again is idempotent and creates nothing new');

-- A new item added to a module the cohort ALREADY has content in must not
-- collide with an existing placement's position: the cohort module's own
-- position numbering can differ from the course module's (e.g. after a
-- reorder on either side), so reusing the course-side position verbatim
-- can land on a position the cohort has already taken.
insert into public.course_items(id, course_id, kind, title, slug, publication_status)
values ('22222222-2222-2222-2222-22222222222a','22222222-2222-2222-2222-222222222222','lecture','Second Lecture In Existing Module','second-lecture-existing','published');
update public.course_module_items set position = 1 where module_id = '22222222-2222-2222-2222-222222222223' and item_id = '22222222-2222-2222-2222-222222222224';
insert into public.course_module_items(module_id, item_id, position) values ('22222222-2222-2222-2222-222222222223','22222222-2222-2222-2222-22222222222a',0);
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222221","role":"authenticated"}';
select lives_ok(
  $$select public.sync_new_course_content_to_cohorts('22222222-2222-2222-2222-222222222222', array['22222222-2222-2222-2222-222222222227']::uuid[])$$,
  'syncing a new item into a module the cohort already has a placement in does not collide on position'
);
reset role;

select * from finish();rollback;
