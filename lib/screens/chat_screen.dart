import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/chat_repository.dart';
import '../data/errors.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/layout.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';
import '../widgets/report_sheet.dart';
import '../widgets/tag.dart';
import '../widgets/typing_dots.dart';

const _groupGap = Duration(minutes: 5);

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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];

  RealtimeChannel? _channel;
  RealtimeChannel? _typingChannel;
  Timer? _typingStop;
  Timer? _readDebounce;
  bool _typingSent = false;
  DateTime? _lastSendAt;
  int _localSeq = 0;

  bool _loading = true;
  String? _error;
  bool _live = false;
  bool _joinedOnce = false;
  late String _status = widget.thread.status;
  DateTime? _peerLastRead;
  List<String> _typingNames = [];
  String? _mutedNotice;
  bool _showJump = false;
  int _unseenBelow = 0;

  String get _me => widget.profile.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.profile.isMuted) {
      _mutedNotice =
          'You are muted until ${clockTime(widget.profile.mutedUntil!)}. You can read but not send.';
    }
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingStop?.cancel();
    _readDebounce?.cancel();
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    if (_channel != null) widget.repository.removeChannel(_channel!);
    if (_typingChannel != null) {
      widget.repository.removeChannel(_typingChannel!);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _resync();
  }

  // -- Loading and realtime ---------------------------------------------------

  Future<void> _bootstrap() async {
    final threadId = widget.thread.id;

    // Subscribe before fetching so nothing lands in the gap.
    _channel = widget.repository.subscribeThread(
      threadId: threadId,
      onInsert: _onRemoteInsert,
      onUpdate: _onRemoteUpdate,
      onRead: (uid, at) {
        if (uid != _me && mounted) setState(() => _peerLastRead = at);
      },
      onStatus: (s) {
        if (mounted) setState(() => _status = s);
      },
      onState: (s) {
        if (!mounted) return;
        final live = s == RealtimeSubscribeStatus.subscribed;
        setState(() => _live = live);
        if (live && _joinedOnce) _resync();
        if (live) _joinedOnce = true;
      },
    );

    await _resync(initial: true);

    _typingChannel = widget.repository.subscribeTyping(
      threadId: threadId,
      displayName: widget.profile.displayName,
      onTyping: (names) {
        if (mounted) setState(() => _typingNames = names);
      },
    );
  }

  Future<void> _resync({bool initial = false}) async {
    try {
      final results = await Future.wait([
        widget.repository.fetchMessages(widget.thread.id),
        widget.repository.fetchPeerLastRead(widget.thread.id),
        widget.repository.fetchThreadStatus(widget.thread.id),
      ]);
      if (!mounted) return;
      final history = results[0] as List<ChatMessage>;
      setState(() {
        final pending = _messages.where((m) => m.isLocal).toList();
        final byId = {
          for (final m in _messages.where((m) => !m.isLocal)) m.id: m,
        };
        for (final m in history) {
          byId[m.id] = m;
        }
        _messages
          ..clear()
          ..addAll(
            byId.values.toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
          )
          ..addAll(pending);
        _peerLastRead = results[1] as DateTime?;
        _status = results[2] as String;
        _loading = false;
        _error = null;
      });
      _markRead();
    } catch (e) {
      if (!mounted) return;
      if (initial || _messages.isEmpty) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  void _onRemoteInsert(ChatMessage msg) {
    if (!mounted) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() {
      if (msg.senderId == _me) {
        final local = _messages.indexWhere(
          (m) => m.isLocal && m.body == msg.body,
        );
        if (local >= 0) {
          _messages[local] = msg;
          return;
        }
      }
      _messages.add(msg);
      if (msg.senderId != _me && _showJump) _unseenBelow++;
    });
    if (msg.senderId != _me) _markRead();
  }

  void _onRemoteUpdate(ChatMessage msg) {
    if (!mounted) return;
    final i = _messages.indexWhere((m) => m.id == msg.id);
    if (i < 0) return;
    setState(() => _messages[i] = msg);
  }

  void _markRead() {
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 500), () {
      widget.repository.markRead(widget.thread.id).catchError((_) {});
    });
  }

  // -- Scrolling ----------------------------------------------------------------

  void _onScroll() {
    final away = _scroll.hasClients && _scroll.offset > 240;
    if (away != _showJump) {
      setState(() {
        _showJump = away;
        if (!away) _unseenBelow = 0;
      });
    }
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  // -- Typing -------------------------------------------------------------------

  void _onComposerChanged(String value) {
    final channel = _typingChannel;
    if (channel == null) return;
    final typing = value.trim().isNotEmpty;
    if (typing != _typingSent) {
      _typingSent = typing;
      widget.repository
          .setTyping(
            channel: channel,
            displayName: widget.profile.displayName,
            typing: typing,
          )
          .catchError((_) {});
    }
    _typingStop?.cancel();
    if (typing) {
      _typingStop = Timer(const Duration(seconds: 3), _stopTyping);
    }
  }

  void _stopTyping() {
    final channel = _typingChannel;
    if (channel == null || !_typingSent) return;
    _typingSent = false;
    widget.repository
        .setTyping(
          channel: channel,
          displayName: widget.profile.displayName,
          typing: false,
        )
        .catchError((_) {});
  }

  // -- Sending ------------------------------------------------------------------

  Future<void> _send() async {
    final text = _composer.text.trim();
    final problem = ChatRepository.validateMessage(text);
    if (problem != null) {
      _toast(problem);
      return;
    }
    final now = DateTime.now();
    if (_lastSendAt != null &&
        now.difference(_lastSendAt!) < SupabaseConfig.sendCooldown) {
      _toast('Slow down a moment before sending again.');
      return;
    }
    _lastSendAt = now;
    _composer.clear();
    _typingStop?.cancel();
    _stopTyping();
    _composerFocus.requestFocus();
    await _deliver(text);
  }

  Future<void> _deliver(String text) async {
    final local = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}-${_localSeq++}',
      threadId: widget.thread.id,
      senderId: _me,
      body: text,
      createdAt: DateTime.now(),
      delivery: DeliveryState.sending,
    );
    setState(() => _messages.add(local));
    _jumpToLatest();

    try {
      final sent = await widget.repository.sendMessage(
        threadId: widget.thread.id,
        body: text,
      );
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == local.id);
        final echoed = _messages.any((m) => m.id == sent.id);
        if (i >= 0) {
          if (echoed) {
            _messages.removeAt(i);
          } else {
            _messages[i] = sent;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      final hint = errorHint(e);
      setState(() {
        final i = _messages.indexWhere((m) => m.id == local.id);
        if (i < 0) return;
        if (hint == 'muted' || hint == 'duplicate') {
          _messages.removeAt(i);
        } else {
          _messages[i] = local.copyWith(delivery: DeliveryState.failed);
        }
        if (hint == 'muted') _mutedNotice = friendlyError(e);
      });
      if (hint == 'duplicate' && _composer.text.isEmpty) {
        _composer.text = text;
      }
      _toast(friendlyError(e));
    }
  }

  void _retry(ChatMessage failed) {
    setState(() => _messages.removeWhere((m) => m.id == failed.id));
    _deliver(failed.body);
  }

  // -- Actions ------------------------------------------------------------------

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _setStatus(String status) async {
    final previous = _status;
    setState(() => _status = status);
    try {
      await widget.repository.setThreadStatus(widget.thread.id, status);
      _toast(
        status == 'resolved'
            ? 'Marked resolved. A new message will reopen it.'
            : 'Conversation reopened.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = previous);
      _toast(friendlyError(e));
    }
  }

  Future<void> _messageMenu(ChatMessage msg) async {
    final mine = msg.senderId == _me;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.delivery == DeliveryState.failed)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Try sending again'),
                onTap: () => Navigator.pop(context, 'retry'),
              ),
            if (msg.delivery == DeliveryState.failed)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Discard'),
                onTap: () => Navigator.pop(context, 'discard'),
              ),
            if (!msg.hidden)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy text'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            if (!mine && !msg.hidden && !msg.isLocal)
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.danger,
                ),
                title: Text(
                  'Report message',
                  style: AppType.body(16, color: AppColors.danger),
                ),
                onTap: () => Navigator.pop(context, 'report'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'retry':
        _retry(msg);
      case 'discard':
        setState(() => _messages.removeWhere((m) => m.id == msg.id));
      case 'copy':
        await Clipboard.setData(ClipboardData(text: msg.body));
        _toast('Copied');
      case 'report':
        final filed = await showReportSheet(
          context,
          quote: msg.body,
          onSubmit: (c) => widget.repository.reportMessage(
            messageId: msg.id,
            reason: c.reason,
            note: c.note,
          ),
        );
        if (filed) _toast('Thanks. A moderator will review it.');
    }
  }

  void _showDetails() {
    final t = widget.thread;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOPIC', style: AppType.mono(11, spacing: 1.2)),
              const SizedBox(height: 4),
              Text(t.title, style: AppType.heading(20)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Avatar(name: t.peerName ?? '?', size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.peerName ?? 'Unknown',
                          style: AppType.body(16, weight: FontWeight.w600),
                        ),
                        if (t.peerHeadline != null)
                          Text(
                            t.peerHeadline!,
                            style: AppType.body(13, color: AppColors.muted),
                          ),
                      ],
                    ),
                  ),
                  Tag.role(t.peerRole),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Only the two of you can read this conversation. '
                'Messages are capped at ${SupabaseConfig.maxMessageLength} characters. '
                'Long press any message to copy or report it.',
                style: AppType.body(13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Build --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    final resolved = _status == 'resolved';
    final peer = t.peerName ?? 'Conversation';

    return Scaffold(
      appBar: AppBar(
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
        title: InkWell(
          onTap: _showDetails,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Avatar(name: peer, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(16, weight: FontWeight.w600),
                      ),
                      Text(
                        _typingNames.isNotEmpty ? 'typing' : t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.mono(
                          11,
                          color: _typingNames.isNotEmpty
                              ? AppColors.signal
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Conversation options',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (v) {
              if (v == 'resolve') _setStatus('resolved');
              if (v == 'reopen') _setStatus('open');
              if (v == 'details') _showDetails();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: resolved ? 'reopen' : 'resolve',
                child: Text(
                  resolved ? 'Reopen conversation' : 'Mark as resolved',
                ),
              ),
              const PopupMenuItem(
                value: 'details',
                child: Text('Conversation details'),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (!_loading && _error == null && !_live && _joinedOnce)
            const Notice(
              icon: Icons.sync_rounded,
              text: 'Reconnecting to live updates',
              background: AppColors.amberSoft,
              foreground: AppColors.amber,
            ),
          if (resolved)
            Notice(
              icon: Icons.check_circle_outline_rounded,
              text: 'Marked resolved. Sending a message reopens it.',
              background: AppColors.sageSoft,
              foreground: AppColors.sage,
              action: TextButton(
                onPressed: () => _setStatus('open'),
                style: TextButton.styleFrom(foregroundColor: AppColors.sage),
                child: const Text('Reopen'),
              ),
            ),
          if (_mutedNotice != null)
            Notice(
              icon: Icons.volume_off_outlined,
              text: _mutedNotice!,
              background: AppColors.dangerSoft,
              foreground: AppColors.danger,
            ),
          Expanded(child: _buildMessages()),
          MaxWidth(
            width: 820,
            child: MessageComposer(
              controller: _composer,
              focusNode: _composerFocus,
              enabled: _error == null && _mutedNotice == null,
              ready: !_loading,
              disabledHint: _mutedNotice != null
                  ? 'You are muted'
                  : 'Messaging is unavailable',
              onChanged: _onComposerChanged,
              onSend: _send,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not open this conversation',
        subtitle: _error!,
        action: FilledButton(
          onPressed: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _resync(initial: true);
          },
          child: const Text('Try again'),
        ),
      );
    }
    if (_messages.isEmpty && _typingNames.isEmpty) {
      return EmptyState(
        icon: Icons.waving_hand_outlined,
        title: 'Say hello',
        subtitle: widget.profile.isLearner
            ? 'Describe what you are working on. ${widget.thread.peerName ?? 'Your mentor'} sees it the moment you send.'
            : 'Introduce yourself and ask what they need help with.',
      );
    }

    final items = _buildItems();
    return Stack(
      children: [
        MaxWidth(
          width: 820,
          child: ListView.builder(
            controller: _scroll,
            reverse: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            itemCount: items.length,
            itemBuilder: (context, i) => items[i],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 12,
          child: AnimatedScale(
            scale: _showJump ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Material(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _jumpToLatest,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_unseenBelow > 0) ...[
                        Text(
                          '$_unseenBelow new',
                          style: AppType.mono(
                            11,
                            color: AppColors.card,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const Icon(
                        Icons.arrow_downward_rounded,
                        size: 16,
                        color: AppColors.card,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Newest first, for a reversed list.
  List<Widget> _buildItems() {
    final out = <Widget>[];
    final msgs = _messages;

    String? lastMineId;
    for (var i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].senderId == _me && !msgs[i].isLocal) {
        lastMineId = msgs[i].id;
        break;
      }
    }

    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final prev = i > 0 ? msgs[i - 1] : null;
      final next = i < msgs.length - 1 ? msgs[i + 1] : null;
      final newDay = prev == null || !isSameDay(prev.createdAt, m.createdAt);
      final first =
          newDay ||
          prev.senderId != m.senderId ||
          m.createdAt.difference(prev.createdAt) > _groupGap;
      final last =
          next == null ||
          next.senderId != m.senderId ||
          !isSameDay(next.createdAt, m.createdAt) ||
          next.createdAt.difference(m.createdAt) > _groupGap;
      final mine = m.senderId == _me;

      String? receipt;
      if (m.id == lastMineId) {
        final seen =
            _peerLastRead != null && !_peerLastRead!.isBefore(m.createdAt);
        receipt = seen ? 'Seen' : 'Sent';
      }

      if (newDay) out.add(DayDivider(label: dayLabel(m.createdAt)));
      out.add(
        MessageBubble(
          key: ValueKey(m.id),
          message: m,
          mine: mine,
          firstInGroup: first,
          lastInGroup: last || receipt != null,
          receipt: receipt,
          onLongPress: () => _messageMenu(m),
          onRetry: () => _retry(m),
        ),
      );
    }

    final reversed = out.reversed.toList();
    if (_typingNames.isNotEmpty) {
      final label = _typingNames.length == 1
          ? '${_typingNames.first} is typing'
          : '${_typingNames.length} people are typing';
      reversed.insert(0, TypingDots(label: label));
    }
    return reversed;
  }
}
