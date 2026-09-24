import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/supabase_config.dart';
import '../theme/app_theme.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
    this.ready = true,
    this.focusNode,
    this.disabledHint,
  });

  final TextEditingController controller;
  final bool enabled;

  /// When false the field stays editable but sending waits.
  final bool ready;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final FocusNode? focusNode;

  /// Placeholder shown when [enabled] is false.
  final String? disabledHint;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focus.onKeyEvent = _onKey;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    if (widget.focusNode == null) {
      _focus.dispose();
    } else {
      _focus.onKeyEvent = null;
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _canSend {
    final text = widget.controller.text.trim();
    return widget.enabled &&
        widget.ready &&
        text.isNotEmpty &&
        text.length <= SupabaseConfig.maxMessageLength;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      if (_canSend) widget.onSend();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final length = widget.controller.text.trim().length;
    final over = length > SupabaseConfig.maxMessageLength;
    final showCounter = length >= SupabaseConfig.counterThreshold;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: widget.onChanged,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          SupabaseConfig.maxMessageLength + 50,
                        ),
                      ],
                      style: AppType.body(15.5),
                      decoration: InputDecoration(
                        hintText: widget.enabled
                            ? 'Write a message'
                            : (widget.disabledHint ?? 'Messaging is off'),
                        fillColor: AppColors.paper,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.lineStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SendButton(enabled: _canSend, onPressed: widget.onSend),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                child: showCounter
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6, right: 56),
                        child: Text(
                          over
                              ? '$length / ${SupabaseConfig.maxMessageLength}  ·  '
                                    'trim ${length - SupabaseConfig.maxMessageLength} to send'
                              : '$length / ${SupabaseConfig.maxMessageLength}',
                          textAlign: TextAlign.right,
                          style: AppType.mono(
                            11,
                            color: over ? AppColors.danger : AppColors.muted,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Send (Enter)',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: enabled ? AppColors.signal : AppColors.sunken,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: Icon(
              Icons.arrow_upward_rounded,
              size: 22,
              color: enabled ? Colors.white : AppColors.faint,
              semanticLabel: 'Send message',
            ),
          ),
        ),
      ),
    );
  }
}
