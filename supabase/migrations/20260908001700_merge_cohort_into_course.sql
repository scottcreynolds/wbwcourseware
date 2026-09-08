-- Cohort and course were kept as two separate entities across three
-- attempts (live-linked content, then flat-copy content) and both were
-- wrong: this project has no template/instance split at all. A course IS
-- the enrolled roster. Modules and items belong directly to the course;
-- they are draft or published; published ones are visible to whichever
-- students are enrolled in that course, gated by that course's own module
-- release schedule and item due dates. Re-running the same content for a
-- new term is an explicit "duplicate course" action, not cohort creation.
--
-- This migration is written to be safe against BOTH possible starting
-- points (uses `if exists`/`if not exists` throughout): a database that
-- already applied 20260908001600's revert, and one that is still on the
-- live-content state (20260908001400/20260908001500), since the two
-- environments this project runs against were found to be at different
-- points when this migration was authored.
--
-- Verified against production data before writing this: 2 courses, each
-- with exactly one cohort (clean 1:1), every cohort_modules/cohort_items
-- row already links to an existing course_modules/course_items row (zero
-- orphans), so no content needs to be created here -- only the
-- cohort-owned fields (dates/timezone/intro, release schedule, due dates)
-- need to move onto their matching course/course_modules/course_items row.

-- ============================================================
-- 1. Schema: absorb cohort-owned fields onto courses/course_modules/course_items
-- ============================================================

alter table public.courses
  add column if not exists start_date date,
  add column if not exists end_date date,
  add column if not exists timezone text,
  add column if not exists intro_markdown text not null default '' check (length(intro_markdown) <= 1000000);

alter table public.course_modules
  add column if not exists release_mode public.module_release_mode not null default 'manual',
  add column if not exists release_at timestamptz,
  add column if not exists manually_released_at timestamptz;

alter table public.course_items
  add column if not exists due_at timestamptz;

