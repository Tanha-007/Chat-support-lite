# Deskline (Chat Support Lite)

Flutter learner↔mentor chat with Supabase Auth, Postgres persistence, RLS, and Realtime.

Repo: [github.com/Tanha-007/Chat-support-lite](https://github.com/Tanha-007/Chat-support-lite)

## What it does

- Sign in with Supabase Auth
- List threads you participate in
- Load message history when a thread opens
- Send text messages (500 char cap, send cooldown)
- Receive peer messages live over Supabase Realtime
- Show ephemeral typing indicators via Presence
- RLS so non-participants cannot read others' threads or messages

## Demo accounts

Use two browsers or devices at once.

```
Learner
email: learner@deskline.app
password: DemoChat123!

Mentor
email: mentor@deskline.app
password: DemoChat123!
```

Login screen has **Fill learner** / **Fill mentor** shortcuts.

Seeded thread: **Homework help: fractions**

## Run (web demo)

```bash
flutter pub get
flutter run -d chrome
```

Open a second Chrome profile (or another browser) for the other demo account.

## Run (Android)

1. Start an emulator or plug in a device with USB debugging.
2. From this folder:

```bash
flutter pub get
flutter run
```

## Run (iOS)

Needs a Mac with Xcode:

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run
```

## Two-client walkthrough

1. Client A: sign in as learner.
2. Client B: sign in as mentor.
3. Both open **Homework help: fractions**.
4. Type on one side and confirm typing dots on the other.
5. Send messages both ways and confirm live delivery.
6. Reload either client and confirm history still loads.
7. (Optional) Sign in as a fresh account with no thread membership and confirm empty isolation.

## Project layout

```
lib/
  main.dart
  config/supabase_config.dart
  data/chat_repository.dart
  models/
  screens/
  theme/
  widgets/
docs/REALTIME_DESIGN.md
supabase/migrations/
scripts/smoke_test.ps1
```

## Backend smoke test

```bash
powershell -File scripts/smoke_test.ps1
```

Covers learner/mentor sign-in, thread visibility, message insert, length rejection, and RLS isolation for a stranger.

## Backend

- Supabase URL and anon key live in `lib/config/supabase_config.dart` (publishable/anon client key only).
- SQL schema + RLS live in `supabase/migrations/`.
- Seeded with two demo users, one shared thread, and a welcome message.
- Create-account flow is available on the login screen for fresh emails (no thread until invited).

## Docs

- Realtime + RLS notes: [`docs/REALTIME_DESIGN.md`](docs/REALTIME_DESIGN.md)
- Assignment brief (no secrets): [`ASSIGNMENT.md`](ASSIGNMENT.md)

## Walkthrough video

Add your <=5 minute two-client demo video link here after recording.
