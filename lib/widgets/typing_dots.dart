import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TypingDots extends StatefulWidget {
  const TypingDots({super.key, required this.label});

  final String label;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                children: List.generate(3, (i) {
                  final t = (_controller.value + i * 0.2) % 1.0;
                  final dy = (t < 0.5 ? t : 1 - t) * -4;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.sky,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }
}
