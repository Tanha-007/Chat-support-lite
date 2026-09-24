import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../util/format.dart';

/// Small uppercase mono label.
class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    this.background = AppColors.sunken,
    this.foreground = AppColors.inkSoft,
  });

  final String label;
  final Color background;
  final Color foreground;

  factory Tag.role(String? role) {
    switch (role) {
      case 'mentor':
        return Tag(
          label: roleLabel(role),
          background: AppColors.sageSoft,
          foreground: AppColors.sage,
        );
      case 'moderator':
        return Tag(
          label: roleLabel(role),
          background: AppColors.amberSoft,
          foreground: AppColors.amber,
        );
      default:
        return Tag(label: roleLabel(role));
    }
  }

  factory Tag.resolved() => const Tag(
    label: 'Resolved',
    background: AppColors.sageSoft,
    foreground: AppColors.sage,
  );

  factory Tag.reason(String reason) {
    switch (reason) {
      case 'harassment':
        return const Tag(
          label: 'Harassment',
          background: AppColors.dangerSoft,
          foreground: AppColors.danger,
        );
      case 'spam':
        return const Tag(
          label: 'Spam',
          background: AppColors.amberSoft,
          foreground: AppColors.amber,
        );
      case 'inappropriate':
        return const Tag(
          label: 'Inappropriate',
          background: AppColors.signalSoft,
          foreground: AppColors.signal,
        );
      default:
        return const Tag(label: 'Other');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppType.mono(
          10,
          color: foreground,
          weight: FontWeight.w600,
          spacing: 0.8,
        ),
      ),
    );
  }
}
