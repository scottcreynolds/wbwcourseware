create type public.invitation_status as enum ('pending','accepted','revoked','expired');
create type public.enrollment_status as enum ('active','removed');

create table public.cohort_invitations(
  id uuid primary key default gen_random_uuid(), cohort_id uuid not null references public.cohorts(id) on delete cascade,
  email_normalized text not null, token_hash text not null unique, status public.invitation_status not null default 'pending',
  expires_at timestamptz not null, invited_by uuid not null references public.profiles(id), accepted_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(email_normalized=lower(btrim(email_normalized))),
  check(expires_at>created_at)
);
create unique index cohort_invitations_one_pending on public.cohort_invitations(cohort_id,email_normalized) where status='pending';
create table public.cohort_enrollments(
  id uuid primary key default gen_random_uuid(), cohort_id uuid not null references public.cohorts(id) on delete cascade,
  student_id uuid not null references public.profiles(id), invitation_id uuid references public.cohort_invitations(id),
  status public.enrollment_status not null default 'active', activated_at timestamptz not null default now(), removed_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(cohort_id,student_id), check((status='removed' and removed_at is not null) or status='active')
);
create trigger invitations_set_updated_at before update on public.cohort_invitations for each row execute function public.set_updated_at();
create trigger enrollments_set_updated_at before update on public.cohort_enrollments for each row execute function public.set_updated_at();
alter table public.cohort_invitations enable row level security;
alter table public.cohort_enrollments enable row level security;

create function public.is_active_student_in_cohort(target_cohort_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.cohort_enrollments where cohort_id=target_cohort_id and student_id=(select auth.uid()) and status='active') $$;
revoke all on function public.is_active_student_in_cohort(uuid) from public;
grant execute on function public.is_active_student_in_cohort(uuid) to authenticated;

create policy "teacher manages cohort invitations" on public.cohort_invitations for all to authenticated
 using(public.owns_cohort(cohort_id)) with check(public.owns_cohort(cohort_id));
create policy "teacher manages enrollments" on public.cohort_enrollments for all to authenticated
 using(public.owns_cohort(cohort_id)) with check(public.owns_cohort(cohort_id));
create policy "student reads own enrollment" on public.cohort_enrollments for select to authenticated
 using(student_id=(select auth.uid()));

create policy "student reads accessible cohort" on public.cohorts for select to authenticated
  using(status<>'draft' and public.is_active_student_in_cohort(id));

create function public.student_can_read_module(target_module_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.cohort_modules m join public.cohorts c on c.id=m.cohort_id
  where m.id=target_module_id and c.status<>'draft' and public.is_active_student_in_cohort(c.id) and public.cohort_module_is_visible(m)) $$;
revoke all on function public.student_can_read_module(uuid) from public;
grant execute on function public.student_can_read_module(uuid) to authenticated;

create function public.student_can_read_item(target_item_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.cohort_items i join public.cohorts c on c.id=i.cohort_id
  join public.cohort_module_items p on p.item_id=i.id join public.cohort_modules m on m.id=p.module_id
  where i.id=target_item_id and i.publication_status='published' and c.status<>'draft'
    and public.is_active_student_in_cohort(c.id) and public.cohort_module_is_visible(m)) $$;
revoke all on function public.student_can_read_item(uuid) from public;
grant execute on function public.student_can_read_item(uuid) to authenticated;

create policy "student reads released modules" on public.cohort_modules for select to authenticated
 using(public.student_can_read_module(id));
create policy "student reads published visible items" on public.cohort_items for select to authenticated
 using(public.student_can_read_item(id));
create policy "student reads visible placements" on public.cohort_module_items for select to authenticated
 using(public.student_can_read_module(module_id) and public.student_can_read_item(item_id));
create policy "student reads visible resources" on public.cohort_item_resources for select to authenticated
 using(public.student_can_read_item(item_id));
create policy "teacher reads enrolled student profiles" on public.profiles for select to authenticated
 using(public.is_teacher() and exists(select 1 from public.cohort_enrollments e join public.cohorts c on c.id=e.cohort_id where e.student_id=profiles.id and c.teacher_id=(select auth.uid())));

grant select,insert,update,delete on public.cohort_invitations to authenticated;
grant select,insert,update,delete on public.cohort_enrollments to authenticated;

create function public.activate_cohort_invitation(target_invitation_id uuid,target_student_id uuid,target_email text)
returns uuid language plpgsql security definer set search_path=''
as $$
declare inv public.cohort_invitations%rowtype; enrollment_id uuid;
begin
  if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;
  select * into inv from public.cohort_invitations where id=target_invitation_id for update;
  if inv.id is null or inv.status<>'pending' or inv.expires_at<=now() or inv.email_normalized<>lower(btrim(target_email)) then raise exception 'invalid invitation'; end if;
  if not exists(select 1 from public.profiles where id=target_student_id and role='student' and email_normalized=inv.email_normalized) then raise exception 'student profile mismatch'; end if;
  insert into public.cohort_enrollments(cohort_id,student_id,invitation_id,status,removed_at)
  values(inv.cohort_id,target_student_id,inv.id,'active',null)
  on conflict(cohort_id,student_id) do update set status='active',invitation_id=excluded.invitation_id,activated_at=now(),removed_at=null
  returning id into enrollment_id;
  update public.cohort_invitations set status='accepted',accepted_at=now() where id=inv.id;
  return enrollment_id;
end $$;
revoke all on function public.activate_cohort_invitation(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.activate_cohort_invitation(uuid,uuid,text) to service_role;
