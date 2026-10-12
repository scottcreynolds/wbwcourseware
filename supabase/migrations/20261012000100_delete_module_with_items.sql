-- Deleting a module previously required the teacher to first move or delete
-- every item placed only in that module. It now deletes those module-only
-- items along with the module in one transaction. Items also placed in
-- another module survive (only this placement goes). Assignments that
-- already have student submissions still block the delete, because
-- submissions reference course_items with on delete restrict.
create or replace function public.delete_course_module(target_module_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
declare target_course_id uuid; module_only_item_ids uuid[];
begin
  select course_id into target_course_id from public.course_modules where id = target_module_id;
  if target_course_id is null or not public.owns_course(target_course_id) then raise exception 'not authorized'; end if;

  select coalesce(array_agg(selected.item_id), '{}') into module_only_item_ids
  from public.course_module_items selected
  where selected.module_id = target_module_id
    and not exists (
      select 1 from public.course_module_items other_placement
      where other_placement.item_id = selected.item_id and other_placement.module_id <> target_module_id
    );

  if exists (select 1 from public.submissions where course_item_id = any(module_only_item_ids)) then
    raise exception 'module contains assignments with student submissions; delete those submissions or move the assignments first';
  end if;

  delete from public.course_modules where id = target_module_id;
  delete from public.course_items where id = any(module_only_item_ids);
end;
$$;
revoke all on function public.delete_course_module(uuid) from public;
grant execute on function public.delete_course_module(uuid) to authenticated;
