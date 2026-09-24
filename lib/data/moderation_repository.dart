import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/moderation.dart';

/// Moderator only RPCs. Every function re-checks the role server side.
class ModerationRepository {
  ModerationRepository({required this.client});

  final SupabaseClient client;

  Future<ModerationStats> fetchStats() async {
    final raw = await client.rpc('moderation_stats');
    return ModerationStats.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// [status] is `open` or `all`.
  Future<List<ModerationReport>> fetchQueue({String status = 'open'}) async {
    final rows = await client.rpc(
      'moderation_queue',
      params: {'p_status': status},
    );
    return (rows as List)
        .map(
          (r) => ModerationReport.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  /// [action] is `dismiss`, `remove`, or `remove_and_mute`.
  Future<void> resolve({
    required String reportId,
    required String action,
    String? note,
  }) async {
    await client.rpc(
      'moderate_report',
      params: {'p_report': reportId, 'p_action': action, 'p_note': note},
    );
  }

  Future<List<MutedUser>> fetchMuted() async {
    final rows = await client.rpc('muted_users');
    return (rows as List)
        .map((r) => MutedUser.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> unmute(String userId) async {
    await client.rpc('unmute_user', params: {'p_user': userId});
  }

  Future<List<ModerationLogEntry>> fetchLog({int limit = 50}) async {
    final rows = await client.rpc('moderation_log', params: {'p_limit': limit});
    return (rows as List)
        .map(
          (r) =>
              ModerationLogEntry.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  RealtimeChannel subscribeReports({required void Function() onNewReport}) {
    final channel = client.channel('moderation:reports');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'message_reports',
          callback: (_) => onNewReport(),
        )
        .subscribe();
    return channel;
  }
}
