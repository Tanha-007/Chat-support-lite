-- Removes throwaway accounts created by scripts/smoke_test.ps1,
-- scripts/realtime_test.mjs and manual UI sign-up tests, plus every thread
-- they took part in. Demo accounts and the unlisted QA Mentor are kept.
-- Run with: powershell -File scripts/run_sql.ps1 supabase/cleanup_test_data.sql

begin;

create temporary table _test_users on commit drop as
select id from auth.users
where email like 'smoke.%@deskline.app'
   or email like 'rt.%@deskline.app'
   or email like 'stranger+%@deskline.app'
   or email like 'ui.test.%@deskline.app';

create temporary table _test_threads on commit drop as
select distinct tp.thread_id as id
from public.thread_participants tp
where tp.user_id in (select id from _test_users);

delete from public.moderation_actions a
where a.target_user_id in (select id from _test_users)
   or a.moderator_id in (select id from _test_users)
   or a.message_id in (
        select m.id from public.messages m
        where m.thread_id in (select id from _test_threads))
   or a.report_id in (
        select r.id from public.message_reports r
        where r.thread_id in (select id from _test_threads));

delete from public.threads where id in (select id from _test_threads);

delete from auth.users where id in (select id from _test_users);

commit;

select
  (select count(*) from public.profiles) as profiles_left,
  (select count(*) from public.threads) as threads_left,
  (select count(*) from public.message_reports) as reports_left,
  (select count(*) from public.moderation_actions) as actions_left;
