import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../data/chat_repository.dart';
import '../data/errors.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/layout.dart';
import '../widgets/tag.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.profile,
    required this.onProfileChanged,
    required this.onSignOut,
  });

  final ChatRepository repository;
  final Profile profile;
  final ValueChanged<Profile> onProfileChanged;
  final Future<void> Function() onSignOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.displayName);
  late final _headline = TextEditingController(
    text: widget.profile.headline ?? '',
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refresh);
    _headline.addListener(_refresh);
  }

  @override
  void dispose() {
    _name.dispose();
    _headline.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _dirty =>
      _name.text.trim() != widget.profile.displayName ||
      (_showHeadline &&
          _headline.text.trim() != (widget.profile.headline ?? ''));

  bool get _showHeadline => !widget.profile.isLearner;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateMyProfile(
        displayName: _name.text,
        headline: _showHeadline ? _headline.text : null,
      );
      widget.onProfileChanged(updated);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in any time. Your conversations stay saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      body: SafeArea(
        child: MaxWidth(
          width: 640,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const PageHeader(title: 'Profile'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Panel(
                  child: Row(
                    children: [
                      Avatar(name: p.displayName, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.displayName, style: AppType.heading(20)),
                            const SizedBox(height: 2),
                            Text(
                              widget.repository.email ?? '',
                              style: AppType.mono(11),
                            ),
                            const SizedBox(height: 8),
                            Tag.role(p.role),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (p.isMuted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Panel(
                    color: AppColors.dangerSoft,
                    borderColor: AppColors.dangerSoft,
                    child: Text(
                      'A moderator muted your account (${timeLeft(p.mutedUntil!)}). '
                      'You can still read conversations.',
                      style: AppType.body(14, color: AppColors.danger),
                    ),
                  ),
                ),
              const SectionLabel('Edit details'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        maxLength: SupabaseConfig.maxNameLength,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          helperText: 'Shown to the people you chat with',
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.length < SupabaseConfig.minNameLength) {
                            return 'Use at least ${SupabaseConfig.minNameLength} characters.';
                          }
                          return null;
                        },
                      ),
                      if (_showHeadline) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _headline,
                          maxLength: SupabaseConfig.maxHeadlineLength,
                          decoration: const InputDecoration(
                            labelText: 'Headline',
                            helperText:
                                'What you help with, shown in the mentor list',
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: (_dirty && !_saving) ? _save : null,
                        child: Text(_saving ? 'Saving' : 'Save changes'),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionLabel('House rules'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: const [
                      _Rule('Message length', 'Up to 500 characters'),
                      Divider(),
                      _Rule('Pace', '5 messages per 10 seconds'),
                      Divider(),
                      _Rule('Repeats', 'Same text blocked for 30 seconds'),
                      Divider(),
                      _Rule('New conversations', '10 per learner per day'),
                      Divider(),
                      _Rule('Reports', 'Reviewed by a moderator'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: _confirmSignOut,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppType.body(14, weight: FontWeight.w600),
            ),
          ),
          Text(value, style: AppType.mono(11.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