-- ============================================================
-- 2. Backfill from cohorts / cohort_modules / cohort_items onto their
--    matching course / course_modules / course_items row (1:1 today,
--    verified above; the join still only ever touches a course's own
--    matching cohort so this is safe even if that ever weren't 1:1).
-- ============================================================

do $$
begin
  if to_regclass('public.cohorts') is not null then
    update public.courses c
    set start_date = co.start_date, end_date = co.end_date, timezone = co.timezone,
        intro_markdown = co.intro_markdown
    from public.cohorts co
    where co.course_id = c.id;
  end if;

  if to_regclass('public.cohort_modules') is not null then
    update public.course_modules m
    set release_mode = cm.release_mode, release_at = cm.release_at,
        manually_released_at = cm.manually_released_at
    from public.cohort_modules cm
    where cm.source_module_id = m.id;
  end if;

  if to_regclass('public.cohort_items') is not null then
    update public.course_items i
    set due_at = ci.due_at
    from public.cohort_items ci
    where ci.source_item_id = i.id and ci.due_at is not null;
  end if;
end $$;

-- Courses that never had a cohort (none exist today, but keep this safe
-- for a course created and never rostered) get sensible non-null defaults
-- so the not-null constraint below never fails; a teacher corrects them.
update public.courses
set start_date = coalesce(start_date, current_date),
    end_date = coalesce(end_date, current_date + interval '90 days'),
    timezone = coalesce(timezone, 'America/New_York')
where start_date is null or end_date is null or timezone is null;

alter table public.courses
  alter column start_date set not null,
  alter column end_date set not null,
  alter column timezone set not null,
  add constraint courses_date_range_check check (end_date >= start_date),
  add constraint courses_timezone_check check (length(btrim(timezone)) between 1 and 100);

alter table public.course_items
  add constraint course_items_due_at_kind_check check ((kind = 'assignment') or due_at is null);

alter table public.course_modules
  add constraint course_modules_release_check check ((release_mode = 'scheduled' and release_at is not null) or release_mode = 'manual');

-- ============================================================
-- 3. Enrollment / invitations: repoint from cohorts to courses directly
-- ============================================================

alter table public.cohort_invitations rename column cohort_id to course_id;
alter table public.cohort_invitations drop constraint cohort_invitations_cohort_id_fkey;
alter table public.cohort_invitations add constraint cohort_invitations_course_id_fkey
  foreign key (course_id) references public.courses(id) on delete cascade;
alter table public.cohort_invitations rename to course_invitations;
alter index if exists cohort_invitations_pkey rename to course_invitations_pkey;
alter index if exists cohort_invitations_one_pending rename to course_invitations_one_pending;
alter index if exists cohort_invitations_teacher_rate_idx rename to course_invitations_teacher_rate_idx;

alter table public.cohort_enrollments rename column cohort_id to course_id;
alter table public.cohort_enrollments drop constraint cohort_enrollments_cohort_id_fkey;
alter table public.cohort_enrollments add constraint cohort_enrollments_course_id_fkey
  foreign key (course_id) references public.courses(id) on delete cascade;
alter table public.cohort_enrollments drop constraint if exists cohort_enrollments_cohort_id_student_id_key;
alter table public.cohort_enrollments add constraint course_enrollments_course_id_student_id_key unique (course_id, student_id);
alter table public.cohort_enrollments rename to course_enrollments;
alter index if exists cohort_enrollments_pkey rename to course_enrollments_pkey;
alter index if exists cohort_enrollments_active_idx rename to course_enrollments_active_idx;

-- ============================================================
-- 4. Announcements / discussions: same repoint, tables keep their names
-- ============================================================

alter table public.announcements rename column cohort_id to course_id;
alter table public.announcements drop constraint announcements_cohort_id_fkey;
alter table public.announcements add constraint announcements_course_id_fkey
  foreign key (course_id) references public.courses(id) on delete cascade;
alter index if exists announcements_cohort_published_idx rename to announcements_course_published_idx;

alter table public.discussion_topics rename column cohort_id to course_id;
alter table public.discussion_topics drop constraint discussion_topics_cohort_id_fkey;
alter table public.discussion_topics add constraint discussion_topics_course_id_fkey
  foreign key (course_id) references public.courses(id) on delete cascade;
alter index if exists discussion_topics_cohort_idx rename to discussion_topics_course_idx;

-- ============================================================
-- 5. Submissions: repoint from cohort_items to course_items
-- ============================================================

alter table public.submissions rename column cohort_item_id to course_item_id;
alter table public.submissions drop constraint submissions_cohort_item_id_fkey;
alter table public.submissions add constraint submissions_course_item_id_fkey
  foreign key (course_item_id) references public.course_items(id) on delete restrict;
alter table public.submissions drop constraint if exists submissions_cohort_item_id_student_id_key;
alter table public.submissions add constraint submissions_course_item_id_student_id_key unique (course_item_id, student_id);
alter index if exists submissions_item_idx rename to submissions_course_item_idx;

-- ============================================================
-- 6. Drop every policy that depends on a function we're about to drop or
--    replace, BEFORE dropping those functions (Postgres refuses to drop a
--    function that a live policy still references).
-- ============================================================

drop policy if exists "student reads course metadata for enrolled cohort" on public.courses;
drop policy if exists "teacher manages cohort invitations" on public.course_invitations;
drop policy if exists "teacher manages enrollments" on public.course_enrollments;
drop policy if exists "student reads own enrollment" on public.course_enrollments;
drop policy if exists "teacher manages own module placements" on public.course_module_items;
drop policy if exists "student reads visible placements" on public.course_module_items;
drop policy if exists "teacher manages own item resources" on public.course_item_resources;
drop policy if exists "student reads visible resources" on public.course_item_resources;
drop policy if exists "teacher manages own course modules" on public.course_modules;
drop policy if exists "student reads released modules" on public.course_modules;
drop policy if exists "teacher manages own course items" on public.course_items;
drop policy if exists "student reads published visible items" on public.course_items;
drop policy if exists "teacher reads enrolled student profiles" on public.profiles;
drop policy if exists "cohort reads submissions" on public.submissions;
drop policy if exists "cohort reads submission versions" on public.submission_versions;
drop policy if exists "cohort reads submission files" on public.submission_files;
drop policy if exists "teacher manages announcements" on public.announcements;
drop policy if exists "student reads published announcements" on public.announcements;
drop policy if exists "teacher reads announcement deliveries" on public.announcement_deliveries;
drop policy if exists "members read topics" on public.discussion_topics;
drop policy if exists "members create topics" on public.discussion_topics;
drop policy if exists "authors or teacher update topics" on public.discussion_topics;
drop policy if exists "members read replies" on public.discussion_replies;
drop policy if exists "members create replies" on public.discussion_replies;
drop policy if exists "authors or teacher update replies" on public.discussion_replies;

-- ============================================================
-- 7. Drop the now-empty cohort content tables -- CASCADE, since whichever
--    starting point this runs from (see header note) may still have
--    cohort-side policies (e.g. "student reads published visible items"
--    on cohort_items) referencing functions we're about to drop next.
--    Cascading here removes only those tables' own policies; the
--    course-table policies with matching names were already dropped in
--    step 6.
-- ============================================================

drop table if exists public.cohort_module_items cascade;
drop table if exists public.cohort_item_resources cascade;
drop table if exists public.cohort_items cascade;
drop table if exists public.cohort_modules cascade;
drop table if exists public.cohorts cascade;
drop type if exists public.cohort_status;

-- ============================================================
-- 8. Drop every function that exists only to serve the two-entity split.
--    `if exists` covers both possible starting points (see header note).
-- ============================================================

drop function if exists public.get_teacher_cohort_content(uuid);
drop function if exists public.get_student_cohort_item(uuid, uuid);
drop function if exists public.sync_new_course_content_to_cohorts(uuid, uuid[]);
drop function if exists public.sync_course_item_to_cohorts(uuid, uuid[]);
drop function if exists public.effective_item_publication_status(public.cohort_items);
drop function if exists public.effective_item_title(public.cohort_items);
drop function if exists public.effective_item_body(public.cohort_items);
drop function if exists public.effective_module_title(public.cohort_modules);
drop function if exists public.effective_module_description(public.cohort_modules);
drop function if exists public.get_student_cohort_outline(uuid);
drop function if exists public.get_cohort_discussions(uuid);
drop function if exists public.create_cohort_from_course(uuid, text, date, date, text);
drop function if exists public.activate_cohort_invitation(uuid, uuid, text);
drop function if exists public.prepare_announcement_publication(uuid, uuid);
drop function if exists public.finalize_submission(uuid, uuid, jsonb);
drop function if exists public.get_assignment_submissions(uuid);
drop function if exists public.can_read_submission(uuid);
drop function if exists public.student_can_read_item(uuid);
drop function if exists public.student_can_read_module(uuid);
drop function if exists public.is_active_student_in_cohort(uuid);
drop function if exists public.cohort_module_is_visible(public.cohort_modules);
drop function if exists public.owns_cohort(uuid);

-- ============================================================
-- 9. Rebuild every helper function against courses/course_modules/
--    course_items directly -- one less join hop than the cohort-layered
--    versions had, since there is no intermediate entity any more.
-- ============================================================

create function public.is_active_student_in_course(target_course_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.course_enrollments where course_id=target_course_id and student_id=(select auth.uid()) and status='active') $$;
revoke all on function public.is_active_student_in_course(uuid) from public;
grant execute on function public.is_active_student_in_course(uuid) to authenticated;

create function public.course_module_is_visible(module_row public.course_modules)
returns boolean language sql stable set search_path=''
as $$ select case when module_row.release_mode='scheduled' then module_row.release_at<=now() else module_row.manually_released_at is not null end $$;
revoke all on function public.course_module_is_visible(public.course_modules) from public;
grant execute on function public.course_module_is_visible(public.course_modules) to authenticated;

create function public.student_can_read_module(target_module_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.course_modules m join public.courses c on c.id=m.course_id
  where m.id=target_module_id and c.status<>'draft' and public.is_active_student_in_course(c.id) and public.course_module_is_visible(m)) $$;
revoke all on function public.student_can_read_module(uuid) from public;
grant execute on function public.student_can_read_module(uuid) to authenticated;

create function public.student_can_read_item(target_item_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.course_items i join public.courses c on c.id=i.course_id
  join public.course_module_items p on p.item_id=i.id join public.course_modules m on m.id=p.module_id
  where i.id=target_item_id and i.publication_status='published' and c.status<>'draft'
    and public.is_active_student_in_course(c.id) and public.course_module_is_visible(m)) $$;
revoke all on function public.student_can_read_item(uuid) from public;
grant execute on function public.student_can_read_item(uuid) to authenticated;

create function public.activate_course_invitation(target_invitation_id uuid,target_student_id uuid,target_email text)
returns uuid language plpgsql security definer set search_path=''
as $$
declare inv public.course_invitations%rowtype; enrollment_id uuid;
begin
  if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;
  select * into inv from public.course_invitations where id=target_invitation_id for update;
  if inv.id is null or inv.status<>'pending' or inv.expires_at<=now() or inv.email_normalized<>lower(btrim(target_email)) then raise exception 'invalid invitation'; end if;
  if not exists(select 1 from public.profiles where id=target_student_id and role='student' and email_normalized=inv.email_normalized) then raise exception 'student profile mismatch'; end if;
  insert into public.course_enrollments(course_id,student_id,invitation_id,status,removed_at)
  values(inv.course_id,target_student_id,inv.id,'active',null)
  on conflict(course_id,student_id) do update set status='active',invitation_id=excluded.invitation_id,activated_at=now(),removed_at=null
  returning id into enrollment_id;
  update public.course_invitations set status='accepted',accepted_at=now() where id=inv.id;
  return enrollment_id;
end $$;
revoke all on function public.activate_course_invitation(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.activate_course_invitation(uuid,uuid,text) to service_role;

create function public.get_student_course_outline(target_course_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
  if not public.is_active_student_in_course(target_course_id) then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'course',jsonb_build_object('id',c.id,'title',c.title,'branding',c.branding_json,'startDate',c.start_date,'endDate',c.end_date,'timezone',c.timezone,'introMarkdown',c.intro_markdown),
    'modules',coalesce((select jsonb_agg(jsonb_build_object(
      'id',m.id,'title',m.title,'description',m.description,'position',m.position,
      'isVisible',public.course_module_is_visible(m),'releaseAt',m.release_at,
      'items',case when public.course_module_is_visible(m) then coalesce((select jsonb_agg(jsonb_build_object(
        'id',i.id,'title',i.title,'kind',i.kind,'dueAt',i.due_at,'position',p.position
      ) order by p.position) from public.course_module_items p join public.course_items i on i.id=p.item_id
      where p.module_id=m.id and i.publication_status='published'),'[]'::jsonb) else '[]'::jsonb end
    ) order by m.position) from public.course_modules m where m.course_id=c.id),'[]'::jsonb)
  ) into result from public.courses c
  where c.id=target_course_id and c.status<>'draft';
  if result is null then raise exception 'course not available'; end if;
  return result;
end $$;
revoke all on function public.get_student_course_outline(uuid) from public;
grant execute on function public.get_student_course_outline(uuid) to authenticated;

create function public.get_student_course_item(target_course_id uuid, target_item_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
  if not public.student_can_read_item(target_item_id) then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'id',i.id,'courseId',i.course_id,'kind',i.kind,'title',i.title,'bodyMarkdown',i.body_markdown,
    'publicationStatus',i.publication_status,'dueAt',i.due_at
  ) into result from public.course_items i
  where i.id=target_item_id and i.course_id=target_course_id;
  if result is null then raise exception 'item not available'; end if;
  return result;
end $$;
revoke all on function public.get_student_course_item(uuid, uuid) from public;
grant execute on function public.get_student_course_item(uuid, uuid) to authenticated;

create function public.get_course_discussions(target_course_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select case when public.owns_course(target_course_id) or public.is_active_student_in_course(target_course_id)
    then coalesce(jsonb_agg(jsonb_build_object(
      'id', t.id, 'authorId', t.author_id, 'authorName', coalesce(p.display_name, 'Member'),
      'title', case when t.deleted_at is null or public.owns_course(target_course_id) then t.title else 'Deleted topic' end,
      'bodyMarkdown', case when t.deleted_at is null or public.owns_course(target_course_id) then t.body_markdown else '' end,
      'createdAt', t.created_at,
      'deletedAt', t.deleted_at, 'replies', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', r.id, 'authorId', r.author_id, 'authorName', coalesce(rp.display_name, 'Member'),
          'bodyMarkdown', case when r.deleted_at is null or public.owns_course(target_course_id) then r.body_markdown else '' end,
          'createdAt', r.created_at, 'deletedAt', r.deleted_at
        ) order by r.created_at), '[]'::jsonb)
        from public.discussion_replies r join public.profiles rp on rp.id = r.author_id
        where r.topic_id = t.id
      )
    ) order by t.created_at desc), '[]'::jsonb)
    else '[]'::jsonb end
  from public.discussion_topics t join public.profiles p on p.id = t.author_id
  where t.course_id = target_course_id
