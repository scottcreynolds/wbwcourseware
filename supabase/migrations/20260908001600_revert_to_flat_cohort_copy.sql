-- The "live view" model (cohort content resolved from the linked course row
-- at read time) turned out to be the wrong direction entirely: it added a
-- sync/effective-resolution layer that kept breaking (stale RLS gates,
-- placement position collisions on sync) for a use case that doesn't need
-- to exist. The actual model wanted is simpler: a cohort is a fully
-- self-contained, independent COPY of a course, made once at creation via
-- create_cohort_from_course (already exists, unchanged). There is no
-- "sync" or "live" concept at all -- if a teacher wants a cohort to pick up
-- later course changes, they create a new cohort.
--
-- This migration removes every piece of the sync/live-resolution machinery
-- added across the last few migrations and restores direct reads of the
-- cohort's own columns. No cohort_modules/cohort_items rows are touched --
-- whatever content a cohort currently has (whether from the original
-- snapshot or from a since-removed sync run) simply becomes its permanent,
-- independent content going forward, which is exactly correct under this
-- model.

drop function if exists public.get_teacher_cohort_content(uuid);
drop function if exists public.get_student_cohort_item(uuid, uuid);
drop function if exists public.sync_new_course_content_to_cohorts(uuid, uuid[]);
drop function if exists public.sync_course_item_to_cohorts(uuid, uuid[]);

create or replace function public.student_can_read_item(target_item_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.cohort_items i join public.cohorts c on c.id=i.cohort_id
  join public.cohort_module_items p on p.item_id=i.id join public.cohort_modules m on m.id=p.module_id
  where i.id=target_item_id and i.publication_status='published' and c.status<>'draft'
    and public.is_active_student_in_cohort(c.id) and public.cohort_module_is_visible(m)) $$;

drop function if exists public.effective_item_publication_status(public.cohort_items);
drop function if exists public.effective_item_title(public.cohort_items);
drop function if exists public.effective_item_body(public.cohort_items);
drop function if exists public.effective_module_title(public.cohort_modules);
drop function if exists public.effective_module_description(public.cohort_modules);

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
      'id',m.id,'title',m.title,'description',m.description,'position',m.position,
      'isVisible',public.cohort_module_is_visible(m),'releaseAt',m.release_at,
      'items',case when public.cohort_module_is_visible(m) then coalesce((select jsonb_agg(jsonb_build_object(
        'id',i.id,'title',i.title,'kind',i.kind,'dueAt',i.due_at,'position',p.position
      ) order by p.position) from public.cohort_module_items p join public.cohort_items i on i.id=p.item_id
      where p.module_id=m.id and i.publication_status='published'),'[]'::jsonb) else '[]'::jsonb end
    ) order by m.position) from public.cohort_modules m where m.cohort_id=c.id),'[]'::jsonb)
  ) into result from public.cohorts c join public.courses course on course.id=c.course_id
  where c.id=target_cohort_id and c.status<>'draft';
  if result is null then raise exception 'cohort not available'; end if;
  return result;
end $$;
