import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// نوار ناوبری شناور «جزیره‌ای» AirHop.
///
/// یک پیل/سوپر-الیپس کپسولی که از لبه‌های صفحه فاصله دارد و شناور است،
/// با حاشیهٔ گرادیانی نئونی و گلوی بیرونی.
class FloatingNavbar extends StatelessWidget {
  const FloatingNavbar({
    super.key,
    required this.title,
    this.onBack,
    this.onHistory,
    this.onSettings,
    this.onHelp,
    this.showLogo = true,
    this.child,
  });

  /// عنوان وسط (اختیاری؛ اگر لوگو نشان داده شود نادیده گرفته می‌شود).
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onHistory;
  final VoidCallback? onSettings;
  final VoidCallback? onHelp;
  final bool showLogo;

  /// محتوای سفارشی وسط (اختیاری).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final showBack = onBack != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: AppColors.glassBg,
          border: Border.all(color: AppColors.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDeep,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 28,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Row(
              children: [
                // سمت راست (در RTL: اول) دکمه خانه/برگشت
                _NavCircleButton(
                  icon: showBack
                      ? Icons.arrow_back_rounded
                      : Icons.home_rounded,
                  onTap: showBack
                      ? (onBack ?? () {})
                      : () => navigatorHome(context),
                ),
                const SizedBox(width: 8),

                // وسط: لوگو + وردمارک یا عنوان
                Expanded(
                  child: Center(
                    child: showLogo
                        ? const _BrandLogo()
                        : Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 8),
                // سمت چپ (در RTL: آخر) ۳ دکمه دایره‌ای
                _NavCircleButton(
                  icon: Icons.history_rounded,
                  onTap: onHistory ?? () {},
                ),
                const SizedBox(width: 6),
                _NavCircleButton(
                  icon: Icons.settings_rounded,
                  onTap: onSettings ?? () {},
                ),
                const SizedBox(width: 6),
                _NavCircleButton(
                  icon: Icons.help_outline_rounded,
                  onTap: onHelp ?? () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void navigatorHome(BuildContext context) {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

/// لوگوی برند: قوس گرادیانی + وردمارک Airhop.
class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // قوس مینیمال (دو نقطه رنگی با قوس اتصال)
        SizedBox(
          width: 40,
          height: 28,
          child: CustomPaint(painter: _ArcPainter()),
        ),
        const SizedBox(width: 8),
        const Text(
          'Airhop',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// نقاشی قوس لوگو (از نقطه فیروزه‌ای به نقطه بنفش).
class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [AppColors.cyan, AppColors.accent, AppColors.primary],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // قوس رو به بالا که دو نقطه را وصل می‌کند
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.1,
        size.width * 0.92,
        size.height * 0.75,
      );
    canvas.drawPath(path, stroke);

    // دو نقطه انتهایی
    final startDot = Paint()..color = AppColors.cyan;
    final endDot = Paint()..color = AppColors.primarySoft;
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.75),
      3.5,
      startDot,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.75),
      3.5,
      endDot,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// دکمه‌ی دایره‌ای شیشه‌ای با هاور/لمس درخشان.
class _NavCircleButton extends StatefulWidget {
  const _NavCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_NavCircleButton> createState() => _NavCircleButtonState();
}

class _NavCircleButtonState extends State<_NavCircleButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.95 : (_hovered ? 1.08 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassBgStrong,
              border: Border.all(
                color: _hovered
                    ? AppColors.primarySoft.withOpacity(0.7)
                    : AppColors.glassBorder,
                width: 1.2,
              ),
              boxShadow: [
                if (_hovered)
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: _hovered ? AppColors.textPrimary : AppColors.textSecondary,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}