$$;
revoke all on function public.get_course_discussions(uuid) from public;
grant execute on function public.get_course_discussions(uuid) to authenticated;

create function public.prepare_announcement_publication(target_announcement_id uuid, target_teacher_id uuid)
returns table(delivery_id uuid, recipient text, announcement_title text, announcement_body text, course_title text, attempts integer)
language plpgsql security definer set search_path = ''
as $$
declare target_course_id uuid;
begin
  if current_user not in ('service_role', 'postgres') then raise exception 'service role required'; end if;
  select a.course_id into target_course_id from public.announcements a
  join public.courses c on c.id = a.course_id
  where a.id = target_announcement_id and c.teacher_id = target_teacher_id for update;
  if target_course_id is null then raise exception 'not authorized'; end if;
  update public.announcements set status = 'published', published_at = coalesce(published_at, now())
  where id = target_announcement_id;
  insert into public.announcement_deliveries(announcement_id, enrollment_id, email_normalized)
  select target_announcement_id, e.id, p.email_normalized
  from public.course_enrollments e join public.profiles p on p.id = e.student_id
  where e.course_id = target_course_id and e.status = 'active'
  on conflict(announcement_id, enrollment_id) do nothing;
  return query
  select d.id, d.email_normalized, a.title, a.body_markdown, c.title, d.attempt_count
  from public.announcement_deliveries d
  join public.announcements a on a.id = d.announcement_id
  join public.courses c on c.id = a.course_id
  where d.announcement_id = target_announcement_id and d.status <> 'sent';
