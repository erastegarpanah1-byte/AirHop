import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// پس‌زمینه‌ی سراسری با گرادیان navy + Bokeh های نورانی (بنفش/آبی) که
/// به آرامی درجا نبض می‌زنند (breathing animation).
class GradientBackground extends StatefulWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: Stack(
        children: [
          // Bokeh بنفش (بالا-چپ)
          Positioned(
            top: -120,
            left: -100,
            child: _BreathingBlob(
              controller: _controller,
              color: AppColors.primary,
              size: 360,
              opacity: 0.20,
            ),
          ),
          // Bokeh آبی (پایین-راست)
          Positioned(
            bottom: -110,
            right: -120,
            child: _BreathingBlob(
              controller: _controller,
              color: AppColors.accent,
              size: 340,
              opacity: 0.18,
            ),
          ),
          // Bokeh فیروزه‌ای کوچک (وسط)
          Positioned(
            top: 250,
            right: -60,
            child: _BreathingBlob(
              controller: _controller,
              color: AppColors.cyan,
              size: 160,
              opacity: 0.10,
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// یک blob نورانی که به آرامی مقیاس می‌گیرد (breathing).
class _BreathingBlob extends StatelessWidget {
  const _BreathingBlob({
    required this.controller,
    required this.color,
    required this.size,
    required this.opacity,
  });

  final AnimationController controller;
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + (controller.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(opacity),
                  color.withOpacity(opacity * 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
