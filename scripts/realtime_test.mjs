// Two real clients over Supabase Realtime: a fresh learner and the unlisted QA mentor.
// Checks live message delivery, typing presence, read receipts, moderation edits,
// and that a stranger subscribed to the same thread receives nothing.
//
//   cd scripts && npm install && npm run realtime
import { createClient } from '@supabase/supabase-js';

const URL = 'https://hwfgytocskiovcqyxpwf.supabase.co';
const ANON =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Zmd5dG9jc2tpb3ZjcXl4cHdmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNjU2ODcsImV4cCI6MjEwNTc0MTY4N30.mZJbQ8lpk3rL6Ln28ePuZrW9VYRgjvZd8Nj1q-gSwpw';
const DEMO_PASSWORD = 'DemoChat123!';

let passed = 0;
const failed = [];
const check = (name, ok, detail = '') => {
  if (ok) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed.push(name);
    console.log(`  FAIL  ${name} ${detail}`);
  }
};

const newClient = () =>
  createClient(URL, ANON, { auth: { persistSession: false, autoRefreshToken: false } });

async function signIn(email, password) {
  const c = newClient();
  const { data, error } = await c.auth.signInWithPassword({ email, password });
  if (error) throw new Error(`${email}: ${error.message}`);
  c.realtime.setAuth(data.session.access_token);
  return { c, user: data.user };
}

async function signUp(email, password, name) {
  const c = newClient();
  const { data, error } = await c.auth.signUp({
    email,
    password,
    options: { data: { display_name: name } },
  });
  if (error) throw new Error(`${email}: ${error.message}`);
  c.realtime.setAuth(data.session.access_token);
  return { c, user: data.user };
}

/** Resolves with the first value pushed within `ms`, or null on timeout. */
function waiter(ms) {
  let resolve;
  const promise = new Promise((r) => {
    resolve = r;
    setTimeout(() => r(null), ms);
  });
  return { promise, push: (v) => resolve(v) };
}

