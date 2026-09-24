class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.status,
    required this.updatedAt,
    this.peerId,
    this.peerName,
    this.peerRole,
    this.peerHeadline,
    this.lastBody,
    this.lastSenderId,
    this.lastAt,
    this.lastHidden = false,
    this.unreadCount = 0,
  });

  final String id;
  final String title;
  final String status;
  final DateTime updatedAt;
  final String? peerId;
  final String? peerName;
  final String? peerRole;
  final String? peerHeadline;
  final String? lastBody;
  final String? lastSenderId;
  final DateTime? lastAt;
  final bool lastHidden;
  final int unreadCount;

  bool get isResolved => status == 'resolved';

  /// Row shape returned by the `my_threads()` RPC.
  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final lastAt = json['last_at'] as String?;
    return ChatThread(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String? ?? 'open',
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      peerId: json['peer_id'] as String?,
      peerName: json['peer_name'] as String?,
      peerRole: json['peer_role'] as String?,
      peerHeadline: json['peer_headline'] as String?,
      lastBody: json['last_body'] as String?,
      lastSenderId: json['last_sender_id'] as String?,
      lastAt: lastAt == null ? null : DateTime.parse(lastAt).toLocal(),
      lastHidden: json['last_hidden'] as bool? ?? false,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  ChatThread copyWith({String? status, int? unreadCount}) {
    return ChatThread(
      id: id,
      title: title,
      status: status ?? this.status,
      updatedAt: updatedAt,
      peerId: peerId,
      peerName: peerName,
      peerRole: peerRole,
      peerHeadline: peerHeadline,
      lastBody: lastBody,
      lastSenderId: lastSenderId,
      lastAt: lastAt,
      lastHidden: lastHidden,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
