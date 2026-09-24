import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/errors.dart';
import '../data/moderation_repository.dart';
import '../models/moderation.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/layout.dart';
import '../widgets/tag.dart';

/// Moderator home: live stats, report queue, muted members, action log.
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({
    super.key,
    required this.repository,
    required this.onOpenCount,
  });

  final ModerationRepository repository;
  final ValueChanged<int> onOpenCount;

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  int _tab = 0;
  bool _showResolved = false;

  ModerationStats? _stats;
  List<ModerationReport> _queue = [];
  List<MutedUser> _muted = [];
  List<ModerationLogEntry> _log = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = widget.repository.subscribeReports(
      onNewReport: () {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () async {
          await _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('New report in the queue')),
            );
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_channel != null) widget.repository.client.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.repository.fetchStats(),
        widget.repository.fetchQueue(status: _showResolved ? 'all' : 'open'),
        widget.repository.fetchMuted(),
        widget.repository.fetchLog(),
      ]);
      if (!mounted) return;
      final stats = results[0] as ModerationStats;
      setState(() {
        _stats = stats;
        _queue = results[1] as List<ModerationReport>;
        _muted = results[2] as List<MutedUser>;
        _log = results[3] as List<ModerationLogEntry>;
        _loading = false;
        _error = null;
      });
      widget.onOpenCount(stats.openReports);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _resolve(ModerationReport r, String action) async {
    if (action == 'remove_and_mute') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Mute ${r.reportedName}?'),
          content: Text(
            'The message is removed and ${r.reportedName} cannot send messages '
            'or open conversations for 24 hours. You can unmute from the Muted tab.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove and mute'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy.add(r.id));
    try {
      await widget.repository.resolve(reportId: r.id, action: action);
      await _load();
      if (!mounted) return;
      final text = switch (action) {
        'dismiss' => 'Report dismissed',
        'remove' => 'Message removed',
        _ => 'Message removed and ${r.reportedName} muted for 24h',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _unmute(MutedUser u) async {
    setState(() => _busy.add(u.id));
    try {
      await widget.repository.unmute(u.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${u.displayName} can send messages again')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _stats?.openReports ?? 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: MaxWidth(
          width: 900,
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _error != null
              ? EmptyState(
                  icon: Icons.shield_outlined,
                  title: 'Could not load moderation data',
                  subtitle: _error!,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.ink,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: PageHeader(
                          title: 'Moderation',
                          meta: open == 0
                              ? 'Queue clear  ·  live'
                              : '$open waiting for review  ·  live',
                          trailing: IconButton(
                            tooltip: 'Refresh',
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: _StatsGrid(stats: _stats!)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: FilterTabs(
                            labels: [
                              'Queue${open > 0 ? ' ($open)' : ''}',
                              'Muted${_muted.isNotEmpty ? ' (${_muted.length})' : ''}',
                              'Log',
                            ],
                            index: _tab,
                            onChanged: (i) => setState(() => _tab = i),
                          ),
                        ),
                      ),
                      ..._buildTab(),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildTab() {
    switch (_tab) {
      case 1:
        return _buildMuted();
      case 2:
        return _buildLog();
      default:
        return _buildQueue();
    }
  }

  List<Widget> _buildQueue() {
    final toggle = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _showResolved ? 'ALL REPORTS' : 'WAITING FOR REVIEW',
                style: AppType.mono(11, spacing: 1.2, weight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _showResolved = !_showResolved);
                _load();
              },
              child: Text(
                _showResolved ? 'Show open only' : 'Include resolved',
              ),
            ),
          ],
        ),
      ),
    );

    if (_queue.isEmpty) {
      return [
        toggle,
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.verified_user_outlined,
            tone: AppColors.sageSoft,
            title: 'Nothing to review',
            subtitle: 'New reports appear here live, and the badge on the tab updates.',
          ),
        ),
      ];
    }

    return [
      toggle,
      SliverList.separated(
        itemCount: _queue.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ReportCard(
            report: _queue[i],
            busy: _busy.contains(_queue[i].id),
            onAction: (a) => _resolve(_queue[i], a),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildMuted() {
    if (_muted.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.volume_up_outlined,
            title: 'Nobody is muted',
            subtitle: 'Members you mute from the queue are listed here until the mute ends.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList.separated(
          itemCount: _muted.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final u = _muted[i];
            return Panel(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Avatar(name: u.displayName, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.displayName,
                          style: AppType.body(15, weight: FontWeight.w600),
                        ),
                        Text(
                          '${roleLabel(u.role)}  ·  ${timeLeft(u.mutedUntil)}',
                          style: AppType.mono(11),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _busy.contains(u.id) ? null : () => _unmute(u),
                    child: const Text('Unmute'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildLog() {
    if (_log.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.history_rounded,
            title: 'No actions yet',
            subtitle:
                'Every dismissal, removal, mute and unmute is recorded here.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        sliver: SliverList.builder(
          itemCount: _log.length,
          itemBuilder: (context, i) =>
              _LogRow(entry: _log[i], last: i == _log.length - 1),
        ),
      ),
    ];
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ModerationStats stats;

  @override
  Widget build(BuildContext context) {
    final cells = [
      ('Open reports', stats.openReports, stats.openReports > 0),
      ('Actions 24h', stats.actions24h, false),
      ('Muted now', stats.mutedUsers, false),
      ('Messages 24h', stats.messages24h, false),
      ('Active threads 24h', stats.activeThreads24h, false),
      ('Open threads', stats.openThreads, false),
      ('Learners', stats.learners, false),
      ('Mentors', stats.mentors, false),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 720 ? 8 : 4;
          final rows = <List<(String, int, bool)>>[
            for (var i = 0; i < cells.length; i += cols)
              cells.sublist(i, (i + cols).clamp(0, cells.length)),
          ];
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                for (var r = 0; r < rows.length; r++)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: r == 0
                          ? null
                          : const Border(
                              top: BorderSide(color: AppColors.line),
                            ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < rows[r].length; i++)
                            Expanded(
                              child: _StatCell(
                                label: rows[r][i].$1,
                                value: rows[r][i].$2,
                                alert: rows[r][i].$3,
                                divider: i > 0,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.alert,
    required this.divider,
  });

  final String label;
  final int value;
  final bool alert;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: alert ? AppColors.signalSoft : null,
        border: divider
            ? const Border(left: BorderSide(color: AppColors.line))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: AppType.display(
              22,
              color: alert ? AppColors.signal : AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.mono(9.5, spacing: 0.6).copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatefulWidget {
  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onAction,
  });

  final ModerationReport report;
  final bool busy;
  final ValueChanged<String> onAction;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _context = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Tag.reason(r.reason),
                const SizedBox(width: 6),
                if (r.reportCount > 1)
                  Tag(
                    label: '${r.reportCount} reports',
                    background: AppColors.signalSoft,
                    foreground: AppColors.signal,
                  ),
                if (!r.isOpen)
                  Tag(
                    label: r.status,
                    background: AppColors.sunken,
                    foreground: AppColors.muted,
                  ),
                const Spacer(),
                Text(relativeAgo(r.reportedAt), style: AppType.mono(11)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Avatar(name: r.reportedName, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              r.reportedName,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.body(15, weight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tag.role(r.reportedRole),
                          if (r.reportedIsMuted) ...[
                            const SizedBox(width: 6),
                            const Tag(
                              label: 'Muted',
                              background: AppColors.dangerSoft,
                              foreground: AppColors.danger,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'in "${r.threadTitle}"  ·  reported by ${r.reporterName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(12.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              border: Border(
                left: BorderSide(color: AppColors.signal, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.messageBody, style: AppType.body(15, height: 1.4)),
                const SizedBox(height: 6),
                Text(
                  '${clockTime(r.messageAt)}${r.messageHidden ? '  ·  removed from chat' : ''}',
                  style: AppType.mono(10.5),
                ),
              ],
            ),
          ),
          if (r.note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'Reporter note: ${r.note}',
                style: AppType.body(13.5, color: AppColors.inkSoft),
              ),
            ),
          if (r.context.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _context = !_context),
                  icon: Icon(
                    _context
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _context ? 'Hide context' : 'Show conversation context',
                  ),
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: _context
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Column(
                      children: [
                        for (final line in r.context)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 92,
                                  child: Text(
                                    line.sender,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.mono(
                                      11,
                                      color: line.reported
                                          ? AppColors.signal
                                          : AppColors.muted,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    line.body,
                                    style: AppType.body(
                                      13.5,
                                      color: line.reported
                                          ? AppColors.ink
                                          : AppColors.inkSoft,
                                      weight: line.reported
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 12),
          if (r.isOpen) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: widget.busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => widget.onAction('dismiss'),
                          child: const Text('Dismiss'),
                        ),
                        OutlinedButton(
                          onPressed: () => widget.onAction('remove'),
                          child: const Text('Remove message'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            minimumSize: const Size(48, 46),
                          ),
                          onPressed: () => widget.onAction('remove_and_mute'),
                          child: const Text('Remove and mute 24h'),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.last});

  final ModerationLogEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final who = e.moderatorName ?? 'A moderator';
    final target = e.targetName ?? 'a member';
    final (verb, color) = switch (e.action) {
      'dismiss' => ('dismissed a report about $target', AppColors.muted),
      'remove_message' => ('removed a message from $target', AppColors.signal),
      'mute_user' => ('muted $target for 24 hours', AppColors.danger),
      'unmute_user' => ('unmuted $target', AppColors.sage),
      _ => (e.action, AppColors.muted),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: who,
                          style: AppType.body(14, weight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: ' $verb',
                          style: AppType.body(14, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  if (e.originalBody != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '"${e.originalBody}"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(
                          13,
                          color: AppColors.muted,
                        ).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(relativeAgo(e.createdAt), style: AppType.mono(10.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
