-- Deskline v2
-- Onboarding profiles, learner-started conversations, inbox RPC, read receipts,
-- server-side abuse guards, report flow, and a moderation panel backend.
-- Safe to re-run.

-- ---------------------------------------------------------------------------
-- Profiles: moderator role, mentor headline, mute, directory listing
-- ---------------------------------------------------------------------------
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('learner', 'mentor', 'moderator'));

alter table public.profiles add column if not exists headline text;
alter table public.profiles add column if not exists muted_until timestamptz;
alter table public.profiles add column if not exists listed boolean not null default true;

alter table public.profiles drop constraint if exists profiles_display_name_len;
alter table public.profiles
  add constraint profiles_display_name_len
  check (char_length(btrim(display_name)) between 2 and 40);

alter table public.profiles drop constraint if exists profiles_headline_len;
alter table public.profiles
  add constraint profiles_headline_len
  check (headline is null or char_length(headline) <= 80);

-- Every new auth user gets a learner profile. Roles above learner are granted by SQL only.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  v_name := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  if char_length(v_name) < 2 then
    v_name := initcap(split_part(coalesce(new.email, ''), '@', 1));
  end if;
  v_name := left(v_name, 40);
  if char_length(btrim(v_name)) < 2 then
    v_name := 'Member';
  end if;

  insert into public.profiles (id, display_name, role)
  values (new.id, v_name, 'learner')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

insert into public.profiles (id, display_name, role)
select
  u.id,
  case
    when char_length(split_part(coalesce(u.email, ''), '@', 1)) >= 2
      then left(initcap(split_part(u.email, '@', 1)), 40)
    else 'Member'
  end,
  'learner'
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'moderator'
  );
$$;

-- ---------------------------------------------------------------------------
-- Threads: status + creator; participants: read receipts
-- ---------------------------------------------------------------------------
alter table public.threads add column if not exists status text not null default 'open';
alter table public.threads drop constraint if exists threads_status_check;
alter table public.threads
  add constraint threads_status_check check (status in ('open', 'resolved'));

alter table public.threads
  add column if not exists created_by uuid references public.profiles(id) on delete set null;

alter table public.threads drop constraint if exists threads_title_len;
alter table public.threads
  add constraint threads_title_len check (char_length(btrim(title)) between 3 and 80);

alter table public.thread_participants
  add column if not exists last_read_at timestamptz not null default now();

create index if not exists threads_created_by_idx
  on public.threads (created_by, created_at desc);

-- ---------------------------------------------------------------------------
-- Messages: moderation fields, blank guard, rate limits
-- ---------------------------------------------------------------------------
alter table public.messages add column if not exists hidden_at timestamptz;
alter table public.messages
  add column if not exists hidden_by uuid references public.profiles(id) on delete set null;

alter table public.messages drop constraint if exists messages_body_not_blank;
alter table public.messages
  add constraint messages_body_not_blank check (btrim(body) <> '');

create index if not exists messages_sender_created_idx
  on public.messages (sender_id, created_at desc);

create or replace function public.guard_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_muted timestamptz;
  v_recent int;
begin
  new.body := btrim(new.body);
  new.created_at := clock_timestamp();
  new.hidden_at := null;
  new.hidden_by := null;

  select muted_until into v_muted from public.profiles where id = new.sender_id;
  if v_muted is not null and v_muted > now() then
    raise exception 'You are muted until % UTC.',
      to_char(v_muted at time zone 'utc', 'Mon DD, HH24:MI')
      using hint = 'muted';
  end if;

  select count(*) into v_recent
  from public.messages
  where sender_id = new.sender_id
    and created_at > now() - interval '10 seconds';
  if v_recent >= 5 then
    raise exception 'Too many messages. Wait a few seconds and try again.'
      using hint = 'rate_limited';
  end if;

  if exists (
    select 1 from public.messages
    where sender_id = new.sender_id
      and thread_id = new.thread_id
      and body = new.body
      and created_at > now() - interval '30 seconds'
  ) then
    raise exception 'You just sent that same message.'
      using hint = 'duplicate';
  end if;

  return new;
end;
$$;

drop trigger if exists messages_guard_insert on public.messages;
create trigger messages_guard_insert
  before insert on public.messages
  for each row execute function public.guard_message_insert();

-- A new message reopens a resolved conversation and bumps inbox order.
create or replace function public.touch_thread_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.threads
  set updated_at = now(),
      status = 'open'
  where id = new.thread_id;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reports + moderation log
