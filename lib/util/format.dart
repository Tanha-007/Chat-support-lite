import 'package:intl/intl.dart';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Inbox style: 14:05 today, Mon this week, Sep 12 otherwise.
String shortStamp(DateTime at, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  if (isSameDay(at, ref)) return DateFormat.jm().format(at);
  final yesterday = ref.subtract(const Duration(days: 1));
  if (isSameDay(at, yesterday)) return 'Yesterday';
  if (ref.difference(at).inDays < 7) return DateFormat.E().format(at);
  if (at.year == ref.year) return DateFormat.MMMd().format(at);
  return DateFormat.yMMMd().format(at);
}

/// Chat divider label.
String dayLabel(DateTime at, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  if (isSameDay(at, ref)) return 'Today';
  if (isSameDay(at, ref.subtract(const Duration(days: 1)))) return 'Yesterday';
  if (at.year == ref.year) return DateFormat.MMMMEEEEd().format(at);
  return DateFormat.yMMMMd().format(at);
}

String clockTime(DateTime at) => DateFormat.jm().format(at);

/// "3m ago", "2h ago", "Sep 12".
String relativeAgo(DateTime at, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(at);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.MMMd().format(at);
}

/// "in 23h", "in 40m".
String timeLeft(DateTime until, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = until.difference(ref);
  if (diff.isNegative) return 'expired';
  if (diff.inHours >= 1) return '${diff.inHours}h left';
  final m = diff.inMinutes < 1 ? 1 : diff.inMinutes;
  return '${m}m left';
}

String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  final list = parts.toList();
  final first = list.first.substring(0, 1);
  final last = list.length > 1 ? list.last.substring(0, 1) : '';
  return (first + last).toUpperCase();
}

String roleLabel(String? role) {
  switch (role) {
    case 'mentor':
      return 'Mentor';
    case 'moderator':
      return 'Moderator';
    case 'learner':
      return 'Learner';
    default:
      return 'Member';
  }
}
