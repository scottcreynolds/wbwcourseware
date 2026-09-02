create type public.cohort_status as enum ('draft', 'active', 'archived');
create type public.module_release_mode as enum ('manual', 'scheduled');

create table public.cohorts (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id),
  teacher_id uuid not null references public.profiles(id),
  title text not null check (length(btrim(title)) between 1 and 200),
  start_date date not null,
  end_date date not null,
  timezone text not null check (length(btrim(timezone)) between 1 and 100),
  status public.cohort_status not null default 'draft',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create table public.cohort_modules (
  id uuid primary key default gen_random_uuid(),
  cohort_id uuid not null references public.cohorts(id) on delete cascade,
  source_module_id uuid references public.course_modules(id) on delete set null,
  title text not null, description text not null default '', position integer not null check (position >= 0),
  release_mode public.module_release_mode not null default 'manual',
  release_at timestamptz,
  manually_released_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(cohort_id, position), unique(cohort_id, source_module_id),
  check ((release_mode = 'scheduled' and release_at is not null) or release_mode = 'manual')
);

create table public.cohort_items (
  id uuid primary key default gen_random_uuid(),
  cohort_id uuid not null references public.cohorts(id) on delete cascade,
  source_item_id uuid references public.course_items(id) on delete set null,
  kind public.curriculum_item_kind not null, title text not null, slug text not null,
  body_markdown text not null default '', publication_status public.publication_status not null default 'draft',
  due_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(cohort_id, source_item_id), unique(cohort_id, slug), unique(id, cohort_id),
  check ((kind = 'assignment') or due_at is null)
);

create table public.cohort_module_items (
  module_id uuid not null references public.cohort_modules(id) on delete cascade,
  item_id uuid not null references public.cohort_items(id) on delete cascade,
  position integer not null check(position >= 0), created_at timestamptz not null default now(),
  primary key(module_id, item_id), unique(module_id, position)
);

create table public.cohort_item_resources (
  id uuid primary key default gen_random_uuid(), item_id uuid not null references public.cohort_items(id) on delete cascade,
  source_resource_id uuid references public.course_item_resources(id) on delete set null,
  title text not null, url text not null check(url ~ '^https?://'), description text not null default '',
  position integer not null check(position >= 0), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(item_id, position)
);

create trigger cohorts_set_updated_at before update on public.cohorts for each row execute function public.set_updated_at();
create trigger cohort_modules_set_updated_at before update on public.cohort_modules for each row execute function public.set_updated_at();
create trigger cohort_items_set_updated_at before update on public.cohort_items for each row execute function public.set_updated_at();
create trigger cohort_item_resources_set_updated_at before update on public.cohort_item_resources for each row execute function public.set_updated_at();

alter table public.cohorts enable row level security;
alter table public.cohort_modules enable row level security;
alter table public.cohort_items enable row level security;
alter table public.cohort_module_items enable row level security;
alter table public.cohort_item_resources enable row level security;

create function public.owns_cohort(target_cohort_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.cohorts where id=target_cohort_id and teacher_id=(select auth.uid()) and public.is_teacher()) $$;
revoke all on function public.owns_cohort(uuid) from public;
grant execute on function public.owns_cohort(uuid) to authenticated;

create policy "teacher manages own cohorts" on public.cohorts for all to authenticated
  using(teacher_id=(select auth.uid()) and public.is_teacher()) with check(teacher_id=(select auth.uid()) and public.is_teacher() and public.owns_course(course_id));
create policy "teacher manages own cohort modules" on public.cohort_modules for all to authenticated
  using(public.owns_cohort(cohort_id)) with check(public.owns_cohort(cohort_id));
create policy "teacher manages own cohort items" on public.cohort_items for all to authenticated
  using(public.owns_cohort(cohort_id)) with check(public.owns_cohort(cohort_id));
create policy "teacher manages own cohort placements" on public.cohort_module_items for all to authenticated
  using(exists(select 1 from public.cohort_modules m where m.id=module_id and public.owns_cohort(m.cohort_id)))
  with check(exists(select 1 from public.cohort_modules m join public.cohort_items i on i.id=item_id and i.cohort_id=m.cohort_id where m.id=module_id and public.owns_cohort(m.cohort_id)));
create policy "teacher manages own cohort resources" on public.cohort_item_resources for all to authenticated
  using(exists(select 1 from public.cohort_items i where i.id=item_id and public.owns_cohort(i.cohort_id)))
  with check(exists(select 1 from public.cohort_items i where i.id=item_id and public.owns_cohort(i.cohort_id)));

