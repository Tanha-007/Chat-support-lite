# Realtime, RLS and moderation design

## Tables

| Table | Purpose |
| --- | --- |
| `profiles` | One row per auth user. `role` is learner, mentor or moderator. `headline`, `listed`, `muted_until`. Created by a trigger on `auth.users`. |
| `threads` | Conversation. `title` (3 to 80 chars), `status` open or resolved, `created_by`. |
| `thread_participants` | Membership plus `last_read_at` for unread counts and read receipts. |
| `messages` | `body` 1 to 500 chars, never blank. `hidden_at` / `hidden_by` when a moderator removes it. |
| `message_reports` | One report per message per reporter. Reason, note, status open / dismissed / actioned. |
| `moderation_actions` | Audit log: dismiss, remove, mute, unmute. Keeps the original body of removed messages. |

Migrations live in `supabase/migrations/`. Demo data lives in `supabase/seed.sql`.

## Write paths

Clients never write threads or participants directly. Everything goes through `security definer` RPCs that check the caller first:

- `start_thread(mentor, title, first_message)`: learners only, not muted, target must be a mentor, 10 per day.
- `my_threads()`: inbox rows with peer, last message, and unread count in one round trip.
- `mark_thread_read(thread)`, `set_thread_status(thread, status)`.
- `report_message(message, reason, note)`: must be a participant, cannot report yourself.
- Moderators only: `moderation_stats`, `moderation_queue`, `moderate_report`, `muted_users`, `unmute_user`, `moderation_log`.

Messages are the one table with a direct insert, guarded by RLS and a `BEFORE INSERT` trigger (`guard_message_insert`).

## RLS and grants

- `anon` has no table access at all.
- `authenticated` can select profiles, threads, participants, messages and reports, and can insert messages. Profiles allow updating only `display_name` and `headline` (column grant), so nobody can promote themselves or clear a mute.
- `is_thread_participant(tid)` is `security definer` so policies avoid recursive lookups.
- Threads, participants and messages are visible only to participants. Moderators additionally see reports and actions.
- A stranger sees zero rows and receives zero Realtime events for a thread they are not in. Both are checked by the test scripts.

## Abuse guards

Enforced in Postgres so a modified client cannot skip them:

| Rule | Where |
| --- | --- |
| 1 to 500 characters, not blank, trimmed | check constraint + trigger |
| 5 messages per 10 seconds per sender | trigger, hint `rate_limited` |
| Same text within 30 seconds rejected | trigger, hint `duplicate` |
| Muted users cannot send or start threads | trigger + `start_thread` |
| 10 new conversations per learner per day | `start_thread` |
| Server time for `created_at` | trigger uses `clock_timestamp()` |

The client mirrors these for fast feedback: a counter from 400 characters, a disabled send button over the cap, a 700 ms send cooldown, and friendly messages mapped from the SQL hints.

## Realtime

Postgres Changes respect RLS, so each client only receives rows it could select.

| Channel | Events | Used for |
| --- | --- | --- |
| `thread:{id}` | messages insert and update, thread_participants update, threads update | live messages, moderator removals, read receipts, resolve and reopen |
| `inbox:{uid}` | messages insert, threads update, thread_participants insert | inbox reorder, unread badges, new conversations |
| `typing:{id}` | Presence | typing indicator. Only tracked when the state changes, never written to a table. |
| `moderation:reports` | message_reports insert | live queue and nav badge for moderators |

### Ordering and gaps

1. The chat screen subscribes before it fetches history, then merges by id so nothing is lost in between.
2. Sends are optimistic. A local bubble shows "Sending", is replaced when the insert returns or when the Realtime echo arrives, and turns into "Tap to retry" on failure.
3. When the channel reconnects, or the app returns from the background, history is fetched again and merged.
4. Read receipts come from the peer's `last_read_at`. The last message you sent shows "Seen" once their read time passes it.

## Known limitations

- The typing channel is a public Presence channel. Someone who knows a thread's UUID could see typing names (never message content). Supabase private channels with Realtime Authorization would close this.
- Push notifications and attachments are not included.
