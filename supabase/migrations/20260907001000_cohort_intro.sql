alter table public.cohorts
  add column intro_markdown text not null default '' check (length(intro_markdown) <= 1000000);

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