grant select,insert,update,delete on public.cohorts,public.cohort_modules,public.cohort_items,public.cohort_module_items,public.cohort_item_resources to authenticated;

create function public.create_cohort_from_course(
  target_course_id uuid, cohort_title text, cohort_start date, cohort_end date, cohort_timezone text
) returns uuid language plpgsql security invoker set search_path=''
as $$
declare new_cohort_id uuid; source_module record; source_item record; new_module_id uuid; new_item_id uuid;
begin
  if not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;
  if cohort_end < cohort_start then raise exception 'end date must not precede start date'; end if;
  insert into public.cohorts(course_id,teacher_id,title,start_date,end_date,timezone)
  values(target_course_id,(select auth.uid()),btrim(cohort_title),cohort_start,cohort_end,btrim(cohort_timezone)) returning id into new_cohort_id;
  for source_module in select * from public.course_modules where course_id=target_course_id order by position loop
    insert into public.cohort_modules(cohort_id,source_module_id,title,description,position)
    values(new_cohort_id,source_module.id,source_module.title,source_module.description,source_module.position) returning id into new_module_id;
  end loop;
  for source_item in select * from public.course_items where course_id=target_course_id loop
    insert into public.cohort_items(cohort_id,source_item_id,kind,title,slug,body_markdown,publication_status)
    values(new_cohort_id,source_item.id,source_item.kind,source_item.title,source_item.slug,source_item.body_markdown,source_item.publication_status) returning id into new_item_id;
    insert into public.cohort_item_resources(item_id,source_resource_id,title,url,description,position)
      select new_item_id,r.id,r.title,r.url,r.description,r.position from public.course_item_resources r where r.item_id=source_item.id;
  end loop;
  insert into public.cohort_module_items(module_id,item_id,position)
    select cm.id,ci.id,p.position from public.course_module_items p
    join public.cohort_modules cm on cm.cohort_id=new_cohort_id and cm.source_module_id=p.module_id
    join public.cohort_items ci on ci.cohort_id=new_cohort_id and ci.source_item_id=p.item_id;
  return new_cohort_id;
end $$;
revoke all on function public.create_cohort_from_course(uuid,text,date,date,text) from public;
grant execute on function public.create_cohort_from_course(uuid,text,date,date,text) to authenticated;

create function public.sync_course_item_to_cohorts(target_source_item_id uuid,target_cohort_ids uuid[])
returns integer language plpgsql security invoker set search_path=''
as $$
declare source_item public.course_items%rowtype; target_item record; updated_count integer:=0;
begin
  select * into source_item from public.course_items where id=target_source_item_id;
  if source_item.id is null or not public.owns_course(source_item.course_id) then raise exception 'not authorized'; end if;
  if exists(select 1 from unnest(target_cohort_ids) id where not exists(select 1 from public.cohorts c where c.id=id and c.course_id=source_item.course_id and public.owns_cohort(c.id))) then raise exception 'invalid cohort selection'; end if;
  for target_item in select ci.id from public.cohort_items ci where ci.source_item_id=source_item.id and ci.cohort_id=any(target_cohort_ids) loop
    update public.cohort_items set title=source_item.title,kind=source_item.kind,slug=source_item.slug,body_markdown=source_item.body_markdown where id=target_item.id;
    delete from public.cohort_item_resources where item_id=target_item.id;
    insert into public.cohort_item_resources(item_id,source_resource_id,title,url,description,position)
      select target_item.id,r.id,r.title,r.url,r.description,r.position from public.course_item_resources r where r.item_id=source_item.id;
    updated_count:=updated_count+1;
  end loop;
  return updated_count;
end $$;
revoke all on function public.sync_course_item_to_cohorts(uuid,uuid[]) from public;
grant execute on function public.sync_course_item_to_cohorts(uuid,uuid[]) to authenticated;

create function public.cohort_module_is_visible(module_row public.cohort_modules)
returns boolean language sql stable set search_path=''
as $$ select case when module_row.release_mode='scheduled' then module_row.release_at<=now() else module_row.manually_released_at is not null end $$;
revoke all on function public.cohort_module_is_visible(public.cohort_modules) from public;
grant execute on function public.cohort_module_is_visible(public.cohort_modules) to authenticated;
