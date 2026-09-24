-- Demo data. Run after the demo auth users exist (scripts/seed_demo.ps1 creates them).
-- Idempotent: safe to run more than once.

do $$
declare
  v_ava uuid := (select id from auth.users where email = 'learner@deskline.app');
  v_noah uuid := (select id from auth.users where email = 'mentor@deskline.app');
  v_iris uuid := (select id from auth.users where email = 'iris@deskline.app');
  v_sam uuid := (select id from auth.users where email = 'moderator@deskline.app');
  v_qa uuid := (select id from auth.users where email = 'qa.mentor@deskline.app');
  v_thread uuid;
begin
  if v_ava is null or v_noah is null or v_iris is null or v_sam is null or v_qa is null then
    raise exception 'Demo users missing. Run scripts/seed_demo.ps1 first.';
  end if;

  insert into public.profiles (id, display_name, role) values
    (v_ava, 'Ava Brooks', 'learner'),
    (v_noah, 'Noah Kim', 'mentor'),
    (v_iris, 'Iris Chen', 'mentor'),
    (v_sam, 'Sam Ortiz', 'moderator'),
    (v_qa, 'QA Mentor', 'mentor')
  on conflict (id) do nothing;

  update public.profiles set display_name = 'Ava Brooks', role = 'learner', headline = null, listed = true
    where id = v_ava;
  update public.profiles set display_name = 'Noah Kim', role = 'mentor',
    headline = 'Maths and physics, grades 6 to 10', listed = true
    where id = v_noah;
  update public.profiles set display_name = 'Iris Chen', role = 'mentor',
    headline = 'Essay writing and English literature', listed = true
    where id = v_iris;
  update public.profiles set display_name = 'Sam Ortiz', role = 'moderator',
    headline = 'Community safety', listed = false
    where id = v_sam;
  update public.profiles set display_name = 'QA Mentor', role = 'mentor',
    headline = 'Automated test account', listed = false
    where id = v_qa;

  -- Thread 1: Ava and Noah (original seed thread)
  select t.id into v_thread
  from public.threads t
  where t.title = 'Homework help: fractions'
  limit 1;

  if v_thread is null then
    insert into public.threads (title, created_by) values ('Homework help: fractions', v_ava)
    returning id into v_thread;
  else
    update public.threads set created_by = v_ava where id = v_thread;
  end if;

  insert into public.thread_participants (thread_id, user_id) values
    (v_thread, v_ava), (v_thread, v_noah)
  on conflict do nothing;

  delete from public.messages where thread_id = v_thread and body like 'Smoke ping%';

  if not exists (select 1 from public.messages where thread_id = v_thread) then
    insert into public.messages (thread_id, sender_id, body) values
      (v_thread, v_noah, 'Hi Ava. Send me the problem you are stuck on and we will walk through it together.');
  end if;

  -- Thread 2: Ava and Iris
  select t.id into v_thread
  from public.threads t
  where t.title = 'Essay structure for history coursework'
  limit 1;

  if v_thread is null then
    insert into public.threads (title, created_by)
    values ('Essay structure for history coursework', v_ava)
    returning id into v_thread;

    insert into public.thread_participants (thread_id, user_id) values
      (v_thread, v_ava), (v_thread, v_iris);

    insert into public.messages (thread_id, sender_id, body) values
      (v_thread, v_ava, 'My intro keeps turning into a summary of the whole essay. How long should it be?');
    perform pg_sleep(0.05);
    insert into public.messages (thread_id, sender_id, body) values
      (v_thread, v_iris, 'Aim for three or four sentences: context, the question, and your argument in one line. Paste your draft and I will mark it up.');
  end if;
end;
$$;