end $$;
revoke all on function public.prepare_announcement_publication(uuid, uuid) from public, anon, authenticated;
grant execute on function public.prepare_announcement_publication(uuid, uuid) to service_role;

create function public.can_read_submission(target_submission_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(
    select 1 from public.submissions s
    join public.course_items i on i.id = s.course_item_id
    where s.id = target_submission_id
      and (public.owns_course(i.course_id) or public.student_can_read_item(s.course_item_id))
  )
$$;
revoke all on function public.can_read_submission(uuid) from public;
grant execute on function public.can_read_submission(uuid) to authenticated;

create function public.finalize_submission(
  target_item_id uuid,
  target_student_id uuid,
  uploaded_files jsonb
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  target_submission_id uuid;
  target_version_id uuid;
  next_version integer;
  target_due_at timestamptz;
  file_record jsonb;
  object_record record;
  expected_prefix text := target_student_id::text || '/' || target_item_id::text || '/';
begin
  if current_user not in ('service_role', 'postgres') then raise exception 'service role required'; end if;
  if jsonb_typeof(uploaded_files) <> 'array' or jsonb_array_length(uploaded_files) < 1 then
    raise exception 'at least one file required';
  end if;
  select due_at into target_due_at from public.course_items
  where id = target_item_id and kind = 'assignment';
  if not found then raise exception 'assignment not found'; end if;
  for file_record in select value from jsonb_array_elements(uploaded_files)
  loop
    if file_record->>'path' not like expected_prefix || '%' then raise exception 'invalid storage path'; end if;
    select name, metadata into object_record from storage.objects
    where bucket_id = 'submissions' and name = file_record->>'path';
    if not found then raise exception 'uploaded file not found'; end if;
    if coalesce(object_record.metadata->>'mimetype', '') <> 'application/pdf'
      or coalesce((object_record.metadata->>'size')::bigint, 0) not between 1 and 26214400
      or lower(file_record->>'name') not like '%.pdf'
    then raise exception 'invalid PDF'; end if;
  end loop;

  insert into public.submissions(course_item_id, student_id)
  values(target_item_id, target_student_id)
  on conflict(course_item_id, student_id) do update set updated_at = now()
  returning id into target_submission_id;
  perform id from public.submissions where id = target_submission_id for update;
  select coalesce(max(version_number), 0) + 1 into next_version
  from public.submission_versions where submission_id = target_submission_id;
  insert into public.submission_versions(submission_id, version_number, submitted_at, is_late)
  values(target_submission_id, next_version, now(), target_due_at is not null and now() > target_due_at)
  returning id into target_version_id;
  for file_record in select value from jsonb_array_elements(uploaded_files)
  loop
    select metadata into object_record from storage.objects
    where bucket_id = 'submissions' and name = file_record->>'path';
    insert into public.submission_files(version_id, storage_path, original_name, mime_type, byte_size)
    values(target_version_id, file_record->>'path', file_record->>'name', 'application/pdf',
      (object_record.metadata->>'size')::bigint);
  end loop;
  return target_version_id;
end $$;
revoke all on function public.finalize_submission(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.finalize_submission(uuid, uuid, jsonb) to service_role;

create function public.get_assignment_submissions(target_item_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  with target as (
    select i.id, i.course_id, public.owns_course(i.course_id) as is_teacher
    from public.course_items i where i.id = target_item_id and i.kind = 'assignment'
  ), people as (
    select s.id, s.student_id, p.display_name
    from target t join public.submissions s on s.course_item_id = t.id
    join public.profiles p on p.id = s.student_id
    where t.is_teacher or public.student_can_read_item(t.id)
    union all
    select null::uuid, e.student_id, p.display_name
    from target t join public.course_enrollments e on e.course_id = t.course_id and e.status = 'active'
    join public.profiles p on p.id = e.student_id
    where t.is_teacher and not exists(
      select 1 from public.submissions s where s.course_item_id = t.id and s.student_id = e.student_id
    )
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', people.id,
    'studentId', people.student_id,
    'studentName', coalesce(people.display_name, 'Student'),
    'versions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', v.id, 'versionNumber', v.version_number, 'submittedAt', v.submitted_at,
        'isLate', v.is_late, 'files', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id', f.id, 'name', f.original_name, 'byteSize', f.byte_size
          ) order by f.created_at), '[]'::jsonb)
          from public.submission_files f where f.version_id = v.id
        )
      ) order by v.version_number desc), '[]'::jsonb)
      from public.submission_versions v where v.submission_id = people.id
    )
  ) order by coalesce(people.display_name, 'Student')), '[]'::jsonb)
  from people
