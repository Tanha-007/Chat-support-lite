import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../data/chat_repository.dart';
import '../data/errors.dart';
import '../models/chat_thread.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/layout.dart';

/// Learner flow: pick a mentor, name the topic, optionally write the first message.
/// Pops with the created [ChatThread].
class NewThreadScreen extends StatefulWidget {
  const NewThreadScreen({super.key, required this.repository});

  final ChatRepository repository;

  @override
  State<NewThreadScreen> createState() => _NewThreadScreenState();
}

class _NewThreadScreenState extends State<NewThreadScreen> {
  final _form = GlobalKey<FormState>();
  final _topic = TextEditingController();
  final _first = TextEditingController();

  List<Profile>? _mentors;
  String? _loadError;
  Profile? _picked;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMentors();
  }

  @override
  void dispose() {
    _topic.dispose();
    _first.dispose();
    super.dispose();
  }

  Future<void> _loadMentors() async {
    setState(() => _loadError = null);
    try {
      final list = await widget.repository.fetchMentors();
      if (!mounted) return;
      setState(() {
        _mentors = list;
        if (list.length == 1) _picked = list.first;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = friendlyError(e));
    }
  }

  Future<void> _submit() async {
    if (_picked == null) {
      setState(() => _error = 'Pick a mentor first.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.repository.startThread(
        mentorId: _picked!.id,
        title: _topic.text,
        firstMessage: _first.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        ChatThread(
          id: id,
          title: _topic.text.trim(),
          status: 'open',
          updatedAt: DateTime.now(),
          peerId: _picked!.id,
          peerName: _picked!.displayName,
          peerRole: _picked!.role,
          peerHeadline: _picked!.headline,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New conversation')),
      body: SafeArea(
        child: MaxWidth(
          width: 640,
          child: _mentors == null
              ? (_loadError != null
                    ? EmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: 'Could not load mentors',
                        subtitle: _loadError!,
                        action: FilledButton(
                          onPressed: _loadMentors,
                          child: const Text('Try again'),
                        ),
                      )
                    : const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ))
              : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final mentors = _mentors!;
    if (mentors.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search_outlined,
        title: 'No mentors available',
        subtitle: 'Check back soon. Mentors are added by the Deskline team.',
      );
    }

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text('Who should help?', style: AppType.heading(22)),
          const SizedBox(height: 4),
          Text(
            'Mentors reply here in real time when they are online.',
            style: AppType.body(14, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          for (final m in mentors) ...[
            _MentorCard(
              mentor: m,
              selected: _picked?.id == m.id,
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _picked = m;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 8),
          ],
          const SectionLabel(
            'Topic',
            padding: EdgeInsets.fromLTRB(2, 18, 2, 8),
          ),
          TextFormField(
            controller: _topic,
            enabled: !_busy,
            maxLength: SupabaseConfig.maxTopicLength,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'For example: Simplifying algebraic fractions',
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.length < SupabaseConfig.minTopicLength) {
                return 'Give the topic at least ${SupabaseConfig.minTopicLength} characters.';
              }
              return null;
            },
          ),
          const SectionLabel(
            'First message (optional)',
            padding: EdgeInsets.fromLTRB(2, 10, 2, 8),
          ),
          TextFormField(
            controller: _first,
            enabled: !_busy,
            minLines: 3,
            maxLines: 6,
            maxLength: SupabaseConfig.maxMessageLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'What have you tried so far, and where did you get stuck?',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                _error!,
                style: AppType.body(13, color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Opening conversation' : 'Start conversation'),
          ),
        ],
      ),
    );
  }
}

class _MentorCard extends StatelessWidget {
  const _MentorCard({
    required this.mentor,
    required this.selected,
    required this.onTap,
  });

  final Profile mentor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: selected ? AppColors.ink : AppColors.line,
      color: selected ? AppColors.card : AppColors.paper,
      child: Row(
        children: [
          Avatar(name: mentor.displayName, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mentor.displayName,
                  style: AppType.body(16, weight: FontWeight.w600),
                ),
                if (mentor.headline != null)
                  Text(
                    mentor.headline!,
                    style: AppType.body(13, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: selected ? AppColors.ink : AppColors.lineStrong,
                width: 1.5,
              ),
            ),
            child: selected
                ? const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: AppColors.card,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
