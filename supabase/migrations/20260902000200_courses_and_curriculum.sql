create type public.course_status as enum ('draft', 'active', 'archived');
create type public.curriculum_item_kind as enum ('lecture', 'assignment');
create type public.publication_status as enum ('draft', 'published');

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.profiles(id),
  title text not null check (length(btrim(title)) between 1 and 160),
  description text not null default '' check (length(description) <= 5000),
  status public.course_status not null default 'draft',
  branding_json jsonb not null default '{}'::jsonb check (jsonb_typeof(branding_json) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.course_modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 160),
  description text not null default '' check (length(description) <= 5000),
  position integer not null check (position >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_id, position)
);

create table public.course_items (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  kind public.curriculum_item_kind not null,
  title text not null check (length(btrim(title)) between 1 and 200),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  body_markdown text not null default '' check (length(body_markdown) <= 1000000),
  publication_status public.publication_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_id, slug),
  unique (id, course_id)
);

create table public.course_module_items (
  module_id uuid not null references public.course_modules(id) on delete cascade,
  item_id uuid not null references public.course_items(id) on delete cascade,
  position integer not null check (position >= 0),
  created_at timestamptz not null default now(),
  primary key (module_id, item_id),
  unique (module_id, position)
);

create table public.course_item_resources (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.course_items(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 200),
  url text not null check (url ~ '^https?://'),
  description text not null default '' check (length(description) <= 2000),
  position integer not null check (position >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (item_id, position)
);

create trigger courses_set_updated_at before update on public.courses
  for each row execute function public.set_updated_at();
create trigger course_modules_set_updated_at before update on public.course_modules
  for each row execute function public.set_updated_at();
create trigger course_items_set_updated_at before update on public.course_items
  for each row execute function public.set_updated_at();
create trigger course_item_resources_set_updated_at before update on public.course_item_resources
  for each row execute function public.set_updated_at();

alter table public.courses enable row level security;
alter table public.course_modules enable row level security;
alter table public.course_items enable row level security;
alter table public.course_module_items enable row level security;
alter table public.course_item_resources enable row level security;

create function public.is_teacher()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'teacher'
  );
$$;
revoke all on function public.is_teacher() from public;
grant execute on function public.is_teacher() to authenticated;

create function public.owns_course(target_course_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.courses
    where id = target_course_id
      and teacher_id = (select auth.uid())
      and public.is_teacher()
  );
$$;
revoke all on function public.owns_course(uuid) from public;
grant execute on function public.owns_course(uuid) to authenticated;

create policy "teacher manages own courses" on public.courses
  for all to authenticated
  using (teacher_id = (select auth.uid()) and public.is_teacher())
  with check (teacher_id = (select auth.uid()) and public.is_teacher());

create policy "teacher manages own course modules" on public.course_modules
  for all to authenticated
  using (public.owns_course(course_id))
  with check (public.owns_course(course_id));

create policy "teacher manages own course items" on public.course_items
  for all to authenticated
  using (public.owns_course(course_id))
  with check (public.owns_course(course_id));

create policy "teacher manages own module placements" on public.course_module_items
  for all to authenticated
  using (exists (
    select 1 from public.course_modules m
    where m.id = module_id and public.owns_course(m.course_id)
  ))
  with check (exists (
    select 1
    from public.course_modules m
    join public.course_items i on i.id = item_id and i.course_id = m.course_id
    where m.id = module_id and public.owns_course(m.course_id)
  ));

create policy "teacher manages own item resources" on public.course_item_resources
  for all to authenticated
  using (exists (
    select 1 from public.course_items i
    where i.id = item_id and public.owns_course(i.course_id)
  ))
  with check (exists (
    select 1 from public.course_items i
    where i.id = item_id and public.owns_course(i.course_id)
  ));

grant select, insert, update, delete on public.courses to authenticated;
grant select, insert, update, delete on public.course_modules to authenticated;
grant select, insert, update, delete on public.course_items to authenticated;
grant select, insert, update, delete on public.course_module_items to authenticated;
grant select, insert, update, delete on public.course_item_resources to authenticated;

create function public.next_course_module_position(target_course_id uuid)
returns integer language sql stable security invoker set search_path = ''
as $$
  select coalesce(max(position) + 1, 0)
  from public.course_modules where course_id = target_course_id;
