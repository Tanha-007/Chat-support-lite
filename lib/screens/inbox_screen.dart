import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_repository.dart';
import '../data/errors.dart';
import '../models/chat_thread.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/layout.dart';
import '../widgets/tag.dart';
import 'chat_screen.dart';
import 'new_thread_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    required this.repository,
    required this.profile,
    required this.onUnreadCount,
  });

  final ChatRepository repository;
  final Profile profile;
  final ValueChanged<int> onUnreadCount;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  final _search = TextEditingController();
  List<ChatThread> _threads = [];
  bool _loading = true;
  String? _error;
  int _filter = 0;
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _channel = widget.repository.subscribeInbox(onChange: _scheduleReload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _search.dispose();
    if (_channel != null) widget.repository.removeChannel(_channel!);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    try {
      final threads = await widget.repository.fetchThreads();
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loading = false;
        _error = null;
      });
      widget.onUnreadCount(threads.fold(0, (sum, t) => sum + t.unreadCount));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  List<ChatThread> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _threads.where((t) {
      if (_filter == 0 && t.isResolved) return false;
      if (_filter == 1 && !t.isResolved) return false;
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          (t.peerName ?? '').toLowerCase().contains(q) ||
          (t.lastBody ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _open(ChatThread thread) async {
    setState(() {
      _threads = [
        for (final t in _threads)
          t.id == thread.id ? t.copyWith(unreadCount: 0) : t,
      ];
    });
    widget.onUnreadCount(_threads.fold(0, (sum, t) => sum + t.unreadCount));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          repository: widget.repository,
          profile: widget.profile,
          thread: thread,
        ),
      ),
    );
    _load();
  }

  Future<void> _newThread() async {
    final thread = await Navigator.of(context).push<ChatThread>(
      MaterialPageRoute(
        builder: (_) => NewThreadScreen(repository: widget.repository),
      ),
    );
    await _load();
    if (thread == null || !mounted) return;
    final fresh = _threads.firstWhere(
      (t) => t.id == thread.id,
      orElse: () => thread,
    );
    _open(fresh);
  }

  @override
  Widget build(BuildContext context) {
    final open = _threads.where((t) => !t.isResolved).length;
    final unread = _threads.fold<int>(0, (s, t) => s + t.unreadCount);
    final learner = widget.profile.isLearner;

    return Scaffold(
      floatingActionButton: learner && _threads.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _newThread,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New conversation'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Inbox',
                meta: _loading ? 'Loading' : '$open open  ·  $unread unread',
              ),
              if (_threads.length > 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search conversations',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                ),
              FilterTabs(
                labels: const ['Open', 'Resolved', 'All'],
                index: _filter,
                onChanged: (i) => setState(() => _filter = i),
              ),
              Expanded(child: _buildList(learner)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(bool learner) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    Widget scrollable(Widget child) => RefreshIndicator(
      onRefresh: _load,
      color: AppColors.ink,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: child,
          ),
        ),
      ),
    );

    if (_error != null) {
      return scrollable(
        EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Could not load your inbox',
          subtitle: _error!,
          action: FilledButton(
            onPressed: _load,
            child: const Text('Try again'),
          ),
        ),
      );
    }

    if (_threads.isEmpty) {
      return scrollable(
        learner
            ? EmptyState(
                icon: Icons.forum_outlined,
                title: 'No conversations yet',
                subtitle: 'Pick a mentor, name your topic, and ask your first question.',
                action: FilledButton.icon(
                  onPressed: _newThread,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Start a conversation'),
                ),
              )
            : const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Your queue is clear',
                subtitle: 'When a learner opens a conversation with you it shows up here straight away.',
              ),
      );
    }

    final items = _visible;
    if (items.isEmpty) {
      return scrollable(
        EmptyState(
          icon: _search.text.isNotEmpty
              ? Icons.search_off_rounded
              : Icons.check_rounded,
          title: _search.text.isNotEmpty
              ? 'No matches'
              : (_filter == 1 ? 'Nothing resolved yet' : 'All caught up'),
          subtitle: _search.text.isNotEmpty
              ? 'Try a mentor name or a word from the topic.'
              : (_filter == 1
                    ? 'Conversations you mark as resolved move here.'
                    : 'Every conversation is resolved. Check the Resolved tab for history.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.ink,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(indent: 76),
        itemBuilder: (context, i) => _ThreadRow(
          thread: items[i],
          myId: widget.profile.id,
          onTap: () => _open(items[i]),
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({
    required this.thread,
    required this.myId,
    required this.onTap,
  });

  final ChatThread thread;
  final String myId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = thread;
    final unread = t.unreadCount > 0;
    final peer = t.peerName ?? 'Waiting for mentor';

    String preview;
    if (t.lastBody == null) {
      preview = 'No messages yet';
    } else if (t.lastHidden) {
      preview = 'Message removed by a moderator';
    } else {
      preview = (t.lastSenderId == myId ? 'You: ' : '') + t.lastBody!;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(name: peer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          peer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body(
                            13,
                            color: AppColors.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (t.isResolved)
                        Tag.resolved()
                      else
                        Tag.role(t.peerRole),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(
                      16,
                      weight: unread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppType.body(
                          14,
                          color: unread ? AppColors.ink : AppColors.muted,
                        ).copyWith(
                          fontStyle: t.lastHidden ? FontStyle.italic : null,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  shortStamp(t.lastAt ?? t.updatedAt),
                  style: AppType.mono(
                    11,
                    color: unread ? AppColors.signal : AppColors.faint,
                  ),
                ),
                const SizedBox(height: 8),
                if (unread)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.signal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t.unreadCount > 99 ? '99+' : '${t.unreadCount}',
                      textAlign: TextAlign.center,
                      style: AppType.mono(
                        11,
                        color: Colors.white,
                        weight: FontWeight.w700,
                        spacing: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
