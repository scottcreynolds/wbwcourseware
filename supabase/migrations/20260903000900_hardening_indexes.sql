create index if not exists cohorts_teacher_status_idx on public.cohorts(teacher_id, status);
create index if not exists cohort_modules_release_idx on public.cohort_modules(cohort_id, release_mode, release_at);
create index if not exists cohort_items_due_idx on public.cohort_items(cohort_id, due_at) where kind = 'assignment';
create index if not exists cohort_enrollments_active_idx on public.cohort_enrollments(cohort_id, student_id) where status = 'active';
create index if not exists cohort_invitations_teacher_rate_idx on public.cohort_invitations(invited_by, created_at desc);

revoke all on function public.protect_discussion_identity() from public;