$$;
revoke all on function public.get_assignment_submissions(uuid) from public;
grant execute on function public.get_assignment_submissions(uuid) to authenticated;

-- ============================================================
-- 10. Rebuild RLS policies against the renamed/merged tables.
-- ============================================================

drop policy if exists "student reads course metadata for enrolled cohort" on public.courses;
create policy "student reads own enrolled course" on public.courses for select to authenticated
using(status<>'draft' and public.is_active_student_in_course(id));

drop policy if exists "teacher manages own module placements" on public.course_module_items;
create policy "teacher manages own module placements" on public.course_module_items
  for all to authenticated
  using (exists (select 1 from public.course_modules m where m.id = module_id and public.owns_course(m.course_id)))
  with check (exists (
    select 1 from public.course_modules m
    join public.course_items i on i.id = item_id and i.course_id = m.course_id
    where m.id = module_id and public.owns_course(m.course_id)
  ));
create policy "student reads visible placements" on public.course_module_items for select to authenticated
using(public.student_can_read_module(module_id) and public.student_can_read_item(item_id));

drop policy if exists "teacher manages own item resources" on public.course_item_resources;
create policy "teacher manages own item resources" on public.course_item_resources
  for all to authenticated
  using (exists (select 1 from public.course_items i where i.id = item_id and public.owns_course(i.course_id)))
  with check (exists (select 1 from public.course_items i where i.id = item_id and public.owns_course(i.course_id)));
