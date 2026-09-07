-- create_cohort_from_course only snapshots modules/items that exist at
-- creation time; sync_course_item_to_cohorts only refreshes content for
-- items already present in the cohort. Neither can push a module or item
-- added to the course afterward into an existing cohort, so newly added
-- curriculum silently never appears for that cohort's teacher or students.
create function public.sync_new_course_content_to_cohorts(target_course_id uuid, target_cohort_ids uuid[])
returns integer language plpgsql security invoker set search_path=''
as $$
declare
  target_cohort_id uuid;
  next_module_position integer;
  source_module record;
  source_item record;
  source_placement record;
  new_module_id uuid;
  new_item_id uuid;
  created_count integer := 0;
begin
  if not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;
  if exists(
    select 1 from unnest(target_cohort_ids) id
    where not exists(select 1 from public.cohorts c where c.id = id and c.course_id = target_course_id and public.owns_cohort(c.id))
  ) then raise exception 'invalid cohort selection'; end if;

  foreach target_cohort_id in array target_cohort_ids loop
    select coalesce(max(position) + 1, 0) into next_module_position
    from public.cohort_modules where cohort_id = target_cohort_id;

    for source_module in
      select cm.* from public.course_modules cm
      where cm.course_id = target_course_id
        and not exists(select 1 from public.cohort_modules where cohort_id = target_cohort_id and source_module_id = cm.id)
      order by cm.position
    loop
      insert into public.cohort_modules(cohort_id, source_module_id, title, description, position)
      values(target_cohort_id, source_module.id, source_module.title, source_module.description, next_module_position);
      next_module_position := next_module_position + 1;
      created_count := created_count + 1;
    end loop;

    for source_item in
      select ci.* from public.course_items ci
      where ci.course_id = target_course_id
        and not exists(select 1 from public.cohort_items where cohort_id = target_cohort_id and source_item_id = ci.id)
    loop
      insert into public.cohort_items(cohort_id, source_item_id, kind, title, slug, body_markdown, publication_status)
      values(target_cohort_id, source_item.id, source_item.kind, source_item.title, source_item.slug, source_item.body_markdown, source_item.publication_status)
      returning id into new_item_id;
      insert into public.cohort_item_resources(item_id, source_resource_id, title, url, description, position)
        select new_item_id, r.id, r.title, r.url, r.description, r.position from public.course_item_resources r where r.item_id = source_item.id;
      created_count := created_count + 1;
    end loop;

    for source_placement in
      select p.module_id, p.item_id, p.position from public.course_module_items p
      join public.course_modules cm on cm.id = p.module_id and cm.course_id = target_course_id
      join public.course_items ci on ci.id = p.item_id and ci.course_id = target_course_id
    loop
      select cm.id into new_module_id from public.cohort_modules cm
      where cm.cohort_id = target_cohort_id and cm.source_module_id = source_placement.module_id;
      select ci.id into new_item_id from public.cohort_items ci
      where ci.cohort_id = target_cohort_id and ci.source_item_id = source_placement.item_id;
      if new_module_id is not null and new_item_id is not null then
        insert into public.cohort_module_items(module_id, item_id, position)
        values(new_module_id, new_item_id, source_placement.position)
        on conflict(module_id, item_id) do nothing;
      end if;
    end loop;
  end loop;

  return created_count;
end $$;
revoke all on function public.sync_new_course_content_to_cohorts(uuid, uuid[]) from public;
grant execute on function public.sync_new_course_content_to_cohorts(uuid, uuid[]) to authenticated;
