-- Same gap as 20260908001800 fixed for announcements: discussion RLS
-- policies and get_course_discussions gated student access purely on
-- enrollment (is_active_student_in_course), never courses.status, so a
-- still-draft course's discussion board was fully readable and postable
-- by an already-invited student. Every other student-facing read path
-- requires status<>'draft'; bring discussions in line with that.
--
-- get_course_discussions is security definer and bypasses table RLS
-- entirely, so it needs its own fix -- the RLS policies below only cover
-- direct table reads, which the RPC does not use.
create or replace function public.get_course_discussions(target_course_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select case when public.owns_course(target_course_id)
    or (public.is_active_student_in_course(target_course_id)
      and exists(select 1 from public.courses c where c.id = target_course_id and c.status <> 'draft'))
    then coalesce(jsonb_agg(jsonb_build_object(
      'id', t.id, 'authorId', t.author_id, 'authorName', coalesce(p.display_name, 'Member'),
      'title', case when t.deleted_at is null or public.owns_course(target_course_id) then t.title else 'Deleted topic' end,
      'bodyMarkdown', case when t.deleted_at is null or public.owns_course(target_course_id) then t.body_markdown else '' end,
      'createdAt', t.created_at,
      'deletedAt', t.deleted_at, 'replies', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', r.id, 'authorId', r.author_id, 'authorName', coalesce(rp.display_name, 'Member'),
          'bodyMarkdown', case when r.deleted_at is null or public.owns_course(target_course_id) then r.body_markdown else '' end,
          'createdAt', r.created_at, 'deletedAt', r.deleted_at
        ) order by r.created_at), '[]'::jsonb)
        from public.discussion_replies r join public.profiles rp on rp.id = r.author_id
        where r.topic_id = t.id
      )
    ) order by t.created_at desc), '[]'::jsonb)
    else '[]'::jsonb end
  from public.discussion_topics t join public.profiles p on p.id = t.author_id
  where t.course_id = target_course_id
$$;

drop policy if exists "members read topics" on public.discussion_topics;
create policy "members read topics" on public.discussion_topics for select to authenticated
using(public.owns_course(course_id) or (
  deleted_at is null and public.is_active_student_in_course(course_id)
  and exists(select 1 from public.courses c where c.id = discussion_topics.course_id and c.status <> 'draft')
));
drop policy if exists "members create topics" on public.discussion_topics;
create policy "members create topics" on public.discussion_topics for insert to authenticated
with check(author_id = (select auth.uid()) and (public.owns_course(course_id) or (
  public.is_active_student_in_course(course_id)
  and exists(select 1 from public.courses c where c.id = discussion_topics.course_id and c.status <> 'draft')
)));

drop policy if exists "members read replies" on public.discussion_replies;
create policy "members read replies" on public.discussion_replies for select to authenticated
using(exists(select 1 from public.discussion_topics t where t.id = discussion_replies.topic_id
  and (public.owns_course(t.course_id) or (
    discussion_replies.deleted_at is null and public.is_active_student_in_course(t.course_id)
    and exists(select 1 from public.courses c where c.id = t.course_id and c.status <> 'draft')
  ))));
drop policy if exists "members create replies" on public.discussion_replies;
create policy "members create replies" on public.discussion_replies for insert to authenticated
with check(author_id = (select auth.uid()) and exists(select 1 from public.discussion_topics t
  where t.id = discussion_replies.topic_id and t.deleted_at is null
    and (public.owns_course(t.course_id) or (
      public.is_active_student_in_course(t.course_id)
      and exists(select 1 from public.courses c where c.id = t.course_id and c.status <> 'draft')
    ))));
