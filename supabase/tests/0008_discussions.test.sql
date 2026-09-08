begin;
select plan(12);
select has_table('public', 'discussion_topics', 'topics table exists');
select has_table('public', 'discussion_replies', 'replies table exists');
select has_column('public', 'discussion_topics', 'deleted_at', 'topics soft-delete');
select has_column('public', 'discussion_replies', 'deleted_at', 'replies soft-delete');
select isnt_empty($$select 1 from pg_policies where tablename='discussion_topics' and policyname='authors or teacher update topics'$$, 'topic moderation policy exists');
select isnt_empty($$select 1 from pg_policies where tablename='discussion_replies' and policyname='authors or teacher update replies'$$, 'reply moderation policy exists');
select hasnt_column('public', 'discussion_replies', 'parent_id', 'replies cannot nest');
select has_function('public', 'get_course_discussions', array['uuid'], 'safe discussion query exists');

insert into auth.users(id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values ('11111111-1111-1111-1111-111111111111','discussion-test@example.com','x',now(),now(),now(),'{}','{}','authenticated','authenticated');
update public.profiles set role='teacher', display_name='Discussion Test Teacher' where id='11111111-1111-1111-1111-111111111111';
insert into public.courses(id, teacher_id, title, start_date, end_date, timezone)
values ('11111111-1111-1111-1111-111111111112','11111111-1111-1111-1111-111111111111','Discussion Test Course','2026-01-01','2026-02-01','UTC');
insert into public.discussion_topics(id, course_id, author_id, title, body_markdown)
values ('11111111-1111-1111-1111-111111111114','11111111-1111-1111-1111-111111111112','11111111-1111-1111-1111-111111111111','Topic','Body');
insert into public.discussion_replies(id, topic_id, author_id, body_markdown)
values ('11111111-1111-1111-1111-111111111115','11111111-1111-1111-1111-111111111114','11111111-1111-1111-1111-111111111111','Reply');

select lives_ok(
  $$update public.discussion_topics set title = 'Edited' where id = '11111111-1111-1111-1111-111111111114'$$,
  'editing a topic does not trip the identity trigger'
);
select lives_ok(
  $$update public.discussion_topics set deleted_at = now() where id = '11111111-1111-1111-1111-111111111114'$$,
  'soft-deleting a topic does not trip the identity trigger'
);
select lives_ok(
  $$update public.discussion_replies set body_markdown = 'Edited reply' where id = '11111111-1111-1111-1111-111111111115'$$,
  'editing a reply does not trip the identity trigger'
);
select lives_ok(
  $$update public.discussion_replies set deleted_at = now() where id = '11111111-1111-1111-1111-111111111115'$$,
  'soft-deleting a reply does not trip the identity trigger'
);

select * from finish();
rollback;
