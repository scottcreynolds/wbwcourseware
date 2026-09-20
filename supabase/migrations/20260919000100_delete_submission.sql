-- Lets a student delete their own submission or a teacher delete any
-- submission for a course they own. Deletion is a full hard delete of the
-- submissions/versions/files rows (no separate audit-of-record table exists
-- for submissions, unlike announcements), amending ADR-004's "immutable
-- version" statement with this explicit exception. Storage object cleanup
-- happens in the submission-delete Edge Function, which needs the returned
-- storage paths since there is no storage.objects RLS policy for this
-- bucket and only a service-role client can remove objects from it.
create function public.delete_submission(target_submission_id uuid)
returns table(storage_path text) language plpgsql security definer set search_path = ''
as $$
declare
  target_student_id uuid;
  target_course_id uuid;
begin
  if current_user not in ('service_role', 'postgres') then raise exception 'service role required'; end if;
  select s.student_id, i.course_id into target_student_id, target_course_id
  from public.submissions s
  join public.course_items i on i.id = s.course_item_id
  where s.id = target_submission_id
  for update of s;
  if not found then raise exception 'submission not found'; end if;

  return query
  delete from public.submission_files
  where version_id in (select id from public.submission_versions where submission_id = target_submission_id)
  returning submission_files.storage_path;

  delete from public.submission_versions where submission_id = target_submission_id;
  delete from public.submissions where id = target_submission_id;
end $$;
revoke all on function public.delete_submission(uuid) from public, anon, authenticated;
grant execute on function public.delete_submission(uuid) to service_role;
