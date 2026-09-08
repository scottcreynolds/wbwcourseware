-- Cohorts previously held an independent, manually-synced copy of course
-- content (title/body/publication_status). Publishing an item on the course
-- never propagated to a cohort that had already been synced, so a teacher
-- could publish curriculum and it would stay invisible to students in any
-- cohort that already had a (draft) copy of that item/module.
--
-- Cohort-owned fields (due dates, module release scheduling, submissions)
-- still live on cohort_modules/cohort_items exactly as before. What changes
-- is that title/body/kind/slug/publication_status for a cohort item or
-- module LINKED to a course item/module (source_item_id/source_module_id
-- set) are now resolved live from the course row instead of trusting the
-- copy made at snapshot/sync time. A cohort item with no course link (none
-- exist today, but the column allows it) keeps using its own columns.
--
-- No existing data is dropped or migrated: the copied columns stay in
-- place as-is and simply stop being the source of truth for linked rows.

create function public.effective_item_publication_status(item_row public.cohort_items)
returns public.publication_status language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select ci.publication_status from public.course_items ci where ci.id = item_row.source_item_id),
    item_row.publication_status
  )
$$;
revoke all on function public.effective_item_publication_status(public.cohort_items) from public;
grant execute on function public.effective_item_publication_status(public.cohort_items) to authenticated;

create function public.effective_item_title(item_row public.cohort_items)
returns text language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select ci.title from public.course_items ci where ci.id = item_row.source_item_id),
    item_row.title
  )
$$;
revoke all on function public.effective_item_title(public.cohort_items) from public;
grant execute on function public.effective_item_title(public.cohort_items) to authenticated;

create function public.effective_item_body(item_row public.cohort_items)
returns text language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select ci.body_markdown from public.course_items ci where ci.id = item_row.source_item_id),
    item_row.body_markdown
  )
$$;
revoke all on function public.effective_item_body(public.cohort_items) from public;
grant execute on function public.effective_item_body(public.cohort_items) to authenticated;

create function public.effective_module_title(module_row public.cohort_modules)
returns text language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select cm.title from public.course_modules cm where cm.id = module_row.source_module_id),
    module_row.title
  )
$$;
revoke all on function public.effective_module_title(public.cohort_modules) from public;
grant execute on function public.effective_module_title(public.cohort_modules) to authenticated;

create function public.effective_module_description(module_row public.cohort_modules)
returns text language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select cm.description from public.course_modules cm where cm.id = module_row.source_module_id),
    module_row.description
  )
$$;
revoke all on function public.effective_module_description(public.cohort_modules) from public;
grant execute on function public.effective_module_description(public.cohort_modules) to authenticated;

-- RLS gate: a student must be able to read a cohort item whose EFFECTIVE
-- status is published, not just its stale copied column.
create or replace function public.student_can_read_item(target_item_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.cohort_items i join public.cohorts c on c.id=i.cohort_id
  join public.cohort_module_items p on p.item_id=i.id join public.cohort_modules m on m.id=p.module_id
  where i.id=target_item_id and public.effective_item_publication_status(i)='published' and c.status<>'draft'
    and public.is_active_student_in_cohort(c.id) and public.cohort_module_is_visible(m)) $$;

-- learningService.item() previously read cohort_items directly, which
-- returns the raw (possibly stale) copied columns even once RLS allows the
-- row through. This RPC returns the effective/live values instead, mirroring
-- the pattern already used for the outline.
create function public.get_student_cohort_item(target_cohort_id uuid, target_item_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
  if not public.student_can_read_item(target_item_id) then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'id',i.id,'cohortId',i.cohort_id,'kind',i.kind,
    'title',public.effective_item_title(i),'bodyMarkdown',public.effective_item_body(i),
    'publicationStatus',public.effective_item_publication_status(i),'dueAt',i.due_at
  ) into result from public.cohort_items i
  where i.id=target_item_id and i.cohort_id=target_cohort_id;
  if result is null then raise exception 'item not available'; end if;
  return result;
end $$;
revoke all on function public.get_student_cohort_item(uuid, uuid) from public;
grant execute on function public.get_student_cohort_item(uuid, uuid) to authenticated;

-- Teacher-facing equivalent: CohortEditorPage.vue reads cohort_modules and
-- cohort_items directly for its own module-release and due-date lists, so
-- it has the same staleness problem as the student view (minus the RLS
-- block, since a teacher can always read their own cohort's rows -- but the
-- displayed title/body would still be the stale copy).
create function public.get_teacher_cohort_content(target_cohort_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
  if not public.owns_cohort(target_cohort_id) then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'modules',coalesce((select jsonb_agg(jsonb_build_object(
      'id',m.id,'title',public.effective_module_title(m),'position',m.position,
      'releaseMode',m.release_mode,'releaseAt',m.release_at,'manuallyReleasedAt',m.manually_released_at
    ) order by m.position) from public.cohort_modules m where m.cohort_id=target_cohort_id),'[]'::jsonb),
    'items',coalesce((select jsonb_agg(jsonb_build_object(
      'id',i.id,'title',public.effective_item_title(i),'kind',i.kind,
      'publicationStatus',public.effective_item_publication_status(i),'dueAt',i.due_at
    )) from public.cohort_items i where i.cohort_id=target_cohort_id),'[]'::jsonb)
  ) into result;
  return result;
end $$;
revoke all on function public.get_teacher_cohort_content(uuid) from public;
grant execute on function public.get_teacher_cohort_content(uuid) to authenticated;

create or replace function public.get_student_cohort_outline(target_cohort_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
  if not public.is_active_student_in_cohort(target_cohort_id) then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'cohort',jsonb_build_object('id',c.id,'title',c.title,'courseId',c.course_id,'startDate',c.start_date,'endDate',c.end_date,'timezone',c.timezone,'introMarkdown',c.intro_markdown),
    'course',jsonb_build_object('title',course.title,'branding',course.branding_json),
    'modules',coalesce((select jsonb_agg(jsonb_build_object(
      'id',m.id,'title',public.effective_module_title(m),'description',public.effective_module_description(m),'position',m.position,
      'isVisible',public.cohort_module_is_visible(m),'releaseAt',m.release_at,
      'items',case when public.cohort_module_is_visible(m) then coalesce((select jsonb_agg(jsonb_build_object(
        'id',i.id,'title',public.effective_item_title(i),'kind',i.kind,'dueAt',i.due_at,'position',p.position
      ) order by p.position) from public.cohort_module_items p join public.cohort_items i on i.id=p.item_id
      where p.module_id=m.id and public.effective_item_publication_status(i)='published'),'[]'::jsonb) else '[]'::jsonb end
    ) order by m.position) from public.cohort_modules m where m.cohort_id=c.id),'[]'::jsonb)
  ) into result from public.cohorts c join public.courses course on course.id=c.course_id
  where c.id=target_cohort_id and c.status<>'draft';
  if result is null then raise exception 'cohort not available'; end if;
  return result;
end $$;
