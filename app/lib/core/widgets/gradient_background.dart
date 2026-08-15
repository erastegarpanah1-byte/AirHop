import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// پس‌زمینه‌ی گرادیانی سراسری.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: child,
    );
  }
}
