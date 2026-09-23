### APP-05 - Chat support lite with Supabase Realtime

**Max score:** 100

#### Problem

Build a mobile learner↔mentor chat: threads, send text, realtime receive. Persist in Supabase. Show typing indicator (ephemeral) optional but valued.

Success: two clients exchange messages live; history loads on open; basic spam length limits.

#### Build / approach

Flutter + Supabase Realtime + Auth. Tables: `threads`, `messages` (plus participants/profiles). RLS so participants only. Seed one thread for two demo users.

#### Deliverables

Source, SQL, two demo accounts, walkthrough video of two-device/emulator chat (≤5 min).
