import 'package:chat_support_lite/config/supabase_config.dart';
import 'package:chat_support_lite/data/chat_repository.dart';
import 'package:chat_support_lite/data/errors.dart';
import 'package:chat_support_lite/models/chat_message.dart';
import 'package:chat_support_lite/models/chat_thread.dart';
import 'package:chat_support_lite/models/moderation.dart';
import 'package:chat_support_lite/models/profile.dart';
import 'package:chat_support_lite/util/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('message validation', () {
    test('rejects empty and whitespace', () {
      expect(ChatRepository.validateMessage(''), isNotNull);
      expect(ChatRepository.validateMessage('   \n  '), isNotNull);
    });

    test('accepts up to the cap after trimming', () {
      final atCap = 'a' * SupabaseConfig.maxMessageLength;
      expect(ChatRepository.validateMessage(atCap), isNull);
      expect(ChatRepository.validateMessage('  $atCap  '), isNull);
    });

    test('rejects over the cap', () {
      final over = 'a' * (SupabaseConfig.maxMessageLength + 1);
      expect(ChatRepository.validateMessage(over), contains('500'));
    });

    test('cap mirrors the database constraint', () {
      expect(SupabaseConfig.maxMessageLength, 500);
    });
  });

  group('friendlyError', () {
    test('passes through guard messages from SQL', () {
      const e = PostgrestException(
        message: 'Too many messages. Wait a few seconds and try again.',
        code: 'P0001',
        hint: 'rate_limited',
      );
      expect(friendlyError(e), startsWith('Too many messages'));
      expect(errorHint(e), 'rate_limited');
    });

    test('maps check violations and RLS denials', () {
      expect(
        friendlyError(const PostgrestException(message: 'x', code: '23514')),
        'That text is empty or too long.',
      );
      expect(
        friendlyError(const PostgrestException(message: 'x', code: '42501')),
        'You do not have access to that.',
      );
    });

    test('maps bad credentials', () {
      expect(
        friendlyError(const AuthException('Invalid login credentials')),
        'Email or password is incorrect.',
      );
    });

    test('maps network failures', () {
      expect(
        friendlyError(Exception('ClientException: Failed host lookup')),
        contains('Network problem'),
      );
    });
  });

  group('models', () {
    test('ChatThread parses my_threads rows', () {
      final t = ChatThread.fromJson({
        'id': 't1',
        'title': 'Fractions',
        'status': 'resolved',
        'updated_at': '2026-09-24T10:00:00Z',
        'peer_id': 'u2',
        'peer_name': 'Noah Kim',
        'peer_role': 'mentor',
        'last_body': 'Hi',
        'last_sender_id': 'u2',
        'last_at': '2026-09-24T10:00:00Z',
        'last_hidden': false,
        'unread_count': 3,
      });
      expect(t.isResolved, isTrue);
      expect(t.unreadCount, 3);
      expect(t.copyWith(unreadCount: 0).unreadCount, 0);
      expect(t.copyWith(unreadCount: 0).peerName, 'Noah Kim');
    });

    test('ChatMessage marks hidden and local ids', () {
      final m = ChatMessage.fromJson({
        'id': 'm1',
        'thread_id': 't1',
        'sender_id': 'u1',
        'body': 'Removed by a moderator.',
        'created_at': '2026-09-24T10:00:00Z',
        'hidden_at': '2026-09-24T10:05:00Z',
      });
      expect(m.hidden, isTrue);
      expect(m.isLocal, isFalse);
      final local = ChatMessage(
        id: 'local-1',
        threadId: 't1',
        senderId: 'u1',
        body: 'x',
        createdAt: DateTime.now(),
        delivery: DeliveryState.sending,
      );
      expect(local.isLocal, isTrue);
      expect(
        local.copyWith(delivery: DeliveryState.failed).delivery,
        DeliveryState.failed,
      );
    });

    test('Profile knows roles and mute state', () {
      final muted = Profile.fromJson({
        'id': 'u1',
        'display_name': 'Ava',
        'role': 'learner',
        'muted_until': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      });
      expect(muted.isLearner, isTrue);
      expect(muted.isMuted, isTrue);

      final expired = Profile.fromJson({
        'id': 'u2',
        'display_name': 'Sam',
        'role': 'moderator',
        'muted_until': '2020-01-01T00:00:00Z',
      });
      expect(expired.isModerator, isTrue);
      expect(expired.isMuted, isFalse);
    });

    test('ModerationReport parses queue rows with context', () {
      final r = ModerationReport.fromJson({
        'report_id': 'r1',
        'reason': 'spam',
        'note': null,
        'status': 'open',
        'reported_at': '2026-09-24T10:00:00Z',
        'report_count': 2,
        'message_id': 'm1',
        'message_body': 'Buy now',
        'message_at': '2026-09-24T09:59:00Z',
        'message_hidden': false,
        'thread_id': 't1',
        'thread_title': 'Fractions',
        'reporter_name': 'Noah Kim',
        'reported_user_id': 'u1',
        'reported_name': 'Ava Brooks',
        'reported_role': 'learner',
        'reported_muted_until': null,
        'context': [
          {
            'sender': 'Noah Kim',
            'body': 'Hello',
            'created_at': '2026-09-24T09:58:00Z',
            'reported': false,
          },
          {
            'sender': 'Ava Brooks',
            'body': 'Buy now',
            'created_at': '2026-09-24T09:59:00Z',
            'reported': true,
          },
        ],
      });
      expect(r.isOpen, isTrue);
      expect(r.reportCount, 2);
      expect(r.context.where((c) => c.reported).single.body, 'Buy now');
      expect(r.reportedIsMuted, isFalse);
    });

    test('ModerationStats tolerates missing keys', () {
      final s = ModerationStats.fromJson({'open_reports': 4});
      expect(s.openReports, 4);
      expect(s.mentors, 0);
    });
  });

  group('format', () {
    final now = DateTime(2026, 9, 24, 15, 0);

    test('day labels', () {
      expect(dayLabel(DateTime(2026, 9, 24, 9), now: now), 'Today');
      expect(dayLabel(DateTime(2026, 9, 23, 9), now: now), 'Yesterday');
      expect(
        dayLabel(DateTime(2026, 9, 1, 9), now: now),
        contains('September'),
      );
    });

    test('short stamps', () {
      expect(shortStamp(DateTime(2026, 9, 23, 9), now: now), 'Yesterday');
      expect(shortStamp(DateTime(2026, 8, 1), now: now), 'Aug 1');
    });

    test('relative and remaining time', () {
      expect(
        relativeAgo(now.subtract(const Duration(seconds: 10)), now: now),
        'just now',
      );
      expect(
        relativeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
      expect(
        timeLeft(now.add(const Duration(hours: 23, minutes: 30)), now: now),
        '23h left',
      );
      expect(
        timeLeft(now.subtract(const Duration(minutes: 1)), now: now),
        'expired',
      );
    });

    test('initials and role labels', () {
      expect(initialsFor('Ava Brooks'), 'AB');
      expect(initialsFor('noah'), 'N');
      expect(initialsFor('   '), '?');
      expect(roleLabel('moderator'), 'Moderator');
      expect(roleLabel(null), 'Member');
    });
  });
}