function subscribed(channel) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`timeout joining ${channel.topic}`)), 15000);
    channel.subscribe((status, err) => {
      if (status === 'SUBSCRIBED') {
        clearTimeout(t);
        resolve();
      } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        clearTimeout(t);
        reject(err ?? new Error(status));
      }
    });
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const stamp = Date.now();
  console.log('\n[setup] two clients');
  const learner = await signUp(`rt.learner+${stamp}@deskline.app`, 'Realtime123!', `RT Learner ${stamp}`);
  const mentor = await signIn('qa.mentor@deskline.app', DEMO_PASSWORD);
  const stranger = await signUp(`rt.stranger+${stamp}@deskline.app`, 'Realtime123!', `RT Stranger ${stamp}`);

  const { data: threadId, error: startErr } = await learner.c.rpc('start_thread', {
    p_mentor: mentor.user.id,
    p_title: `Realtime ${stamp}`,
  });
  if (startErr) throw startErr;
  console.log(`  thread ${threadId}`);

  const filter = `thread_id=eq.${threadId}`;

  // Mentor listens for messages, moderation edits, and learner read receipts.
  const mentorInsert = waiter(10000);
  const mentorRead = waiter(10000);
  const mentorChannel = mentor.c
    .channel(`thread:${threadId}:mentor`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter }, (p) =>
      mentorInsert.push(p.new),
    )
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'thread_participants', filter }, (p) => {
      if (p.new.user_id === learner.user.id) mentorRead.push(p.new);
    });

  // Learner listens for replies.
  const learnerInsert = waiter(10000);
  const learnerChannel = learner.c
    .channel(`thread:${threadId}:learner`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter }, (p) => {
      if (p.new.sender_id === mentor.user.id) learnerInsert.push(p.new);
    });

  // Stranger tries to eavesdrop on the same filter.
  const strangerEvents = [];
  const strangerChannel = stranger.c
    .channel(`thread:${threadId}:stranger`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'messages', filter }, (p) =>
      strangerEvents.push(p),
    );

  await Promise.all([subscribed(mentorChannel), subscribed(learnerChannel), subscribed(strangerChannel)]);
  await sleep(1500);

  console.log('\n[1] live delivery');
  const body = `Live ping ${stamp}`;
  const sentAt = Date.now();
  const { error: sendErr } = await learner.c
    .from('messages')
    .insert({ thread_id: threadId, sender_id: learner.user.id, body });
  check('learner insert accepted', !sendErr, sendErr?.message);
  const got = await mentorInsert.promise;
  check('mentor receives the message live', got?.body === body, got ? '' : 'no event within 10s');
  if (got) console.log(`        latency ${Date.now() - sentAt} ms`);

  const reply = `Reply ${stamp}`;
  await mentor.c.from('messages').insert({ thread_id: threadId, sender_id: mentor.user.id, body: reply });
  const gotReply = await learnerInsert.promise;
  check('learner receives the reply live', gotReply?.body === reply);

  console.log('\n[2] read receipts');
  await learner.c.rpc('mark_thread_read', { p_thread: threadId });
  const read = await mentorRead.promise;
  check('mentor sees learner read receipt live', Boolean(read?.last_read_at));

  console.log('\n[3] typing presence');
  const typingSeen = waiter(10000);
  const mentorTyping = mentor.c.channel(`typing:${threadId}`, { config: { presence: { key: mentor.user.id } } });
  mentorTyping.on('presence', { event: 'sync' }, () => {
    const state = mentorTyping.presenceState();
    const typing = Object.values(state)
      .flat()
      .some((p) => p.user_id === learner.user.id && p.typing === true);
    if (typing) typingSeen.push(true);
  });
  const learnerTyping = learner.c.channel(`typing:${threadId}`, { config: { presence: { key: learner.user.id } } });
  await Promise.all([subscribed(mentorTyping), subscribed(learnerTyping)]);
  await learnerTyping.track({ name: 'RT Learner', typing: true, user_id: learner.user.id });
  check('mentor sees learner typing', (await typingSeen.promise) === true);

  console.log('\n[4] moderation edit reaches the chat live');
  const hiddenSeen = waiter(10000);
  const modChannel = mentor.c
    .channel(`thread:${threadId}:mod`)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'messages', filter }, (p) => {
      if (p.new.hidden_at) hiddenSeen.push(p.new);
    });
  await subscribed(modChannel);
  await sleep(1000);
  const { data: msgRow } = await learner.c.from('messages').select('id').eq('body', body).single();
  const { error: repErr } = await mentor.c.rpc('report_message', { p_message: msgRow.id, p_reason: 'spam' });
  check('mentor files a report', !repErr, repErr?.message);
  const moderator = await signIn('moderator@deskline.app', DEMO_PASSWORD);
  const { data: queue } = await moderator.c.rpc('moderation_queue', { p_status: 'open' });
  const report = (queue ?? []).find((r) => r.message_id === msgRow.id);
  const { error: modErr } = await moderator.c.rpc('moderate_report', { p_report: report?.report_id, p_action: 'remove' });
  check('moderator removes it', !modErr, modErr?.message);
  const hidden = await hiddenSeen.promise;
  check('removal arrives live as an update', hidden?.body === 'Removed by a moderator.');

  console.log('\n[5] isolation');
  await sleep(1500);
  check('stranger received zero events for the thread', strangerEvents.length === 0, `got ${strangerEvents.length}`);

  for (const c of [learner.c, mentor.c, stranger.c, moderator.c]) await c.removeAllChannels();

  console.log(`\nPassed: ${passed}   Failed: ${failed.length}`);
  if (failed.length) {
    failed.forEach((f) => console.log(`  - ${f}`));
    process.exit(1);
  }
  console.log('REALTIME TEST PASSED');
  process.exit(0);
}

main().catch((e) => {
  console.error('ERROR', e);
  process.exit(1);
});
