create function public.protect_announcement_publication_state()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (new.status <> old.status or new.published_at is distinct from old.published_at)
    and current_user not in ('service_role', 'postgres') then
    raise exception 'announcement publication state is immutable outside publish-announcement';
  end if;
  return new;
end $$;
create trigger protect_announcement_publication_state before update on public.announcements
for each row execute function public.protect_announcement_publication_state();

drop policy "teacher manages announcements" on public.announcements;
create policy "teacher manages announcements" on public.announcements for all to authenticated
using(public.owns_cohort(cohort_id))
with check(public.owns_cohort(cohort_id) and author_id = (select auth.uid()));
