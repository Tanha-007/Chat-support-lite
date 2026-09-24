import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../data/errors.dart';
import '../theme/app_theme.dart';

class ReportChoice {
  const ReportChoice(this.reason, this.note);
  final String reason;
  final String? note;
}

const _reasons = <(String, String, String)>[
  ('spam', 'Spam', 'Ads, links, or repeated junk'),
  ('harassment', 'Harassment', 'Insults, threats, or bullying'),
  ('inappropriate', 'Inappropriate', 'Content that does not belong here'),
  ('other', 'Something else', 'Tell the moderator in the note'),
];

/// Collects a reason and note, then runs [onSubmit]. Returns true when filed.
Future<bool> showReportSheet(
  BuildContext context, {
  required String quote,
  required Future<void> Function(ReportChoice choice) onSubmit,
}) async {
  final filed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ReportSheet(quote: quote, onSubmit: onSubmit),
  );
  return filed ?? false;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.quote, required this.onSubmit});

  final String quote;
  final Future<void> Function(ReportChoice choice) onSubmit;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(ReportChoice(_reason!, _note.text));
      if (mounted) Navigator.of(context).pop(true);
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
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + inset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report message', style: AppType.heading(22)),
            const SizedBox(height: 6),
            Text(
              'A moderator reviews every report. The sender is not told who reported them.',
              style: AppType.body(14, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: AppColors.paper,
                border: Border(
                  left: BorderSide(color: AppColors.lineStrong, width: 3),
                ),
              ),
              child: Text(
                widget.quote,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppType.body(14, color: AppColors.inkSoft),
              ),
            ),
            const SizedBox(height: 10),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final r in _reasons)
                    RadioListTile<String>(
                      value: r.$1,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        r.$2,
                        style: AppType.body(15, weight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        r.$3,
                        style: AppType.body(13, color: AppColors.muted),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLength: SupabaseConfig.maxReportNoteLength,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Note for the moderator (optional)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: AppType.body(13, color: AppColors.danger),
                ),
              ),
            FilledButton(
              onPressed: (_reason == null || _busy) ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: Text(_busy ? 'Sending report' : 'Send report'),
            ),
          ],
        ),
      ),
    );
  }
}
