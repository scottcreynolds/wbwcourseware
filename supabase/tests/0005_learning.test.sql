begin;
select plan(7);
select has_function('public','get_student_cohort_outline',array['uuid'],'safe student outline exists');
select policies_are('public','courses',array['student reads course metadata for enrolled cohort','teacher manages own courses'],'course metadata access is explicit');
select function_privs_are('public','get_student_cohort_outline',array['uuid'],'authenticated',array['EXECUTE'],'students may request authorized outline');
select has_function('public','get_student_cohort_item',array['uuid','uuid'],'live-resolved single item fetch exists');
select has_function('public','effective_item_publication_status',array['cohort_items'],'effective publication status resolver exists');

-- Publishing a course item after it has already been synced into a cohort
-- (as a draft) must make it visible without re-syncing: cohort_items.
-- publication_status is a stale copy, not the source of truth once linked.
insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values
  ('33333333-3333-3333-3333-333333333331','live-content-teacher@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated'),
  ('33333333-3333-3333-3333-333333333332','live-content-student@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='teacher', display_name='Live Content Teacher' where id='33333333-3333-3333-3333-333333333331';
update public.profiles set role='student', display_name='Live Content Student', email_normalized='live-content-student@example.com' where id='33333333-3333-3333-3333-333333333332';
insert into public.courses(id, teacher_id, title, status) values ('33333333-3333-3333-3333-333333333333','33333333-3333-3333-3333-333333333331','Live Content Course','active');
insert into public.course_modules(id, course_id, title, position) values ('33333333-3333-3333-3333-333333333334','33333333-3333-3333-3333-333333333333','Module One',0);
insert into public.course_items(id, course_id, kind, title, slug, body_markdown, publication_status)
  values ('33333333-3333-3333-3333-333333333335','33333333-3333-3333-3333-333333333333','lecture','Lecture One','lecture-one-live','Real content','draft');
insert into public.course_module_items(module_id, item_id, position) values ('33333333-3333-3333-3333-333333333334','33333333-3333-3333-3333-333333333335',0);
insert into public.cohorts(id, course_id, teacher_id, title, start_date, end_date, timezone, status)
  values ('33333333-3333-3333-3333-333333333336','33333333-3333-3333-3333-333333333333','33333333-3333-3333-3333-333333333331','Live Content Cohort','2026-01-01','2026-02-01','UTC','active');
insert into public.cohort_enrollments(id, cohort_id, student_id, status)
  values ('33333333-3333-3333-3333-333333333337','33333333-3333-3333-3333-333333333336','33333333-3333-3333-3333-333333333332','active');
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333331","role":"authenticated"}';
select public.sync_new_course_content_to_cohorts('33333333-3333-3333-3333-333333333333', array['33333333-3333-3333-3333-333333333336']::uuid[]) as sync_count \gset
reset role;
update public.cohort_modules set manually_released_at = now() where cohort_id = '33333333-3333-3333-3333-333333333336';

select is(
  (select ci.publication_status::text from public.cohort_items ci where ci.source_item_id = '33333333-3333-3333-3333-333333333335'),
  'draft',
  'the synced cohort_items copy starts draft, matching the course item at sync time'
);

-- publish on the course side, WITHOUT re-syncing
update public.course_items set publication_status = 'published' where id = '33333333-3333-3333-3333-333333333335';

set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333332","role":"authenticated"}';
select is(
  (select jsonb_array_length(m.value -> 'items') from jsonb_array_elements(
    public.get_student_cohort_outline('33333333-3333-3333-3333-333333333336') -> 'modules'
  ) m),
  1,
  'the outline shows the item as soon as the course item is published, with no re-sync'
);
reset role;

select * from finish();rollback;
