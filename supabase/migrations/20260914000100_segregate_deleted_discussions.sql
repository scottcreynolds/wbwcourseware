-- Deleted discussion topics should never reach students at all (not even
-- as a masked "Deleted topic" placeholder) and should be segregated from
-- the active board for teachers rather than interleaved with it. The
-- previous version of this function sent every topic -- deleted or not --
-- to every caller, masking title/body for non-owning callers; now a
-- deleted topic is excluded from the result entirely unless the caller
-- owns the course, so masking is no longer needed for the only audience
-- (the owning teacher) that still receives the row.
create or replace function public.get_course_discussions(target_course_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select case when public.owns_course(target_course_id)
    or (public.is_active_student_in_course(target_course_id)
      and exists(select 1 from public.courses c where c.id = target_course_id and c.status <> 'draft'))
    then coalesce(jsonb_agg(jsonb_build_object(
      'id', t.id, 'authorId', t.author_id, 'authorName', coalesce(p.display_name, 'Member'),
      'title', t.title,
      'bodyMarkdown', t.body_markdown,
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
    and (t.deleted_at is null or public.owns_course(target_course_id))
$$;
revoke all on function public.get_course_discussions(uuid) from public;
grant execute on function public.get_course_discussions(uuid) to authenticated;