-- ---------------------------------------------------------------------------
create table if not exists public.message_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  thread_id uuid not null references public.threads(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (reason in ('spam', 'harassment', 'inappropriate', 'other')),
  note text check (note is null or char_length(note) <= 300),
  status text not null default 'open' check (status in ('open', 'dismissed', 'actioned')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null,
  unique (message_id, reporter_id)
);

create index if not exists message_reports_status_idx
  on public.message_reports (status, created_at desc);

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  moderator_id uuid references public.profiles(id) on delete set null,
  report_id uuid references public.message_reports(id) on delete set null,
  target_user_id uuid references public.profiles(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  action text not null check (action in ('dismiss', 'remove_message', 'mute_user', 'unmute_user')),
  original_body text,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists moderation_actions_created_idx
  on public.moderation_actions (created_at desc);

alter table public.message_reports enable row level security;
alter table public.moderation_actions enable row level security;

drop policy if exists "reports_select_own_or_moderator" on public.message_reports;
create policy "reports_select_own_or_moderator"
  on public.message_reports for select to authenticated
  using (reporter_id = auth.uid() or public.is_moderator());

drop policy if exists "moderation_actions_select_moderator" on public.moderation_actions;
create policy "moderation_actions_select_moderator"
  on public.moderation_actions for select to authenticated
  using (public.is_moderator());

-- ---------------------------------------------------------------------------
-- RPCs: conversations
-- ---------------------------------------------------------------------------
create or replace function public.start_thread(
  p_mentor uuid,
  p_title text,
  p_first_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_muted timestamptz;
  v_title text := btrim(coalesce(p_title, ''));
  v_count int;
  v_thread uuid;
begin
  if v_uid is null then
    raise exception 'Sign in first.';
  end if;

  select role, muted_until into v_role, v_muted from public.profiles where id = v_uid;
  if v_role is distinct from 'learner' then
    raise exception 'Only learners can open a new conversation.';
  end if;
  if v_muted is not null and v_muted > now() then
    raise exception 'You are muted and cannot open conversations right now.'
      using hint = 'muted';
  end if;
  if not exists (select 1 from public.profiles where id = p_mentor and role = 'mentor') then
    raise exception 'Pick a mentor from the list.';
  end if;
  if char_length(v_title) < 3 or char_length(v_title) > 80 then
    raise exception 'Topic must be between 3 and 80 characters.';
  end if;

  select count(*) into v_count
  from public.threads
  where created_by = v_uid and created_at > now() - interval '1 day';
  if v_count >= 10 then
    raise exception 'Daily limit reached. You can open up to 10 conversations per day.'
      using hint = 'rate_limited';
  end if;

  insert into public.threads (title, created_by)
  values (v_title, v_uid)
  returning id into v_thread;

  insert into public.thread_participants (thread_id, user_id)
  values (v_thread, v_uid), (v_thread, p_mentor);

  if p_first_message is not null and btrim(p_first_message) <> '' then
    insert into public.messages (thread_id, sender_id, body)
    values (v_thread, v_uid, p_first_message);
  end if;

  return v_thread;
end;
$$;

create or replace function public.my_threads()
returns table (
  id uuid,
  title text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  peer_id uuid,
  peer_name text,
  peer_role text,
  peer_headline text,
  last_body text,
  last_sender_id uuid,
  last_at timestamptz,
  last_hidden boolean,
  unread_count int
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    t.id,
    t.title,
    t.status,
    t.created_at,
    t.updated_at,
    peer.user_id,
    pp.display_name,
    pp.role,
    pp.headline,
    lm.body,
    lm.sender_id,
    lm.created_at,
    lm.hidden_at is not null,
    (
      select count(*)::int from public.messages m
      where m.thread_id = t.id
        and m.sender_id <> me.user_id
        and m.created_at > me.last_read_at
    )
  from public.thread_participants me
  join public.threads t on t.id = me.thread_id
  left join lateral (
    select tp.user_id from public.thread_participants tp
    where tp.thread_id = t.id and tp.user_id <> me.user_id
    limit 1
  ) peer on true
  left join public.profiles pp on pp.id = peer.user_id
  left join lateral (
    select m.body, m.sender_id, m.created_at, m.hidden_at
    from public.messages m
    where m.thread_id = t.id
    order by m.created_at desc
    limit 1
  ) lm on true
  where me.user_id = auth.uid()
  order by t.updated_at desc;
$$;

create or replace function public.mark_thread_read(p_thread uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.thread_participants
  set last_read_at = now()
  where thread_id = p_thread and user_id = auth.uid();
$$;

create or replace function public.set_thread_status(p_thread uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_thread_participant(p_thread) then
    raise exception 'You are not part of this conversation.';
  end if;
  if p_status not in ('open', 'resolved') then
    raise exception 'Unknown status.';
  end if;
  update public.threads set status = p_status where id = p_thread;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPCs: report flow
-- ---------------------------------------------------------------------------
create or replace function public.report_message(
  p_message uuid,
  p_reason text,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_msg public.messages%rowtype;
  v_count int;
  v_id uuid;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if v_uid is null then
    raise exception 'Sign in first.';
  end if;
  select * into v_msg from public.messages where id = p_message;
  if not found or not public.is_thread_participant(v_msg.thread_id) then
    raise exception 'Message not found.';
  end if;
  if v_msg.sender_id = v_uid then
    raise exception 'You cannot report your own message.';
  end if;
  if p_reason not in ('spam', 'harassment', 'inappropriate', 'other') then
    raise exception 'Pick a reason.';
  end if;
  if v_note is not null and char_length(v_note) > 300 then
    raise exception 'Keep the note under 300 characters.';
  end if;

  select count(*) into v_count
  from public.message_reports
  where reporter_id = v_uid and created_at > now() - interval '1 day';
  if v_count >= 20 then
    raise exception 'Report limit reached for today.' using hint = 'rate_limited';
  end if;

  insert into public.message_reports (message_id, thread_id, reporter_id, reported_user_id, reason, note)
  values (v_msg.id, v_msg.thread_id, v_uid, v_msg.sender_id, p_reason, v_note)
  on conflict (message_id, reporter_id) do nothing
  returning id into v_id;

  if v_id is null then
    raise exception 'You already reported this message.' using hint = 'duplicate';
  end if;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPCs: moderation panel (moderators only)
-- ---------------------------------------------------------------------------
create or replace function public.moderation_stats()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_moderator() then
    raise exception 'Moderators only.';
  end if;
  return json_build_object(
    'open_reports', (select count(*) from public.message_reports where status = 'open'),
    'actions_24h', (select count(*) from public.moderation_actions where created_at > now() - interval '1 day'),
    'muted_users', (select count(*) from public.profiles where muted_until > now()),
    'messages_24h', (select count(*) from public.messages where created_at > now() - interval '1 day'),
    'active_threads_24h', (
      select count(distinct thread_id) from public.messages
      where created_at > now() - interval '1 day'
    ),
    'open_threads', (select count(*) from public.threads where status = 'open'),
    'learners', (select count(*) from public.profiles where role = 'learner'),
    'mentors', (select count(*) from public.profiles where role = 'mentor')
  );
end;
$$;

create or replace function public.moderation_queue(p_status text default 'open')
returns table (
  report_id uuid,
  reason text,
  note text,
  status text,
  reported_at timestamptz,
  report_count int,
  message_id uuid,
  message_body text,
  message_at timestamptz,
  message_hidden boolean,
  thread_id uuid,
  thread_title text,
  reporter_name text,
  reported_user_id uuid,
  reported_name text,
  reported_role text,
  reported_muted_until timestamptz,
  context json
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_moderator() then
    raise exception 'Moderators only.';
  end if;

  return query
  select
    r.id,
    r.reason,
    r.note,
    r.status,
    r.created_at,
    (select count(*)::int from public.message_reports r2 where r2.message_id = r.message_id),
    m.id,
    coalesce(
      (select ma.original_body from public.moderation_actions ma
       where ma.message_id = m.id and ma.action = 'remove_message'
       order by ma.created_at desc limit 1),
      m.body
    ),
    m.created_at,
    m.hidden_at is not null,
    t.id,
    t.title,
    rp.display_name,
    up.id,
    up.display_name,
    up.role,
    up.muted_until,
    (
      select coalesce(json_agg(c order by c.created_at), '[]'::json)
      from (
        (
          select cm.id, cm.body, cm.created_at, cp.display_name as sender, cm.id = m.id as reported
          from public.messages cm
          join public.profiles cp on cp.id = cm.sender_id
          where cm.thread_id = m.thread_id and cm.created_at <= m.created_at
          order by cm.created_at desc
          limit 3
        )
        union all
        (
          select cm.id, cm.body, cm.created_at, cp.display_name, false
          from public.messages cm
          join public.profiles cp on cp.id = cm.sender_id
          where cm.thread_id = m.thread_id and cm.created_at > m.created_at
          order by cm.created_at asc
          limit 2
        )
      ) c
    )
  from public.message_reports r
  join public.messages m on m.id = r.message_id
  join public.threads t on t.id = r.thread_id
  join public.profiles rp on rp.id = r.reporter_id
  join public.profiles up on up.id = r.reported_user_id
  where p_status = 'all' or r.status = p_status
  order by r.created_at desc
  limit 100;
end;
$$;

create or replace function public.moderate_report(
  p_report uuid,
  p_action text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_report public.message_reports%rowtype;
  v_msg public.messages%rowtype;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if not public.is_moderator() then
    raise exception 'Moderators only.';
  end if;
  if p_action not in ('dismiss', 'remove', 'remove_and_mute') then
    raise exception 'Unknown action.';
  end if;

  select * into v_report from public.message_reports where id = p_report for update;
  if not found then
    raise exception 'Report not found.';
  end if;

  if p_action = 'dismiss' then
    update public.message_reports
    set status = 'dismissed', resolved_at = now(), resolved_by = v_uid
    where id = p_report;
    insert into public.moderation_actions (moderator_id, report_id, target_user_id, message_id, action, note)
    values (v_uid, p_report, v_report.reported_user_id, v_report.message_id, 'dismiss', v_note);
    return;
  end if;

  select * into v_msg from public.messages where id = v_report.message_id for update;
  if v_msg.hidden_at is null then
    insert into public.moderation_actions (moderator_id, report_id, target_user_id, message_id, action, original_body, note)
    values (v_uid, p_report, v_msg.sender_id, v_msg.id, 'remove_message', v_msg.body, v_note);
    update public.messages
    set body = 'Removed by a moderator.', hidden_at = now(), hidden_by = v_uid
    where id = v_msg.id;
  end if;

  update public.message_reports
  set status = 'actioned', resolved_at = now(), resolved_by = v_uid
  where message_id = v_report.message_id and status = 'open';

  if p_action = 'remove_and_mute' then
    update public.profiles
    set muted_until = greatest(coalesce(muted_until, now()), now()) + interval '24 hours'
    where id = v_report.reported_user_id;
    insert into public.moderation_actions (moderator_id, report_id, target_user_id, message_id, action, note)
    values (v_uid, p_report, v_report.reported_user_id, v_report.message_id, 'mute_user', v_note);
  end if;
end;
$$;

create or replace function public.unmute_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_moderator() then
    raise exception 'Moderators only.';
  end if;
  update public.profiles set muted_until = null where id = p_user;
  insert into public.moderation_actions (moderator_id, target_user_id, action)
  values (auth.uid(), p_user, 'unmute_user');
end;
$$;

create or replace function public.muted_users()
returns table (id uuid, display_name text, role text, muted_until timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_moderator() then
    raise exception 'Moderators only.';
  end if;
  return query
  select p.id, p.display_name, p.role, p.muted_until
  from public.profiles p
  where p.muted_until > now()
  order by p.muted_until asc;
end;
$$;

create or replace function public.moderation_log(p_limit int default 50)
returns table (
  id uuid,
  action text,
  created_at timestamptz,
  moderator_name text,
  target_name text,
  original_body text,
  note text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_moderator() then
    raise exception 'Moderators only.';
  end if;
  return query
  select a.id, a.action, a.created_at, mp.display_name, tp.display_name, a.original_body, a.note
  from public.moderation_actions a
  left join public.profiles mp on mp.id = a.moderator_id
  left join public.profiles tp on tp.id = a.target_user_id
  order by a.created_at desc
  limit least(greatest(p_limit, 1), 200);
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges: least privilege for API roles
-- ---------------------------------------------------------------------------
revoke all on public.profiles, public.threads, public.thread_participants,
  public.messages, public.message_reports, public.moderation_actions
  from anon;
revoke all on public.profiles, public.threads, public.thread_participants,
  public.messages, public.message_reports, public.moderation_actions
  from authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, headline) on public.profiles to authenticated;
grant select on public.threads to authenticated;
grant select on public.thread_participants to authenticated;
grant select, insert on public.messages to authenticated;
grant select on public.message_reports to authenticated;
grant select on public.moderation_actions to authenticated;

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.is_thread_participant(uuid)',
    'public.is_moderator()',
    'public.start_thread(uuid, text, text)',
    'public.my_threads()',
    'public.mark_thread_read(uuid)',
    'public.set_thread_status(uuid, text)',
    'public.report_message(uuid, text, text)',
    'public.moderation_stats()',
    'public.moderation_queue(text)',
    'public.moderate_report(uuid, text, text)',
    'public.unmute_user(uuid)',
    'public.muted_users()',
    'public.moderation_log(int)'
  ] loop
    execute format('revoke all on function %s from public, anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;

  foreach fn in array array[
    'public.handle_new_user()',
    'public.guard_message_insert()',
    'public.touch_thread_updated_at()'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', fn);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Realtime publication
-- ---------------------------------------------------------------------------
do $$
declare
  tbl text;
begin
  foreach tbl in array array['messages', 'threads', 'thread_participants', 'message_reports'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = tbl
    ) then
      execute format('alter publication supabase_realtime add table public.%I', tbl);
    end if;
  end loop;
end;
$$;
