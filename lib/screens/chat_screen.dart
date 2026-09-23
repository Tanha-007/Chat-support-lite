import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';
import '../widgets/typing_dots.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.repository,
    required this.profile,
    required this.thread,
  });

  final ChatRepository repository;
  final Profile profile;
  final ChatThread thread;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];

  RealtimeChannel? _messageChannel;
  RealtimeChannel? _typingChannel;
  Timer? _typingStop;
  DateTime? _lastSendAt;

  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<String> _typingNames = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final history =
          await widget.repository.fetchMessages(widget.thread.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
        _loading = false;
      });
      _scrollToEnd();

      _messageChannel = widget.repository.subscribeMessages(
        threadId: widget.thread.id,
        onInsert: (msg) {
          if (!mounted) return;
          if (_messages.any((m) => m.id == msg.id)) return;
          setState(() => _messages.add(msg));
          _scrollToEnd();
        },
      );

      _typingChannel = widget.repository.subscribeTyping(
        threadId: widget.thread.id,
        displayName: widget.profile.displayName,
        onTyping: (names) {
          if (!mounted) return;
          setState(() {
            _typingNames = names
                .where((n) => n != widget.profile.displayName)
                .toList();
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _onComposerChanged(String value) async {
    final channel = _typingChannel;
    if (channel == null) return;
    await widget.repository.setTyping(
      channel: channel,
      displayName: widget.profile.displayName,
      typing: value.trim().isNotEmpty,
    );
    _typingStop?.cancel();
    _typingStop = Timer(const Duration(seconds: 2), () async {
      await widget.repository.setTyping(
        channel: channel,
        displayName: widget.profile.displayName,
        typing: false,
      );
    });
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > SupabaseConfig.maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Keep messages to ${SupabaseConfig.maxMessageLength} characters.',
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (_lastSendAt != null &&
        now.difference(_lastSendAt!) < SupabaseConfig.sendCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slow down a moment before sending again.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final sent = await widget.repository.sendMessage(
        threadId: widget.thread.id,
        body: text,
      );
      _lastSendAt = DateTime.now();
      _composer.clear();
      if (_typingChannel != null) {
        await widget.repository.setTyping(
          channel: _typingChannel!,
          displayName: widget.profile.displayName,
          typing: false,
        );
      }
      if (!_messages.any((m) => m.id == sent.id)) {
        setState(() => _messages.add(sent));
        _scrollToEnd();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _typingStop?.cancel();
    _composer.dispose();
    _scroll.dispose();
    if (_messageChannel != null) {
      Supabase.instance.client.removeChannel(_messageChannel!);
    }
    if (_typingChannel != null) {
      Supabase.instance.client.removeChannel(_typingChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.thread.peerName == null
        ? widget.thread.title
        : '${widget.thread.peerName} · ${widget.thread.peerRole ?? 'peer'}';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.thread.title),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.mist, Color(0xFFDDE8F0)],
                ),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? EmptyState(
                          title: 'Could not open chat',
                          subtitle: _error!,
                          icon: Icons.error_outline,
                        )
                      : _messages.isEmpty
                          ? const EmptyState(
                              title: 'No messages yet',
                              subtitle:
                                  'Say hello. Your note will appear live on the other device.',
                            )
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                              itemCount:
                                  _messages.length + (_typingNames.isEmpty ? 0 : 1),
                              itemBuilder: (context, index) {
                                if (index == _messages.length) {
                                  final label = _typingNames.length == 1
                                      ? '${_typingNames.first} is typing'
                                      : 'Several people are typing';
                                  return TypingDots(label: label);
                                }
                                final msg = _messages[index];
                                return MessageBubble(
                                  message: msg,
                                  mine: msg.senderId == widget.profile.id,
                                );
                              },
                            ),
            ),
          ),
          MessageComposer(
            controller: _composer,
            enabled: !_loading && _error == null,
            sending: _sending,
            onChanged: (v) {
              setState(() {});
              _onComposerChanged(v);
            },
            onSend: _send,
          ),
        ],
      ),
    );
  }
}
