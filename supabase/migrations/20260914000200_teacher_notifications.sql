-- Teacher email notifications for two student-initiated events: a new
-- top-level discussion topic, and an assignment submission. Both events can
-- happen while the teacher's own client is closed, so the trigger must be
-- server-initiated rather than dependent on any client call after the fact.
--
-- Outbox pattern (matches announcement_deliveries): a trusted write inserts a
-- pending row here, then a dedicated trigger fires an async HTTP call via
-- pg_net to the notify-teacher Edge Function, which sends the email via
-- Resend and records delivery status back onto the row. pg_net and Vault are
-- new dependencies for this codebase; they are the standard Supabase-provided
-- mechanism for calling an Edge Function from a database trigger without
-- hardcoding secrets into migration SQL.
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault;

create table public.teacher_notifications(
  id uuid primary key default gen_random_uuid(),
  kind text not null check(kind in ('discussion_topic', 'submission')),
  course_id uuid not null references public.courses(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id) on delete restrict,
  source_id uuid not null,
  status public.delivery_status not null default 'pending',
  provider_message_id text,
  attempt_count integer not null default 0 check(attempt_count >= 0),
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(kind, source_id)
);

create trigger teacher_notifications_set_updated_at before update on public.teacher_notifications
for each row execute function public.set_updated_at();

alter table public.teacher_notifications enable row level security;

create policy "teacher reads own notifications" on public.teacher_notifications for select to authenticated
using(teacher_id = (select auth.uid()));

-- Supabase's default privileges grant anon/authenticated full DML on new
-- public tables; revoke everything first so RLS is a second layer rather
-- than the only thing preventing writes, matching the read-only contract.
-- service_role needs full access since notify-teacher (running as
-- service_role) both reads and updates delivery status on this table.
revoke all on public.teacher_notifications from anon, authenticated;
grant select on public.teacher_notifications to authenticated;
grant select, update on public.teacher_notifications to service_role;

-- This project's default privileges (see the two conflicting `alter default
-- privileges` entries left by the base Supabase image vs. this project's own
-- migrations, both owned differently) leave service_role with no direct
-- SELECT on any application table -- every existing trusted RPC works around
-- this by running `security definer` as the function owner rather than by
-- querying tables directly as service_role. notify-teacher is a genuine new
-- case: an HTTP-triggered function (not a caller-authenticated RPC) that
-- must read plain tables directly as service_role. Grant only what it reads.
grant select on public.profiles, public.courses, public.discussion_topics to service_role;
grant select on public.submission_versions, public.submissions, public.course_items to service_role;

create index teacher_notifications_status_idx on public.teacher_notifications(status);
create index teacher_notifications_course_idx on public.teacher_notifications(course_id, created_at desc);

-- Queue a notification for a new student-authored discussion topic. Runs
-- security definer so it can read the owning teacher regardless of the
-- inserting student's RLS visibility, and is defensive about excluding the
-- teacher's own posts even though role='student' already implies that under
-- the current single-teacher constraint.
create function public.notify_teacher_of_discussion_topic()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare target_teacher_id uuid; author_role text;
begin
  select role into author_role from public.profiles where id = new.author_id;
  if author_role <> 'student' then return new; end if;
  select teacher_id into target_teacher_id from public.courses where id = new.course_id;
  if target_teacher_id is null or target_teacher_id = new.author_id then return new; end if;
  insert into public.teacher_notifications(kind, course_id, teacher_id, source_id)
  values('discussion_topic', new.course_id, target_teacher_id, new.id)
  on conflict(kind, source_id) do nothing;
  return new;
end $$;
revoke all on function public.notify_teacher_of_discussion_topic() from public, anon, authenticated;

create trigger notify_teacher_after_discussion_topic after insert on public.discussion_topics
for each row execute function public.notify_teacher_of_discussion_topic();

-- Dispatch a pending notification to the notify-teacher Edge Function via
-- pg_net. Reads the function base URL and service-role key from Vault rather
-- than embedding either in migration SQL. If either secret is missing (e.g.
-- a fresh environment before one-time Vault provisioning), the row is left
-- pending rather than failing the insert transaction -- it stays visible to
-- the teacher via the select policy above and can be redispatched manually.
create function public.dispatch_teacher_notification()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare function_url text; service_key text;
begin
  select decrypted_secret into function_url from vault.decrypted_secrets where name = 'notify_teacher_function_url';
  select decrypted_secret into service_key from vault.decrypted_secrets where name = 'notify_teacher_service_key';
  if function_url is null or service_key is null then return new; end if;
  perform net.http_post(
    url := function_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || service_key),
    body := jsonb_build_object('notificationId', new.id)
  );
  return new;
end $$;
revoke all on function public.dispatch_teacher_notification() from public, anon, authenticated;

create trigger dispatch_teacher_notification_after_insert after insert on public.teacher_notifications
for each row execute function public.dispatch_teacher_notification();

-- finalize_submission already runs security definer as service_role and has
-- every id needed in scope; queue the notification there rather than adding
-- a table trigger on submission_versions, since this is already the one
-- trusted choke point for every submission path.
create or replace function public.finalize_submission(
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
  target_course_id uuid;
  target_teacher_id uuid;
  file_record jsonb;
  object_record record;
  expected_prefix text := target_student_id::text || '/' || target_item_id::text || '/';
begin
  if current_user not in ('service_role', 'postgres') then raise exception 'service role required'; end if;
  if jsonb_typeof(uploaded_files) <> 'array' or jsonb_array_length(uploaded_files) < 1 then
    raise exception 'at least one file required';
  end if;
  select due_at, course_id into target_due_at, target_course_id from public.course_items
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

  select teacher_id into target_teacher_id from public.courses where id = target_course_id;
  if target_teacher_id is not null then
    insert into public.teacher_notifications(kind, course_id, teacher_id, source_id)
    values('submission', target_course_id, target_teacher_id, target_version_id)
    on conflict(kind, source_id) do nothing;
  end if;

  return target_version_id;
end $$;
revoke all on function public.finalize_submission(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.finalize_submission(uuid, uuid, jsonb) to service_role;
