-- delete_submission (20260919000100_delete_submission.sql) hard-deletes a
-- submission's versions/files but never touched teacher_notifications.
-- teacher_notifications.source_id is a bare uuid (see
-- 20260914000200_teacher_notifications.sql) with no FK to
-- submission_versions, so nothing cascaded on its own -- a deleted
-- submission could leave an orphaned notification row: a still-pending one
-- would dispatch later and 404 inside notify-teacher when it looks up the
-- now-gone version, and an already-sent one would keep linking the teacher
-- to a submission that no longer exists. Redefine the function to remove
-- any notification for the versions it deletes, regardless of status.
create or replace function public.delete_submission(target_submission_id uuid)
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

  delete from public.teacher_notifications
  where kind = 'submission'
    and source_id in (select id from public.submission_versions where submission_id = target_submission_id);

  return query
  delete from public.submission_files
  where version_id in (select id from public.submission_versions where submission_id = target_submission_id)
  returning submission_files.storage_path;

  delete from public.submission_versions where submission_id = target_submission_id;
  delete from public.submissions where id = target_submission_id;
end $$;
revoke all on function public.delete_submission(uuid) from public, anon, authenticated;
grant execute on function public.delete_submission(uuid) to service_role;

-- service_role's privileges on this table are otherwise kept accurate to
-- what it is expected to do (see the grant comment in
-- 20260914000200_teacher_notifications.sql) rather than relying solely on
-- delete_submission's ownership to bypass the ACL.
grant delete on public.teacher_notifications to service_role;
