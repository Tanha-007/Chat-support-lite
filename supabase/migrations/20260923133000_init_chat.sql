-- Chat Support Lite: threads, participants, messages + RLS
create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null check (role in ('learner', 'mentor')),
  created_at timestamptz not null default now()
);

create table if not exists public.threads (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.thread_participants (
  thread_id uuid not null references public.threads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint messages_body_length check (char_length(body) between 1 and 500)
);

create index if not exists messages_thread_created_idx
  on public.messages (thread_id, created_at asc);
create index if not exists thread_participants_user_idx
  on public.thread_participants (user_id);
create index if not exists threads_updated_at_idx
  on public.threads (updated_at desc);

create or replace function public.is_thread_participant(tid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.thread_participants tp
    where tp.thread_id = tid and tp.user_id = auth.uid()
  );
$$;

create or replace function public.touch_thread_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.threads set updated_at = now() where id = new.thread_id;
  return new;
end;
$$;

drop trigger if exists messages_touch_thread on public.messages;
create trigger messages_touch_thread
  after insert on public.messages
  for each row execute function public.touch_thread_updated_at();

alter table public.profiles enable row level security;
alter table public.threads enable row level security;
alter table public.thread_participants enable row level security;
alter table public.messages enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles for select to authenticated using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "threads_select_participant" on public.threads;
create policy "threads_select_participant"
  on public.threads for select to authenticated
  using (public.is_thread_participant(id));

drop policy if exists "participants_select_own_threads" on public.thread_participants;
create policy "participants_select_own_threads"
  on public.thread_participants for select to authenticated
  using (public.is_thread_participant(thread_id));

drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant"
  on public.messages for select to authenticated
  using (public.is_thread_participant(thread_id));

drop policy if exists "messages_insert_participant" on public.messages;
create policy "messages_insert_participant"
  on public.messages for insert to authenticated
  with check (
    auth.uid() = sender_id
    and public.is_thread_participant(thread_id)
    and char_length(body) between 1 and 500
  );

grant select, update on public.profiles to authenticated;
grant select on public.threads to authenticated;
grant select on public.thread_participants to authenticated;
grant select, insert on public.messages to authenticated;

alter table public.thread_participants
  drop constraint if exists thread_participants_user_id_profiles_fkey;
alter table public.thread_participants
  add constraint thread_participants_user_id_profiles_fkey
  foreign key (user_id) references public.profiles(id) on delete cascade;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
