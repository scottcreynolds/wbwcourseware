create table public.discussion_topics(
  id uuid primary key default gen_random_uuid(),
  cohort_id uuid not null references public.cohorts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete restrict,
  title text not null check(char_length(btrim(title)) between 1 and 200),
  body_markdown text not null default '',
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.discussion_replies(
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.discussion_topics(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete restrict,
  body_markdown text not null check(char_length(btrim(body_markdown)) > 0),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger discussion_topics_set_updated_at before update on public.discussion_topics
for each row execute function public.set_updated_at();
create trigger discussion_replies_set_updated_at before update on public.discussion_replies
for each row execute function public.set_updated_at();

create function public.protect_discussion_identity()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_table_name = 'discussion_topics' and (new.cohort_id <> old.cohort_id or new.author_id <> old.author_id) then
    raise exception 'discussion identity is immutable';
  end if;
  if tg_table_name = 'discussion_replies' and (new.topic_id <> old.topic_id or new.author_id <> old.author_id) then
    raise exception 'discussion identity is immutable';
  end if;
  return new;
end $$;
create trigger protect_discussion_topic_identity before update on public.discussion_topics
for each row execute function public.protect_discussion_identity();
create trigger protect_discussion_reply_identity before update on public.discussion_replies
for each row execute function public.protect_discussion_identity();

alter table public.discussion_topics enable row level security;
alter table public.discussion_replies enable row level security;

create policy "members read topics" on public.discussion_topics for select to authenticated
using(public.owns_cohort(cohort_id) or public.is_active_student_in_cohort(cohort_id));
create policy "members create topics" on public.discussion_topics for insert to authenticated
with check(author_id = (select auth.uid()) and (public.owns_cohort(cohort_id) or public.is_active_student_in_cohort(cohort_id)));
create policy "authors or teacher update topics" on public.discussion_topics for update to authenticated
using(author_id = (select auth.uid()) or public.owns_cohort(cohort_id))
with check(author_id = (select auth.uid()) or public.owns_cohort(cohort_id));

create policy "members read replies" on public.discussion_replies for select to authenticated
using(exists(
  select 1 from public.discussion_topics t where t.id = discussion_replies.topic_id
    and (public.owns_cohort(t.cohort_id) or public.is_active_student_in_cohort(t.cohort_id))
));
create policy "members create replies" on public.discussion_replies for insert to authenticated
with check(author_id = (select auth.uid()) and exists(
  select 1 from public.discussion_topics t where t.id = discussion_replies.topic_id and t.deleted_at is null
    and (public.owns_cohort(t.cohort_id) or public.is_active_student_in_cohort(t.cohort_id))
));
create policy "authors or teacher update replies" on public.discussion_replies for update to authenticated
using(author_id = (select auth.uid()) or exists(
  select 1 from public.discussion_topics t where t.id = discussion_replies.topic_id and public.owns_cohort(t.cohort_id)
)) with check(author_id = (select auth.uid()) or exists(
  select 1 from public.discussion_topics t where t.id = discussion_replies.topic_id and public.owns_cohort(t.cohort_id)
));

grant select, insert, update on public.discussion_topics, public.discussion_replies to authenticated;

create function public.get_cohort_discussions(target_cohort_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select case when public.owns_cohort(target_cohort_id) or public.is_active_student_in_cohort(target_cohort_id)
    then coalesce(jsonb_agg(jsonb_build_object(
      'id', t.id, 'authorId', t.author_id, 'authorName', coalesce(p.display_name, 'Member'),
      'title', t.title, 'bodyMarkdown', t.body_markdown, 'createdAt', t.created_at,
      'deletedAt', t.deleted_at, 'replies', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', r.id, 'authorId', r.author_id, 'authorName', coalesce(rp.display_name, 'Member'),
          'bodyMarkdown', r.body_markdown, 'createdAt', r.created_at, 'deletedAt', r.deleted_at
        ) order by r.created_at), '[]'::jsonb)
        from public.discussion_replies r join public.profiles rp on rp.id = r.author_id
        where r.topic_id = t.id
      )
    ) order by t.created_at desc), '[]'::jsonb)
    else '[]'::jsonb end
  from public.discussion_topics t join public.profiles p on p.id = t.author_id
  where t.cohort_id = target_cohort_id
$$;
revoke all on function public.get_cohort_discussions(uuid) from public;
grant execute on function public.get_cohort_discussions(uuid) to authenticated;

create index discussion_topics_cohort_idx on public.discussion_topics(cohort_id, created_at desc);
create index discussion_replies_topic_idx on public.discussion_replies(topic_id, created_at);