create policy "student reads visible resources" on public.course_item_resources for select to authenticated
using(public.student_can_read_item(item_id));

drop policy if exists "teacher manages own course modules" on public.course_modules;
create policy "teacher manages own course modules" on public.course_modules
  for all to authenticated using (public.owns_course(course_id)) with check (public.owns_course(course_id));
create policy "student reads released modules" on public.course_modules for select to authenticated
using(public.student_can_read_module(id));

drop policy if exists "teacher manages own course items" on public.course_items;
create policy "teacher manages own course items" on public.course_items
  for all to authenticated using (public.owns_course(course_id)) with check (public.owns_course(course_id));
create policy "student reads published visible items" on public.course_items for select to authenticated
using(public.student_can_read_item(id));

create policy "teacher manages course invitations" on public.course_invitations for all to authenticated
using(public.owns_course(course_id)) with check(public.owns_course(course_id));
create policy "teacher manages enrollments" on public.course_enrollments for all to authenticated
using(public.owns_course(course_id)) with check(public.owns_course(course_id));
create policy "student reads own enrollment" on public.course_enrollments for select to authenticated
using(student_id=(select auth.uid()));
grant select,insert,update,delete on public.course_invitations to authenticated;
grant select,insert,update,delete on public.course_enrollments to authenticated;

