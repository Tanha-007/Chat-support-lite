import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../models/profile.dart';

const _messageColumns = 'id, thread_id, sender_id, body, created_at, hidden_at';
const _profileColumns = 'id, display_name, role, headline, muted_until';

class ChatRepository {
  ChatRepository({required this.client});

  final SupabaseClient client;

  String? get userId => client.auth.currentUser?.id;
  String? get email => client.auth.currentUser?.email;

  // -- Profile ---------------------------------------------------------------

  Future<Profile?> fetchMyProfile() async {
    final id = userId;
    if (id == null) return null;
    final row = await client
        .from('profiles')
        .select(_profileColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Profile> updateMyProfile({
    required String displayName,
    String? headline,
  }) async {
    final id = userId;
    if (id == null) throw StateError('Not signed in');
    final name = displayName.trim();
    if (name.length < SupabaseConfig.minNameLength ||
        name.length > SupabaseConfig.maxNameLength) {
      throw ArgumentError(
        'Name must be ${SupabaseConfig.minNameLength} to '
        '${SupabaseConfig.maxNameLength} characters.',
      );
    }
    final patch = <String, dynamic>{'display_name': name};
    if (headline != null) {
      final h = headline.trim();
      if (h.length > SupabaseConfig.maxHeadlineLength) {
        throw ArgumentError(
          'Headline must be ${SupabaseConfig.maxHeadlineLength} characters or fewer.',
        );
      }
      patch['headline'] = h.isEmpty ? null : h;
    }
    final row = await client
        .from('profiles')
        .update(patch)
        .eq('id', id)
        .select(_profileColumns)
        .single();
    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<Profile>> fetchMentors() async {
    final rows = await client
        .from('profiles')
        .select(_profileColumns)
        .eq('role', 'mentor')
        .eq('listed', true)
        .order('display_name');
    return (rows as List)
        .map((r) => Profile.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // -- Threads ---------------------------------------------------------------

  Future<List<ChatThread>> fetchThreads() async {
    if (userId == null) return [];
    final rows = await client.rpc('my_threads');
    return (rows as List)
        .map((r) => ChatThread.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<String> startThread({
    required String mentorId,
    required String title,
    String? firstMessage,
  }) async {
    final topic = title.trim();
    if (topic.length < SupabaseConfig.minTopicLength ||
        topic.length > SupabaseConfig.maxTopicLength) {
      throw ArgumentError(
        'Topic must be ${SupabaseConfig.minTopicLength} to '
        '${SupabaseConfig.maxTopicLength} characters.',
      );
    }
    final first = firstMessage?.trim() ?? '';
    if (first.length > SupabaseConfig.maxMessageLength) {
      throw ArgumentError(
        'First message must be ${SupabaseConfig.maxMessageLength} characters or fewer.',
      );
    }
    final id = await client.rpc(
      'start_thread',
      params: {
        'p_mentor': mentorId,
        'p_title': topic,
        'p_first_message': first.isEmpty ? null : first,
      },
    );
    return id as String;
  }

  Future<void> setThreadStatus(String threadId, String status) async {
    await client.rpc(
      'set_thread_status',
      params: {'p_thread': threadId, 'p_status': status},
    );
  }

  Future<void> markRead(String threadId) async {
    await client.rpc('mark_thread_read', params: {'p_thread': threadId});
  }

  /// Returns the peer's last read time for receipts.
  Future<DateTime?> fetchPeerLastRead(String threadId) async {
    final uid = userId;
    if (uid == null) return null;
    final row = await client
        .from('thread_participants')
        .select('last_read_at')
        .eq('thread_id', threadId)
        .neq('user_id', uid)
        .limit(1)
        .maybeSingle();
    final raw = row?['last_read_at'] as String?;
    return raw == null ? null : DateTime.parse(raw).toLocal();
  }

  Future<String> fetchThreadStatus(String threadId) async {
    final row = await client
        .from('threads')
        .select('status')
        .eq('id', threadId)
        .single();
    return row['status'] as String? ?? 'open';
  }

  // -- Messages --------------------------------------------------------------

  Future<List<ChatMessage>> fetchMessages(String threadId) async {
    final rows = await client
        .from('messages')
        .select(_messageColumns)
        .eq('thread_id', threadId)
        .order('created_at', ascending: true)
        .limit(500);
    return (rows as List)
        .map((r) => ChatMessage.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  static String? validateMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return 'Message is empty.';
    if (trimmed.length > SupabaseConfig.maxMessageLength) {
      return 'Keep messages to ${SupabaseConfig.maxMessageLength} characters.';
    }
    return null;
  }

  Future<ChatMessage> sendMessage({
    required String threadId,
    required String body,
  }) async {
    final uid = userId;
    if (uid == null) throw StateError('Not signed in');
    final problem = validateMessage(body);
    if (problem != null) throw ArgumentError(problem);

    final row = await client
        .from('messages')
        .insert({'thread_id': threadId, 'sender_id': uid, 'body': body.trim()})
        .select(_messageColumns)
        .single();
    return ChatMessage.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> reportMessage({
    required String messageId,
    required String reason,
    String? note,
  }) async {
    await client.rpc(
      'report_message',
      params: {
        'p_message': messageId,
        'p_reason': reason,
        'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      },
    );
  }

  // -- Realtime --------------------------------------------------------------

  /// One channel per open chat: message inserts and moderation edits,
  /// peer read receipts, and thread status.
  RealtimeChannel subscribeThread({
    required String threadId,
    required void Function(ChatMessage message) onInsert,
    required void Function(ChatMessage message) onUpdate,
    required void Function(String userId, DateTime lastReadAt) onRead,
    required void Function(String status) onStatus,
    required void Function(RealtimeSubscribeStatus status) onState,
  }) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'thread_id',
      value: threadId,
    );
    final channel = client.channel('thread:$threadId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: (payload) => onInsert(
            ChatMessage.fromJson(Map<String, dynamic>.from(payload.newRecord)),
          ),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: (payload) => onUpdate(
            ChatMessage.fromJson(Map<String, dynamic>.from(payload.newRecord)),
          ),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'thread_participants',
          filter: filter,
          callback: (payload) {
            final row = payload.newRecord;
            final at = row['last_read_at'] as String?;
            final uid = row['user_id'] as String?;
            if (at != null && uid != null) {
              onRead(uid, DateTime.parse(at).toLocal());
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'threads',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: threadId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status != null) onStatus(status);
          },
        )
        .subscribe((status, _) => onState(status));
    return channel;
  }

  /// Inbox refresh signal: any visible message, new membership, or status change.
  RealtimeChannel subscribeInbox({required void Function() onChange}) {
    final uid = userId;
    final channel = client.channel('inbox:${uid ?? 'anon'}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'threads',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'thread_participants',
          filter: uid == null
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'user_id',
                  value: uid,
                ),
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel subscribeTyping({
    required String threadId,
    required String displayName,
    required void Function(List<String> typingNames) onTyping,
  }) {
    final channel = client.channel(
      'typing:$threadId',
      opts: RealtimeChannelConfig(key: userId ?? ''),
    );

    channel
        .onPresenceSync((_) {
          final names = <String>{};
          for (final entry in channel.presenceState()) {
            for (final p in entry.presences) {
              final name = p.payload['name'] as String?;
              final typing = p.payload['typing'] == true;
              final uid = p.payload['user_id'] as String?;
              if (typing && uid != userId && name != null && name.isNotEmpty) {
                names.add(name);
              }
            }
          }
          onTyping(names.toList());
        })
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await channel.track({
              'name': displayName,
              'typing': false,
              'user_id': userId,
            });
          }
        });

    return channel;
  }

  Future<void> setTyping({
    required RealtimeChannel channel,
    required String displayName,
    required bool typing,
  }) async {
    await channel.track({
      'name': displayName,
      'typing': typing,
      'user_id': userId,
    });
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      client.removeChannel(channel);
}
