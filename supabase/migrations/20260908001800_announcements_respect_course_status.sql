-- "student reads published announcements" only checked enrollment status
-- and the announcement's own published state, never courses.status -- so
-- a published announcement on a still-draft course was readable by an
-- enrolled student even though every other student-facing read path
-- (course row, outline, module/item visibility) requires status<>'draft'.
drop policy if exists "student reads published announcements" on public.announcements;
create policy "student reads published announcements" on public.announcements for select to authenticated
using(
  status = 'published'
  and public.is_active_student_in_course(course_id)
  and exists(select 1 from public.courses c where c.id = announcements.course_id and c.status <> 'draft')
);
