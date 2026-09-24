import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../util/format.dart';

/// Rounded square monogram. Tone is stable per name.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tones = AppColors.avatarTones;
    final tone =
        tones[name.codeUnits.fold<int>(0, (a, b) => a + b) % tones.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        initialsFor(name),
        style: AppType.heading(size * 0.36, color: AppColors.ink),
      ),
    );
  }
}