$$;
revoke all on function public.next_course_module_position(uuid) from public;
grant execute on function public.next_course_module_position(uuid) to authenticated;

create function public.next_module_item_position(target_module_id uuid)
returns integer language sql stable security invoker set search_path = ''
as $$
  select coalesce(max(position) + 1, 0)
  from public.course_module_items where module_id = target_module_id;
$$;
revoke all on function public.next_module_item_position(uuid) from public;
grant execute on function public.next_module_item_position(uuid) to authenticated;

create function public.create_course_item(
  target_course_id uuid,
  target_module_id uuid,
  item_kind public.curriculum_item_kind,
  item_title text,
  item_slug text
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare new_item_id uuid;
begin
  if not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;
  if not exists (
    select 1 from public.course_modules
    where id = target_module_id and course_id = target_course_id
  ) then raise exception 'module does not belong to course'; end if;

  insert into public.course_items(course_id, kind, title, slug)
  values(target_course_id, item_kind, btrim(item_title), item_slug)
  returning id into new_item_id;

  insert into public.course_module_items(module_id, item_id, position)
  values(target_module_id, new_item_id, public.next_module_item_position(target_module_id));
  return new_item_id;
end;
$$;
revoke all on function public.create_course_item(uuid, uuid, public.curriculum_item_kind, text, text) from public;
grant execute on function public.create_course_item(uuid, uuid, public.curriculum_item_kind, text, text) to authenticated;

create function public.reorder_course_modules(target_course_id uuid, ordered_ids uuid[])
returns void language plpgsql security invoker set search_path = ''
as $$
declare current_count integer; supplied_count integer;
begin
  if not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;
  select count(*) into current_count from public.course_modules where course_id = target_course_id;
  select count(distinct value) into supplied_count from unnest(ordered_ids) value;
  if current_count <> supplied_count or exists (
    select 1 from unnest(ordered_ids) value
    where not exists (
      select 1 from public.course_modules where id = value and course_id = target_course_id
    )
  ) then raise exception 'ordered_ids must contain every module exactly once'; end if;

  update public.course_modules set position = position + 1000000 where course_id = target_course_id;
  update public.course_modules m set position = ordering.position
  from unnest(ordered_ids) with ordinality ordering(id, position)
  where m.id = ordering.id;
end;
$$;
revoke all on function public.reorder_course_modules(uuid, uuid[]) from public;
grant execute on function public.reorder_course_modules(uuid, uuid[]) to authenticated;

create function public.reorder_module_items(target_module_id uuid, ordered_ids uuid[])
returns void language plpgsql security invoker set search_path = ''
as $$
declare current_count integer; supplied_count integer; target_course_id uuid;
begin
  select course_id into target_course_id from public.course_modules where id = target_module_id;
  if target_course_id is null or not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;
  select count(*) into current_count from public.course_module_items where module_id = target_module_id;
  select count(distinct value) into supplied_count from unnest(ordered_ids) value;
  if current_count <> supplied_count or exists (
    select 1 from unnest(ordered_ids) value
    where not exists (
      select 1 from public.course_module_items where module_id = target_module_id and item_id = value
    )
  ) then raise exception 'ordered_ids must contain every item exactly once'; end if;

  update public.course_module_items set position = position + 1000000 where module_id = target_module_id;
  update public.course_module_items p set position = ordering.position
  from unnest(ordered_ids) with ordinality ordering(id, position)
  where p.module_id = target_module_id and p.item_id = ordering.id;
end;
$$;
revoke all on function public.reorder_module_items(uuid, uuid[]) from public;
grant execute on function public.reorder_module_items(uuid, uuid[]) to authenticated;

create function public.remove_course_item_placement(target_module_id uuid, target_item_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
declare target_course_id uuid; placement_count integer;
begin
  select course_id into target_course_id from public.course_modules where id = target_module_id;
  if target_course_id is null or not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;
  select count(*) into placement_count from public.course_module_items where item_id = target_item_id;
  if placement_count <= 1 then raise exception 'item must remain in at least one module'; end if;
  delete from public.course_module_items where module_id = target_module_id and item_id = target_item_id;
end;
$$;
revoke all on function public.remove_course_item_placement(uuid, uuid) from public;
grant execute on function public.remove_course_item_placement(uuid, uuid) to authenticated;

create function public.delete_course_module(target_module_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
declare target_course_id uuid;
begin
  select course_id into target_course_id from public.course_modules where id = target_module_id;
  if target_course_id is null or not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;
  if exists (
    select 1 from public.course_module_items selected
    where selected.module_id = target_module_id
      and (select count(*) from public.course_module_items all_placements where all_placements.item_id = selected.item_id) = 1
  ) then raise exception 'move or delete module-only items before deleting module'; end if;
  delete from public.course_modules where id = target_module_id;
end;
$$;
revoke all on function public.delete_course_module(uuid) from public;
grant execute on function public.delete_course_module(uuid) to authenticated;

create function public.reorder_item_resources(target_item_id uuid, ordered_ids uuid[])
returns void language plpgsql security invoker set search_path = ''
as $$
declare target_course_id uuid; current_count integer; supplied_count integer;
begin
  select course_id into target_course_id from public.course_items where id = target_item_id;
  if target_course_id is null or not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;
  select count(*) into current_count from public.course_item_resources where item_id = target_item_id;
  select count(distinct value) into supplied_count from unnest(ordered_ids) value;
  if current_count <> supplied_count or exists (
    select 1 from unnest(ordered_ids) value
    where not exists (
      select 1 from public.course_item_resources where item_id = target_item_id and id = value
    )
  ) then raise exception 'ordered_ids must contain every resource exactly once'; end if;
  update public.course_item_resources set position = position + 1000000 where item_id = target_item_id;
  update public.course_item_resources r set position = ordering.position
  from unnest(ordered_ids) with ordinality ordering(id, position)
  where r.item_id = target_item_id and r.id = ordering.id;
end;
$$;
revoke all on function public.reorder_item_resources(uuid, uuid[]) from public;
grant execute on function public.reorder_item_resources(uuid, uuid[]) to authenticated;

create function public.import_course_outline(target_course_id uuid, outline jsonb)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare
  module_data jsonb; item_data jsonb; new_module_id uuid; new_item_id uuid;
  module_position integer; item_position integer; item_slug text; base_slug text; suffix integer;
  created_modules integer := 0; created_items integer := 0;
begin
  if not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;
  if jsonb_typeof(outline) <> 'array' or jsonb_array_length(outline) = 0 then
    raise exception 'outline must contain modules';
  end if;
  module_position := public.next_course_module_position(target_course_id);

  for module_data in select value from jsonb_array_elements(outline)
  loop
    if length(btrim(coalesce(module_data ->> 'title', ''))) = 0 then raise exception 'module title is required'; end if;
    insert into public.course_modules(course_id, title, position)
    values(target_course_id, btrim(module_data ->> 'title'), module_position)
    returning id into new_module_id;
    module_position := module_position + 1; created_modules := created_modules + 1; item_position := 0;

    for item_data in select value from jsonb_array_elements(coalesce(module_data -> 'items', '[]'::jsonb))
    loop
      if item_data ->> 'kind' not in ('lecture', 'assignment') then raise exception 'invalid item kind'; end if;
      if length(btrim(coalesce(item_data ->> 'title', ''))) = 0 then raise exception 'item title is required'; end if;
      base_slug := trim(both '-' from regexp_replace(lower(item_data ->> 'title'), '[^a-z0-9]+', '-', 'g'));
      if base_slug = '' then base_slug := 'untitled'; end if;
      item_slug := base_slug; suffix := 2;
      while exists(select 1 from public.course_items where course_id = target_course_id and slug = item_slug) loop
        item_slug := base_slug || '-' || suffix::text; suffix := suffix + 1;
      end loop;
      insert into public.course_items(course_id, kind, title, slug)
      values(target_course_id, (item_data ->> 'kind')::public.curriculum_item_kind, btrim(item_data ->> 'title'), item_slug)
      returning id into new_item_id;
      insert into public.course_module_items(module_id, item_id, position)
      values(new_module_id, new_item_id, item_position);
      item_position := item_position + 1; created_items := created_items + 1;
    end loop;
  end loop;
  return jsonb_build_object('modulesCreated', created_modules, 'itemsCreated', created_items);
end;
$$;
revoke all on function public.import_course_outline(uuid, jsonb) from public;
grant execute on function public.import_course_outline(uuid, jsonb) to authenticated;
