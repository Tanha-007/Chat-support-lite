import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../models/profile.dart';

class ChatRepository {
  ChatRepository({required this.client});

  final SupabaseClient client;

  String? get userId => client.auth.currentUser?.id;

  Future<Profile?> fetchMyProfile() async {
    final id = userId;
    if (id == null) return null;
    final row = await client
        .from('profiles')
        .select('id, display_name, role')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<ChatThread>> fetchThreads() async {
    final uid = userId;
    if (uid == null) return [];

    final rows = await client
        .from('threads')
        .select('id, title, updated_at')
        .order('updated_at', ascending: false);

    final threads = <ChatThread>[];
    for (final raw in rows as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      var thread = ChatThread.fromJson(map);

      final peers = await client
          .from('thread_participants')
          .select('user_id, profiles(display_name, role)')
          .eq('thread_id', thread.id)
          .neq('user_id', uid);

      String? peerName;
      String? peerRole;
      final peerRows = peers as List;
      if (peerRows.isNotEmpty) {
        final peer = Map<String, dynamic>.from(peerRows.first as Map);
        final profile = peer['profiles'];
        if (profile is Map) {
          peerName = profile['display_name'] as String?;
          peerRole = profile['role'] as String?;
        }
      }

      final last = await client
          .from('messages')
          .select('body')
          .eq('thread_id', thread.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      threads.add(
        thread.copyWith(
          peerName: peerName,
          peerRole: peerRole,
          lastPreview: last == null ? null : last['body'] as String?,
        ),
      );
    }
    return threads;
  }

  Future<List<ChatMessage>> fetchMessages(String threadId) async {
    final rows = await client
        .from('messages')
        .select('id, thread_id, sender_id, body, created_at')
        .eq('thread_id', threadId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((r) => ChatMessage.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String threadId,
    required String body,
  }) async {
    final uid = userId;
    if (uid == null) {
      throw StateError('Not signed in');
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message is empty');
    }
    if (trimmed.length > SupabaseConfig.maxMessageLength) {
      throw ArgumentError(
        'Message must be ${SupabaseConfig.maxMessageLength} characters or fewer',
      );
    }

    final row = await client
        .from('messages')
        .insert({
          'thread_id': threadId,
          'sender_id': uid,
          'body': trimmed,
        })
        .select('id, thread_id, sender_id, body, created_at')
        .single();

    return ChatMessage.fromJson(Map<String, dynamic>.from(row));
  }

  RealtimeChannel subscribeMessages({
    required String threadId,
    required void Function(ChatMessage message) onInsert,
  }) {
    final channel = client.channel('messages:$threadId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            onInsert(ChatMessage.fromJson(Map<String, dynamic>.from(row)));
          },
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
      opts: const RealtimeChannelConfig(self: false),
    );

    channel
        .onPresenceSync((_) {
          final names = <String>{};
          for (final entry in channel.presenceState()) {
            for (final p in entry.presences) {
              final name = p.payload['name'] as String?;
              final typing = p.payload['typing'] == true;
              if (typing && name != null && name.isNotEmpty) {
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
}
