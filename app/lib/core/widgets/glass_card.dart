import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// کارت شیشه‌ای (glass card) با frosted glass + حاشیه گرادیانی نئونی.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 22,
    this.glowColor,
    this.color,
    this.gradientBorder = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? glowColor;
  final Color? color;

  /// اگر true، حاشیه‌ی گرادیانی بنفش→آبی به جای حاشیه‌ی ساده.
  final bool gradientBorder;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: color ?? AppColors.glassBg,
        border: gradientBorder
            ? null
            : Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDeep,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withOpacity(0.18),
              blurRadius: 32,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: child,
        ),
      ),
    );
  }
}

/// کانتینر با حاشیه‌ی گرادیانی نئونی (بنفش→آبی) دور آن.
class NeonBorderContainer extends StatelessWidget {
  const NeonBorderContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.glowColor = AppColors.glowPurple,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5), // ضخامت حاشیه گرادیانی
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: AppColors.brandGradient,
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.35),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius - 1.5),
          color: AppColors.backgroundMid,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 1.5),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: child,
          ),
        ),
      ),
    );
  }
}
