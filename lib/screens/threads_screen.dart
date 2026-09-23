import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/chat_repository.dart';
import '../models/chat_thread.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'chat_screen.dart';

class ThreadsScreen extends StatefulWidget {
  const ThreadsScreen({
    super.key,
    required this.repository,
    required this.profile,
    required this.onSignOut,
  });

  final ChatRepository repository;
  final Profile profile;
  final Future<void> Function() onSignOut;

  @override
  State<ThreadsScreen> createState() => _ThreadsScreenState();
}

class _ThreadsScreenState extends State<ThreadsScreen> {
  late Future<List<ChatThread>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchThreads();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.repository.fetchThreads();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deskline'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Signed in as ${widget.profile.displayName} (${widget.profile.role})',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<List<ChatThread>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          title: 'Could not load threads',
                          subtitle: snapshot.error.toString(),
                          icon: Icons.error_outline,
                        ),
                      ],
                    );
                  }
                  final threads = snapshot.data ?? [];
                  if (threads.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          title: 'No conversations yet',
                          subtitle:
                              'Ask an admin to seed a learner mentor thread, then pull to refresh.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: threads.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final t = threads[index];
                      final when = DateFormat.MMMd().add_jm().format(t.updatedAt);
                      return Material(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ChatScreen(
                                  repository: widget.repository,
                                  profile: widget.profile,
                                  thread: t,
                                ),
                              ),
                            );
                            await _reload();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      AppColors.sky.withValues(alpha: 0.15),
                                  foregroundColor: AppColors.sky,
                                  child: Text(
                                    () {
                                      final label =
                                          (t.peerName ?? t.title).trim();
                                      if (label.isEmpty) return '?';
                                      return label.substring(0, 1).toUpperCase();
                                    }(),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        t.peerName == null
                                            ? (t.lastPreview ?? 'Open chat')
                                            : '${t.peerName} · ${t.lastPreview ?? 'Say hello'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  when,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
