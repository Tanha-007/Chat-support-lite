class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.peerName,
    this.peerRole,
    this.lastPreview,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final String? peerName;
  final String? peerRole;
  final String? lastPreview;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as String,
      title: json['title'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      peerName: json['peer_name'] as String?,
      peerRole: json['peer_role'] as String?,
      lastPreview: json['last_preview'] as String?,
    );
  }

  ChatThread copyWith({
    String? peerName,
    String? peerRole,
    String? lastPreview,
    DateTime? updatedAt,
  }) {
    return ChatThread(
      id: id,
      title: title,
      updatedAt: updatedAt ?? this.updatedAt,
      peerName: peerName ?? this.peerName,
      peerRole: peerRole ?? this.peerRole,
      lastPreview: lastPreview ?? this.lastPreview,
    );
  }
}