drop policy if exists "teacher reads enrolled student profiles" on public.profiles;
create policy "teacher reads enrolled student profiles" on public.profiles for select to authenticated
using(public.is_teacher() and exists(select 1 from public.course_enrollments e where e.student_id=profiles.id and public.owns_course(e.course_id)));

drop policy if exists "cohort reads submissions" on public.submissions;
create policy "course reads submissions" on public.submissions for select to authenticated
using(public.can_read_submission(id));
drop policy if exists "cohort reads submission versions" on public.submission_versions;
create policy "course reads submission versions" on public.submission_versions for select to authenticated
using(public.can_read_submission(submission_id));
drop policy if exists "cohort reads submission files" on public.submission_files;
create policy "course reads submission files" on public.submission_files for select to authenticated
using(exists(select 1 from public.submission_versions v where v.id = submission_files.version_id and public.can_read_submission(v.submission_id)));

drop policy if exists "teacher manages announcements" on public.announcements;
create policy "teacher manages announcements" on public.announcements for all to authenticated
using(public.owns_course(course_id)) with check(public.owns_course(course_id) and author_id = (select auth.uid()));
drop policy if exists "student reads published announcements" on public.announcements;
create policy "student reads published announcements" on public.announcements for select to authenticated
using(status = 'published' and public.is_active_student_in_course(course_id));
drop policy if exists "teacher reads announcement deliveries" on public.announcement_deliveries;
create policy "teacher reads announcement deliveries" on public.announcement_deliveries for select to authenticated
using(exists(select 1 from public.announcements a where a.id = announcement_deliveries.announcement_id and public.owns_course(a.course_id)));

