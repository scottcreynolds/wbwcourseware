create table public.submissions(
  id uuid primary key default gen_random_uuid(),
  cohort_item_id uuid not null references public.cohort_items(id) on delete restrict,
  student_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(cohort_item_id, student_id)
);

create table public.submission_versions(
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions(id) on delete restrict,
  version_number integer not null check(version_number > 0),
  submitted_at timestamptz not null default now(),
  is_late boolean not null,
  unique(submission_id, version_number)
);

create table public.submission_files(
  id uuid primary key default gen_random_uuid(),
  version_id uuid not null references public.submission_versions(id) on delete restrict,
  storage_path text not null unique,
  original_name text not null,
  mime_type text not null check(mime_type = 'application/pdf'),
  byte_size bigint not null check(byte_size between 1 and 26214400),
  checksum text,
  created_at timestamptz not null default now()
);

create trigger submissions_set_updated_at before update on public.submissions
for each row execute function public.set_updated_at();

alter table public.submissions enable row level security;
alter table public.submission_versions enable row level security;
alter table public.submission_files enable row level security;

create function public.can_read_submission(target_submission_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(
    select 1 from public.submissions s
    join public.cohort_items i on i.id = s.cohort_item_id
    where s.id = target_submission_id
      and (public.owns_cohort(i.cohort_id) or public.is_active_student_in_cohort(i.cohort_id))
  )
$$;
revoke all on function public.can_read_submission(uuid) from public;
grant execute on function public.can_read_submission(uuid) to authenticated;

create policy "cohort reads submissions" on public.submissions for select to authenticated
using(public.can_read_submission(id));
create policy "cohort reads submission versions" on public.submission_versions for select to authenticated
using(public.can_read_submission(submission_id));
create policy "cohort reads submission files" on public.submission_files for select to authenticated
using(exists(
  select 1 from public.submission_versions v
  where v.id = submission_files.version_id and public.can_read_submission(v.submission_id)
));

grant select on public.submissions, public.submission_versions, public.submission_files to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values('submissions', 'submissions', false, 26214400, array['application/pdf'])
on conflict(id) do update set public = false, file_size_limit = 26214400,
allowed_mime_types = array['application/pdf'];

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
  select due_at into target_due_at from public.cohort_items
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

  insert into public.submissions(cohort_item_id, student_id)
  values(target_item_id, target_student_id)
  on conflict(cohort_item_id, student_id) do update set updated_at = now()
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
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', s.id,
    'studentId', s.student_id,
    'studentName', coalesce(p.display_name, 'Student'),
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
      from public.submission_versions v where v.submission_id = s.id
    )
  ) order by coalesce(p.display_name, 'Student')), '[]'::jsonb)
  from public.submissions s
  join public.cohort_items i on i.id = s.cohort_item_id
  join public.profiles p on p.id = s.student_id
  where s.cohort_item_id = target_item_id
    and (public.owns_cohort(i.cohort_id) or public.is_active_student_in_cohort(i.cohort_id))
$$;
revoke all on function public.get_assignment_submissions(uuid) from public;
grant execute on function public.get_assignment_submissions(uuid) to authenticated;

create index submissions_item_idx on public.submissions(cohort_item_id);
create index submission_versions_submission_idx on public.submission_versions(submission_id, version_number desc);
create index submission_files_version_idx on public.submission_files(version_id);
