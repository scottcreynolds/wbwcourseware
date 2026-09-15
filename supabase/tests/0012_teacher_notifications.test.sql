begin;
select plan(11);

select has_table('public', 'teacher_notifications', 'teacher_notifications table exists');
select col_is_unique('public', 'teacher_notifications', array['kind', 'source_id'], 'one notification per source row');
select isnt_empty(
  $$select 1 from pg_policies where tablename='teacher_notifications' and policyname='teacher reads own notifications'$$,
  'teacher read policy exists'
);
select table_privs_are('public', 'teacher_notifications', 'authenticated', array['SELECT'], 'only select is granted to authenticated');
select has_function('public', 'finalize_submission', array['uuid','uuid','jsonb'], 'finalize_submission still exists after redefinition');

insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values
  ('22222222-2222-2222-2222-222222222221','notif-test-teacher@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated'),
  ('22222222-2222-2222-2222-222222222222','notif-test-student@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated'),
  ('22222222-2222-2222-2222-222222222229','notif-other-teacher@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='teacher', display_name='Notification Test Teacher' where id='22222222-2222-2222-2222-222222222221';
update public.profiles set role='student', display_name='Notification Test Student', email_normalized='notif-test-student@example.com' where id='22222222-2222-2222-2222-222222222222';
-- profiles_single_teacher_unique allows only one teacher account; verify
-- cross-teacher isolation via a manual role/id substitution below instead of
-- a second real teacher profile.
insert into public.courses(id, teacher_id, title, status, start_date, end_date, timezone)
values ('22222222-2222-2222-2222-222222222223','22222222-2222-2222-2222-222222222221','Notification Test Course','active','2026-01-01','2026-06-01','UTC');
insert into public.course_enrollments(id, course_id, student_id, status)
values ('22222222-2222-2222-2222-222222222224','22222222-2222-2222-2222-222222222223','22222222-2222-2222-2222-222222222222','active');

-- A student's new top-level topic queues a pending notification for the
-- owning teacher.
insert into public.discussion_topics(id, course_id, author_id, title, body_markdown)
values ('22222222-2222-2222-2222-222222222225','22222222-2222-2222-2222-222222222223','22222222-2222-2222-2222-222222222222','Student topic','Body');
select is(
  (select count(*)::int from public.teacher_notifications
    where kind = 'discussion_topic' and source_id = '22222222-2222-2222-2222-222222222225'
      and teacher_id = '22222222-2222-2222-2222-222222222221' and status = 'pending'),
  1,
  'a student-authored topic queues one pending teacher notification'
);

-- The teacher's own topic must never queue a notification to themselves.
insert into public.discussion_topics(id, course_id, author_id, title, body_markdown)
values ('22222222-2222-2222-2222-222222222226','22222222-2222-2222-2222-222222222223','22222222-2222-2222-2222-222222222221','Teacher topic','Body');
select is(
  (select count(*)::int from public.teacher_notifications where source_id = '22222222-2222-2222-2222-222222222226'),
  0,
  'the teacher''s own topic does not queue a self-notification'
);

-- Re-inserting the same source id (defensive: should not happen via the
-- app, but the unique constraint must hold) does not duplicate the row.
insert into public.teacher_notifications(kind, course_id, teacher_id, source_id)
values ('discussion_topic', '22222222-2222-2222-2222-222222222223', '22222222-2222-2222-2222-222222222221', '22222222-2222-2222-2222-222222222225')
on conflict(kind, source_id) do nothing;
select is(
  (select count(*)::int from public.teacher_notifications where source_id = '22222222-2222-2222-2222-222222222225'),
  1,
  'duplicate notifications for the same source row are not created'
);

-- The owning teacher can read their notification; a student cannot read any.
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222221","role":"authenticated"}';
select is(
  (select count(*)::int from public.teacher_notifications where source_id = '22222222-2222-2222-2222-222222222225'),
  1,
  'the owning teacher can read their own notification'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
select is(
  (select count(*)::int from public.teacher_notifications where source_id = '22222222-2222-2222-2222-222222222225'),
  0,
  'a student cannot read teacher notifications'
);
reset role;

-- Cross-teacher isolation: promote a second profile to teacher (bypassing
-- profiles_single_teacher_unique is not needed since RLS is checked purely
-- by auth.uid() matching teacher_id, independent of current role values).
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222229","role":"authenticated"}';
select is(
  (select count(*)::int from public.teacher_notifications where source_id = '22222222-2222-2222-2222-222222222225'),
  0,
  'a different teacher cannot read another teacher''s notification'
);
reset role;

select * from finish();
rollback;
