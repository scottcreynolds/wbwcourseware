-- Instructor-only teaching notes per module: a place to teach from, never
-- visible to students. A separate table (not a column on course_modules)
-- because course_modules already carries a student-facing SELECT policy
-- ("student reads released modules") with no column restriction -- RLS is
-- row-scoped, not column-scoped, and this schema never uses column-level
-- grants anywhere. A new column there would be reachable by any
-- authenticated student issuing `select *` against their own enrolled,
-- released module row. Isolating notes on their own table, with only a
-- teacher-ownership policy and no student policy at all, makes it
-- structurally impossible for a student role to match any row.

create table public.course_module_notes (
  module_id uuid primary key references public.course_modules(id) on delete cascade,
  notes_markdown text not null default '' check (length(notes_markdown) <= 1000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger course_module_notes_set_updated_at before update on public.course_module_notes
  for each row execute function public.set_updated_at();

alter table public.course_module_notes enable row level security;

create policy "teacher manages own module notes" on public.course_module_notes
  for all to authenticated
  using (exists (select 1 from public.course_modules m where m.id = module_id and public.owns_course(m.course_id)))
  with check (exists (select 1 from public.course_modules m where m.id = module_id and public.owns_course(m.course_id)));

grant select, insert, update, delete on public.course_module_notes to authenticated;

-- duplicate_course copies teaching notes the same way it copies item
-- body_markdown: notes are teaching material tied to content, not
-- term-specific state like release schedule or due dates, which reset.
create or replace function public.duplicate_course(target_course_id uuid, new_title text)
returns uuid language plpgsql security invoker set search_path=''
as $$
declare
  new_course_id uuid;
  source_module record;
  source_item record;
  new_module_id uuid;
  new_item_id uuid;
begin
  if not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;
  insert into public.courses(teacher_id,title,description,status,branding_json,start_date,end_date,timezone,intro_markdown)
  select (select auth.uid()),btrim(new_title),description,'draft',branding_json,start_date,end_date,timezone,intro_markdown
  from public.courses where id=target_course_id
  returning id into new_course_id;

  -- module_id_map / item_id_map: source id -> newly created id, so
  -- placements (which can reference the same item from multiple modules)
  -- are wired up afterward instead of duplicating an item per placement.
  create temporary table module_id_map(source_id uuid primary key, new_id uuid not null) on commit drop;
  create temporary table item_id_map(source_id uuid primary key, new_id uuid not null) on commit drop;

  for source_module in select * from public.course_modules where course_id=target_course_id order by position loop
    insert into public.course_modules(course_id,title,description,position,release_mode,release_at,manually_released_at)
    values(new_course_id,source_module.title,source_module.description,source_module.position,'manual',null,null)
    returning id into new_module_id;
    insert into module_id_map(source_id,new_id) values(source_module.id,new_module_id);
  end loop;

  for source_item in select * from public.course_items where course_id=target_course_id loop
    insert into public.course_items(course_id,kind,title,slug,body_markdown,publication_status,due_at)
    values(new_course_id,source_item.kind,source_item.title,source_item.slug,source_item.body_markdown,source_item.publication_status,null)
    returning id into new_item_id;
    insert into item_id_map(source_id,new_id) values(source_item.id,new_item_id);
    insert into public.course_item_resources(item_id,title,url,description,position)
    select new_item_id,r.title,r.url,r.description,r.position
    from public.course_item_resources r where r.item_id=source_item.id;
  end loop;

  insert into public.course_module_items(module_id,item_id,position)
  select mm.new_id,im.new_id,p.position
  from public.course_module_items p
  join module_id_map mm on mm.source_id=p.module_id
  join item_id_map im on im.source_id=p.item_id;

  insert into public.course_module_notes(module_id,notes_markdown)
  select mm.new_id,n.notes_markdown
  from public.course_module_notes n
  join module_id_map mm on mm.source_id=n.module_id;

  return new_course_id;
end $$;
revoke all on function public.duplicate_course(uuid, text) from public;
grant execute on function public.duplicate_course(uuid, text) to authenticated;
