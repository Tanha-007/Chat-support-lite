import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
  });

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(message.createdAt);
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = mine ? AppColors.bubbleMine : AppColors.bubbleTheirs;
    final fg = mine ? Colors.white : AppColors.ink;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: mine ? null : Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: fg,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: mine
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.muted,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
