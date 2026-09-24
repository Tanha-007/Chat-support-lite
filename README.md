# Deskline (Chat Support Lite)

A mobile chat where learners ask mentors for help, built with Flutter and Supabase. Messages arrive live, history loads when a conversation opens, only the two people in a conversation can read it, and a moderator panel handles reports.

Repo: [github.com/Tanha-007/Chat-support-lite](https://github.com/Tanha-007/Chat-support-lite)

## What is inside

**Learners**
- Sign up with a name, email and password, or use a demo account in one tap.
- Pick a mentor from the directory, give the conversation a topic, and optionally write the first message.
- Inbox with Open / Resolved / All filters, search, unread badges, and a live preview of the last message.

**Everyone in a conversation**
- Live messages over Supabase Realtime, with a typing indicator.
- "Sending", "Sent" and "Seen" receipts on your latest message.
- Day dividers, grouped bubbles, a jump-to-latest button, and a character counter near the 500 cap.
- Enter sends, Shift+Enter adds a new line. Failed sends stay in place with tap to retry.
- Tap a message to copy it, or to report one from the other person.
- Either person can mark a conversation resolved. A new message reopens it.
- Reconnects and app resumes refetch history, so nothing is missed after a dropped connection.

**Moderators (new panel)**
- Live stats: open reports, actions in the last 24 hours, muted users, message and thread activity.
- Report queue with the reported message, who reported it, and the surrounding conversation.
- Actions: dismiss, remove the message, or remove and mute the sender for 24 hours.
- Muted tab with time left and unmute, plus an audit log that keeps the original text of removed messages.
- New reports appear live and the tab shows a badge.

## Demo accounts

All demo accounts use the password `DemoChat123!`. The login screen lists them for one-tap sign-in.

| Name | Email | Role |
| --- | --- | --- |
| Ava Brooks | learner@deskline.app | Learner |
| Noah Kim | mentor@deskline.app | Mentor (maths and physics) |
| Iris Chen | iris@deskline.app | Mentor (essays and English) |
| Sam Ortiz | moderator@deskline.app | Moderator |

Seeded conversations: **Homework help: fractions** (Ava and Noah) and **Essay structure for history coursework** (Ava and Iris).

## Two-client walkthrough

1. Open the app in two windows (for example Chrome and an incognito window, or an emulator and the web build).
2. Sign in as **Ava** on one side and **Noah** on the other. Both open *Homework help: fractions*.
3. Type on one side and watch the typing dots on the other. Send messages both ways.
4. Watch Ava's last message change from "Sent" to "Seen" when Noah has it open.
5. Reload either window. The full history loads again.
6. Try the limits: paste more than 500 characters, or send the same line twice quickly.
7. As Ava, tap one of Noah's messages and report it. Sign in as **Sam** to review it in the Moderation panel.
8. Create a fresh learner account. The inbox is empty, and none of the demo conversations are visible.

## Run

Requires Flutter 3.47 or newer (Dart 3.13).

```bash
flutter pub get
flutter run -d chrome      # web
flutter run                # connected Android device or emulator
```

iOS needs a Mac with Xcode: `cd ios && pod install && cd .. && flutter run`.

The app talks to the hosted Supabase project in `lib/config/supabase_config.dart`. That file holds only the public anon key.

## Backend

Everything the app needs is already applied to the hosted project. To rebuild it on a new project:

```powershell
$env:SUPABASE_ACCESS_TOKEN = '<personal access token>'   # never commit this
powershell -File scripts/run_sql.ps1 supabase/migrations/20260923133000_init_chat.sql
powershell -File scripts/run_sql.ps1 supabase/migrations/20260924100000_conversations_moderation.sql
powershell -File scripts/seed_demo.ps1                     # creates demo users, then runs seed.sql
```

Key points (details in [`docs/REALTIME_DESIGN.md`](docs/REALTIME_DESIGN.md)):

- Row level security limits threads, participants and messages to the people in the conversation. The anon role has no table access.
- Conversations are created through RPCs that check the caller's role. Profiles only allow editing the display name and headline, so nobody can make themselves a moderator.
- Spam and length rules run in a Postgres trigger: 500 characters, 5 messages per 10 seconds, no repeated text within 30 seconds, and no sending while muted. Learners can open 10 conversations per day.

## Testing

| Suite | Command | Result |
| --- | --- | --- |
| Backend smoke test (REST, RPC, RLS, limits, moderation) | `powershell -File scripts/smoke_test.ps1` | 64 of 64 pass |
| Two-client Realtime test (Node, supabase-js) | `cd scripts && npm install && node realtime_test.mjs` | 9 of 9 pass, about 0.8 s delivery |
| Flutter unit and widget tests | `flutter test` | 26 of 26 pass |
| Static analysis | `flutter analyze` | No issues |

The Realtime test signs in a learner, a mentor, a moderator and a stranger at once. It checks live delivery both ways, read receipts, typing presence, a moderator removal arriving live, and that the stranger receives nothing.

`scripts/peer_reply.mjs` plays the other side during a manual test: it shows typing for a few seconds, marks the conversation read, then replies.

The test scripts create throwaway accounts. Remove them afterwards with:

```powershell
powershell -File scripts/run_sql.ps1 supabase/cleanup_test_data.sql
```

## Project layout

```
lib/
  main.dart                 auth gate
  config/                   Supabase URL, anon key, limits, demo accounts
  data/                     chat and moderation repositories, error mapping
  models/                   profile, thread, message, moderation types
  screens/                  login, home shell, inbox, new conversation, chat, profile, moderation
  widgets/                  bubble, composer, report sheet, layout pieces
  theme/app_theme.dart      colours, type scale, component themes
supabase/
  migrations/               schema, RLS, triggers, RPCs
  seed.sql                  demo profiles and conversations
  cleanup_test_data.sql     removes accounts made by the test scripts
scripts/                    run_sql, seed_demo, smoke_test, realtime_test, peer_reply
docs/REALTIME_DESIGN.md     data model, RLS, Realtime channels, abuse guards
```

## Design

A warm paper background with ink text and a single vermilion accent for actions and alerts. Bricolage Grotesque for headings, Instrument Sans for body text, and JetBrains Mono for timestamps and metadata. Flat surfaces with hairline borders, no gradients or glow. On wide screens the bottom bar becomes a side rail and the login screen splits into two columns.

## Known limitations

- The typing indicator uses a public Presence channel, so someone who knows a conversation's ID could see typing names (not messages). Private Realtime channels would close this.
- No attachments or push notifications yet.

## Walkthrough video

Add the link to the two-client demo video (5 minutes or less) here after recording.
