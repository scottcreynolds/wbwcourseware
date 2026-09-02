create type public.app_role as enum ('teacher', 'student');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email_normalized text not null,
  display_name text,
  role public.app_role not null default 'student',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_email_normalized_lowercase
    check (email_normalized = lower(btrim(email_normalized))),
  constraint profiles_email_normalized_nonempty
    check (length(email_normalized) > 0)
);

create unique index profiles_email_normalized_unique
  on public.profiles (email_normalized);

create unique index profiles_single_teacher_unique
  on public.profiles ((role))
  where role = 'teacher';

alter table public.profiles enable row level security;
alter table public.profiles force row level security;

create policy "users can read their own profile"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is null or length(btrim(new.email)) = 0 then
    raise exception 'An email address is required';
  end if;

  insert into public.profiles (id, email_normalized, display_name, role)
  values (
    new.id,
    lower(btrim(new.email)),
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), ''),
    'student'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_updated_at() from public;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

grant select on public.profiles to authenticated;
revoke insert, update, delete on public.profiles from anon, authenticated;

comment on table public.profiles is
  'Application identity. Global role is server-managed and never client-writable.';

