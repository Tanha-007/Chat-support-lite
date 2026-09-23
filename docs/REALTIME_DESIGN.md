# Realtime and RLS design

## Persistence

- `threads`: conversation containers
- `thread_participants`: membership join table
- `messages`: body text with `char_length` between 1 and 500
- `profiles`: display name + learner/mentor role

Sending a message inserts into `messages`. A trigger bumps `threads.updated_at` so the inbox sorts by recent activity.

## Realtime

- **Messages:** Postgres Changes on `public.messages` filtered by `thread_id`. Clients append inserts that are not already present (covers local optimistic echo).
- **Typing:** Presence on channel `typing:{threadId}`. Payload includes `name` and `typing`. Absolute ephemeral: no table writes.

## RLS

Helper `is_thread_participant(tid)` is `security definer` so policies can check membership without recursive policy loops.

- Threads: select only if participant
- Participants: select only for threads you belong to
- Messages: select/insert only if participant; insert must use `auth.uid()` as `sender_id`
- Profiles: authenticated can read (needed for peer labels); update only own row

A user who is not on a thread sees zero rows for that thread's messages.

## Abuse guards

- DB check constraint + RLS `with check` on body length
- Client composer counter and hard cap
- Client send cooldown (~700ms) to blunt rapid spam taps
