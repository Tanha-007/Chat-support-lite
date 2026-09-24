// Act as a second client for manual demos: show typing, then reply in a thread.
//   node peer_reply.mjs <email> "<thread title>" "<reply text>"
import { createClient } from '@supabase/supabase-js';

const URL = 'https://hwfgytocskiovcqyxpwf.supabase.co';
const ANON =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Zmd5dG9jc2tpb3ZjcXl4cHdmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNjU2ODcsImV4cCI6MjEwNTc0MTY4N30.mZJbQ8lpk3rL6Ln28ePuZrW9VYRgjvZd8Nj1q-gSwpw';

const [email, title, reply] = process.argv.slice(2);
if (!email || !title || !reply) {
  console.log('usage: node peer_reply.mjs <email> "<thread title>" "<reply text>"');
  process.exit(1);
}

const c = createClient(URL, ANON, { auth: { persistSession: false } });
const { data: auth, error } = await c.auth.signInWithPassword({ email, password: 'DemoChat123!' });
if (error) throw error;
c.realtime.setAuth(auth.session.access_token);

const { data: threads } = await c.rpc('my_threads');
const thread = threads.find((t) => t.title === title);
if (!thread) throw new Error(`No thread titled "${title}" for ${email}`);

const { data: me } = await c.from('profiles').select('display_name').eq('id', auth.user.id).single();
const typing = c.channel(`typing:${thread.id}`, { config: { presence: { key: auth.user.id } } });
await new Promise((resolve) => typing.subscribe((s) => s === 'SUBSCRIBED' && resolve()));
await typing.track({ name: me.display_name, typing: true, user_id: auth.user.id });
console.log(`${me.display_name} is typing in "${title}"`);
await new Promise((r) => setTimeout(r, 4000));

await c.rpc('mark_thread_read', { p_thread: thread.id });
const { error: sendErr } = await c
  .from('messages')
  .insert({ thread_id: thread.id, sender_id: auth.user.id, body: reply });
if (sendErr) throw sendErr;
await typing.track({ name: me.display_name, typing: false, user_id: auth.user.id });
console.log('reply sent');
await new Promise((r) => setTimeout(r, 500));
await c.removeAllChannels();
process.exit(0);
