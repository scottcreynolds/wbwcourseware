-- protect_discussion_identity referenced new.topic_id / new.cohort_id
-- unconditionally, but NEW/OLD are typed per-table in a trigger, so the
-- shared function raised "record has no field" on every update to either
-- table (including soft-delete) regardless of the tg_table_name guard.
drop trigger protect_discussion_topic_identity on public.discussion_topics;
drop trigger protect_discussion_reply_identity on public.discussion_replies;
drop function public.protect_discussion_identity();

create function public.protect_discussion_topic_identity()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.cohort_id <> old.cohort_id or new.author_id <> old.author_id then
    raise exception 'discussion identity is immutable';
  end if;
  if old.deleted_at is not null and current_user not in ('service_role', 'postgres') then
    raise exception 'deleted discussion content is immutable';
  end if;
  return new;
end $$;
create trigger protect_discussion_topic_identity before update on public.discussion_topics
for each row execute function public.protect_discussion_topic_identity();
revoke all on function public.protect_discussion_topic_identity() from public, anon, authenticated;

create function public.protect_discussion_reply_identity()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.topic_id <> old.topic_id or new.author_id <> old.author_id then
    raise exception 'discussion identity is immutable';
  end if;
  if old.deleted_at is not null and current_user not in ('service_role', 'postgres') then
    raise exception 'deleted discussion content is immutable';
  end if;
  return new;
end $$;
create trigger protect_discussion_reply_identity before update on public.discussion_replies
for each row execute function public.protect_discussion_reply_identity();
revoke all on function public.protect_discussion_reply_identity() from public, anon, authenticated;
