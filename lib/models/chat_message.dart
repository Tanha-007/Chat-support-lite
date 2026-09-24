enum DeliveryState { sent, sending, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.hidden = false,
    this.delivery = DeliveryState.sent,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool hidden;
  final DeliveryState delivery;

  bool get isLocal => id.startsWith('local-');

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      hidden: json['hidden_at'] != null,
    );
  }

  ChatMessage copyWith({DeliveryState? delivery}) {
    return ChatMessage(
      id: id,
      threadId: threadId,
      senderId: senderId,
      body: body,
      createdAt: createdAt,
      hidden: hidden,
      delivery: delivery ?? this.delivery,
    );
  }
}
