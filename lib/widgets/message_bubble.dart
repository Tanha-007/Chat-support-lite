import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.firstInGroup = true,
    this.lastInGroup = true,
    this.receipt,
    this.onLongPress,
    this.onRetry,
  });

  final ChatMessage message;
  final bool mine;
  final bool firstInGroup;
  final bool lastInGroup;

  /// "Seen" or "Sent" under the latest outgoing message.
  final String? receipt;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = message.delivery == DeliveryState.failed;
    final sending = message.delivery == DeliveryState.sending;
    final hidden = message.hidden;

    final Color bg;
    final Color fg;
    Border? border;
    if (hidden) {
      bg = Colors.transparent;
      fg = AppColors.muted;
      border = Border.all(color: AppColors.lineStrong);
    } else if (mine) {
      bg = failed ? AppColors.dangerSoft : AppColors.ink;
      fg = failed ? AppColors.danger : AppColors.card;
    } else {
      bg = AppColors.card;
      fg = AppColors.ink;
      border = Border.all(color: AppColors.line);
    }

    const big = Radius.circular(18);
    const small = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: !mine && !firstInGroup ? small : big,
      topRight: mine && !firstInGroup ? small : big,
      bottomLeft: !mine && !lastInGroup ? small : (mine ? big : small),
      bottomRight: mine && !lastInGroup ? small : (mine ? small : big),
    );

    final meta = <String>[
      if (lastInGroup || failed || sending) clockTime(message.createdAt),
      if (sending) 'Sending',
      if (failed) 'Not sent. Tap to retry',
      if (!sending && !failed && receipt != null) receipt!,
    ];

    return Padding(
      padding: EdgeInsets.only(top: firstInGroup ? 10 : 2),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.8),
              child: GestureDetector(
                onLongPress: onLongPress,
                onSecondaryTap: onLongPress,
                onTap: failed ? onRetry : onLongPress,
                child: AnimatedOpacity(
                  opacity: sending ? 0.6 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: radius,
                      border: border,
                    ),
                    child: hidden
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.block_rounded,
                                size: 15,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Removed by a moderator',
                                  style: AppType.body(
                                    14,
                                    color: fg,
                                  ).copyWith(fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            message.body,
                            style: AppType.body(15.5, color: fg, height: 1.4),
                          ),
                  ),
                ),
              ),
            ),
          ),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                meta.join('  ·  '),
                style: AppType.mono(
                  10.5,
                  color: failed ? AppColors.danger : AppColors.faint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DayDivider extends StatelessWidget {
  const DayDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label.toUpperCase(),
              style: AppType.mono(10.5, spacing: 1.2),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
