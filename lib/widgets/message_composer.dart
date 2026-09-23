import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/supabase_config.dart';
import '../theme/app_theme.dart';

class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final remaining =
        SupabaseConfig.maxMessageLength - controller.text.length;
    final over = remaining < 0;

    return Material(
      color: AppColors.paper,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled && !sending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      onChanged: onChanged,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          SupabaseConfig.maxMessageLength + 20,
                        ),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: (!enabled || sending || over) ? null : onSend,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                over
                    ? '${-remaining} over the ${SupabaseConfig.maxMessageLength} character limit'
                    : '$remaining left',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: over ? AppColors.danger : AppColors.muted,
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
