create type public.announcement_status as enum ('draft', 'published');
create type public.delivery_status as enum ('pending', 'sent', 'failed');

create table public.announcements(
  id uuid primary key default gen_random_uuid(),
  cohort_id uuid not null references public.cohorts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete restrict,
  title text not null check(char_length(btrim(title)) between 1 and 200),
  body_markdown text not null default '',
  status public.announcement_status not null default 'draft',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check((status = 'draft' and published_at is null) or (status = 'published' and published_at is not null))
);

create table public.announcement_deliveries(
  id uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  enrollment_id uuid not null references public.cohort_enrollments(id) on delete restrict,
  email_normalized text not null,
  status public.delivery_status not null default 'pending',
  provider_message_id text,
  attempt_count integer not null default 0 check(attempt_count >= 0),
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(announcement_id, enrollment_id)
);

create trigger announcements_set_updated_at before update on public.announcements
for each row execute function public.set_updated_at();
create trigger announcement_deliveries_set_updated_at before update on public.announcement_deliveries
for each row execute function public.set_updated_at();

alter table public.announcements enable row level security;
alter table public.announcement_deliveries enable row level security;

create policy "teacher manages announcements" on public.announcements for all to authenticated
using(public.owns_cohort(cohort_id)) with check(
  public.owns_cohort(cohort_id) and author_id = (select auth.uid()) and status = 'draft'
);
create policy "student reads published announcements" on public.announcements for select to authenticated
using(status = 'published' and public.is_active_student_in_cohort(cohort_id));
create policy "teacher reads announcement deliveries" on public.announcement_deliveries for select to authenticated
using(exists(
  select 1 from public.announcements a
  where a.id = announcement_deliveries.announcement_id and public.owns_cohort(a.cohort_id)
));

grant select, insert, update, delete on public.announcements to authenticated;
grant select on public.announcement_deliveries to authenticated;

create function public.prepare_announcement_publication(target_announcement_id uuid, target_teacher_id uuid)
returns table(delivery_id uuid, recipient text, announcement_title text, announcement_body text, cohort_title text, attempts integer)
language plpgsql security definer set search_path = ''
as $$
declare target_cohort_id uuid;
begin
  if current_user not in ('service_role', 'postgres') then raise exception 'service role required'; end if;
  select a.cohort_id into target_cohort_id from public.announcements a
  join public.cohorts c on c.id = a.cohort_id
  where a.id = target_announcement_id and c.teacher_id = target_teacher_id for update;
  if target_cohort_id is null then raise exception 'not authorized'; end if;
  update public.announcements set status = 'published', published_at = coalesce(published_at, now())
  where id = target_announcement_id;
  insert into public.announcement_deliveries(announcement_id, enrollment_id, email_normalized)
  select target_announcement_id, e.id, p.email_normalized
  from public.cohort_enrollments e join public.profiles p on p.id = e.student_id
  where e.cohort_id = target_cohort_id and e.status = 'active'
  on conflict(announcement_id, enrollment_id) do nothing;
  return query
  select d.id, d.email_normalized, a.title, a.body_markdown, c.title, d.attempt_count
  from public.announcement_deliveries d
  join public.announcements a on a.id = d.announcement_id
  join public.cohorts c on c.id = a.cohort_id
  where d.announcement_id = target_announcement_id and d.status <> 'sent';
end $$;
revoke all on function public.prepare_announcement_publication(uuid, uuid) from public, anon, authenticated;
grant execute on function public.prepare_announcement_publication(uuid, uuid) to service_role;

create index announcements_cohort_published_idx on public.announcements(cohort_id, published_at desc);
create index announcement_deliveries_status_idx on public.announcement_deliveries(announcement_id, status);