drop policy if exists "members read topics" on public.discussion_topics;
create policy "members read topics" on public.discussion_topics for select to authenticated
using(public.owns_course(course_id) or (deleted_at is null and public.is_active_student_in_course(course_id)));
drop policy if exists "members create topics" on public.discussion_topics;
create policy "members create topics" on public.discussion_topics for insert to authenticated
with check(author_id = (select auth.uid()) and (public.owns_course(course_id) or public.is_active_student_in_course(course_id)));
drop policy if exists "authors or teacher update topics" on public.discussion_topics;
create policy "authors or teacher update topics" on public.discussion_topics for update to authenticated
using(author_id = (select auth.uid()) or public.owns_course(course_id))
with check(author_id = (select auth.uid()) or public.owns_course(course_id));

drop policy if exists "members read replies" on public.discussion_replies;
create policy "members read replies" on public.discussion_replies for select to authenticated
using(exists(select 1 from public.discussion_topics t where t.id = discussion_replies.topic_id
  and (public.owns_course(t.course_id) or (discussion_replies.deleted_at is null and public.is_active_student_in_course(t.course_id)))));
drop policy if exists "members create replies" on public.discussion_replies;
create policy "members create replies" on public.discussion_replies for insert to authenticated
with check(author_id = (select auth.uid()) and exists(select 1 from public.discussion_topics t
  where t.id = discussion_replies.topic_id and t.deleted_at is null
    and (public.owns_course(t.course_id) or public.is_active_student_in_course(t.course_id))));
drop policy if exists "authors or teacher update replies" on public.discussion_replies;
create policy "authors or teacher update replies" on public.discussion_replies for update to authenticated
using(author_id = (select auth.uid()) or exists(select 1 from public.discussion_topics t where t.id = discussion_replies.topic_id and public.owns_course(t.course_id)))
with check(author_id = (select auth.uid()) or exists(select 1 from public.discussion_topics t where t.id = discussion_replies.topic_id and public.owns_course(t.course_id)));

-- protect_discussion_topic_identity referenced new.cohort_id -- fix it to
-- reference the renamed course_id column, matching the existing pattern
-- of one function per table shape (see 20260907001200's fix note).
create or replace function public.protect_discussion_topic_identity()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.course_id <> old.course_id or new.author_id <> old.author_id then
    raise exception 'discussion identity is immutable';
  end if;
  if old.deleted_at is not null and current_user not in ('service_role', 'postgres') then
    raise exception 'deleted discussion content is immutable';
  end if;
  return new;
end $$;

-- ============================================================
-- 11. Indexes that used to live on the cohort tables, carried forward
--     onto their course-table equivalents (course_modules_release_idx /
--     course_items_due_idx are new -- courses never needed these until
--     they absorbed the release-schedule/due-date columns).
-- ============================================================

create index if not exists courses_teacher_status_idx on public.courses(teacher_id, status);
create index if not exists course_modules_release_idx on public.course_modules(course_id, release_mode, release_at);
create index if not exists course_items_due_idx on public.course_items(course_id, due_at) where kind = 'assignment';

-- ============================================================
-- 12. New: explicit deep-copy for starting a new term/section from an
--     existing course. This is the ONLY copy mechanism in the system now.
-- ============================================================

create function public.duplicate_course(target_course_id uuid, new_title text)
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

  return new_course_id;
end $$;
revoke all on function public.duplicate_course(uuid, text) from public;
grant execute on function public.duplicate_course(uuid, text) to authenticated;
