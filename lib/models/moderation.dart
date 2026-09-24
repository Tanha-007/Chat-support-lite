DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.parse(raw as String).toLocal();

class ModerationStats {
  const ModerationStats({
    required this.openReports,
    required this.actions24h,
    required this.mutedUsers,
    required this.messages24h,
    required this.activeThreads24h,
    required this.openThreads,
    required this.learners,
    required this.mentors,
  });

  final int openReports;
  final int actions24h;
  final int mutedUsers;
  final int messages24h;
  final int activeThreads24h;
  final int openThreads;
  final int learners;
  final int mentors;

  factory ModerationStats.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ModerationStats(
      openReports: n('open_reports'),
      actions24h: n('actions_24h'),
      mutedUsers: n('muted_users'),
      messages24h: n('messages_24h'),
      activeThreads24h: n('active_threads_24h'),
      openThreads: n('open_threads'),
      learners: n('learners'),
      mentors: n('mentors'),
    );
  }
}

class ContextLine {
  const ContextLine({
    required this.sender,
    required this.body,
    required this.createdAt,
    required this.reported,
  });

  final String sender;
  final String body;
  final DateTime createdAt;
  final bool reported;

  factory ContextLine.fromJson(Map<String, dynamic> json) {
    return ContextLine(
      sender: json['sender'] as String? ?? 'Member',
      body: json['body'] as String? ?? '',
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      reported: json['reported'] == true,
    );
  }
}

class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.reason,
    required this.status,
    required this.reportedAt,
    required this.reportCount,
    required this.messageId,
    required this.messageBody,
    required this.messageAt,
    required this.messageHidden,
    required this.threadTitle,
    required this.reporterName,
    required this.reportedUserId,
    required this.reportedName,
    required this.reportedRole,
    required this.context,
    this.note,
    this.reportedMutedUntil,
  });

  final String id;
  final String reason;
  final String status;
  final DateTime reportedAt;
  final int reportCount;
  final String messageId;
  final String messageBody;
  final DateTime messageAt;
  final bool messageHidden;
  final String threadTitle;
  final String reporterName;
  final String reportedUserId;
  final String reportedName;
  final String reportedRole;
  final List<ContextLine> context;
  final String? note;
  final DateTime? reportedMutedUntil;

  bool get isOpen => status == 'open';
  bool get reportedIsMuted =>
      reportedMutedUntil != null && reportedMutedUntil!.isAfter(DateTime.now());

  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    final ctx = json['context'];
    return ModerationReport(
      id: json['report_id'] as String,
      reason: json['reason'] as String,
      note: json['note'] as String?,
      status: json['status'] as String,
      reportedAt: _date(json['reported_at'])!,
      reportCount: (json['report_count'] as num?)?.toInt() ?? 1,
      messageId: json['message_id'] as String,
      messageBody: json['message_body'] as String? ?? '',
      messageAt: _date(json['message_at'])!,
      messageHidden: json['message_hidden'] == true,
      threadTitle: json['thread_title'] as String? ?? '',
      reporterName: json['reporter_name'] as String? ?? 'Member',
      reportedUserId: json['reported_user_id'] as String,
      reportedName: json['reported_name'] as String? ?? 'Member',
      reportedRole: json['reported_role'] as String? ?? 'learner',
      reportedMutedUntil: _date(json['reported_muted_until']),
      context: ctx is List
          ? ctx
                .map(
                  (e) =>
                      ContextLine.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList()
          : const [],
    );
  }
}

class MutedUser {
  const MutedUser({
    required this.id,
    required this.displayName,
    required this.role,
    required this.mutedUntil,
  });

  final String id;
  final String displayName;
  final String role;
  final DateTime mutedUntil;

  factory MutedUser.fromJson(Map<String, dynamic> json) {
    return MutedUser(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Member',
      role: json['role'] as String? ?? 'learner',
      mutedUntil: _date(json['muted_until'])!,
    );
  }
}

class ModerationLogEntry {
  const ModerationLogEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    this.moderatorName,
    this.targetName,
    this.originalBody,
    this.note,
  });

  final String id;
  final String action;
  final DateTime createdAt;
  final String? moderatorName;
  final String? targetName;
  final String? originalBody;
  final String? note;

  factory ModerationLogEntry.fromJson(Map<String, dynamic> json) {
    return ModerationLogEntry(
      id: json['id'] as String,
      action: json['action'] as String,
      createdAt: _date(json['created_at'])!,
      moderatorName: json['moderator_name'] as String?,
      targetName: json['target_name'] as String?,
      originalBody: json['original_body'] as String?,
      note: json['note'] as String?,
    );
  }
}
