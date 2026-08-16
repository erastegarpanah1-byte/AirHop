import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/data/device_service.dart';
import '../../core/domain/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/airhop_footer.dart';
import '../../core/widgets/floating_navbar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_text.dart';
import '../send/send_screen.dart';
import '../transfer/transfer_screen.dart';

/// صفحه جفت‌سازی (Pairing).
///
/// - Sender: QR با لوگو وسط + حلقه رادار + کد ۶ رقمی + منتظر اتصال.
/// - Receiver: اسکنر بارکد + ورود دستی کد.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key, required this.isSender});

  final bool isSender;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _codeController = TextEditingController();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (widget.isSender) Future.microtask(_begin);
  }

  Future<void> _begin() async {
    if (_started) return;
    _started = true;
    final device = await ref.read(deviceProvider.notifier).ensureReady();
    if (!mounted) return;
    await ref.read(sessionProvider.notifier).startSending(device);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (widget.isSender && session.status == PairingStatus.readyToSend) {
      Future.microtask(() {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SendScreen()),
          );
        }
      });
    }

    if (!widget.isSender && session.status == PairingStatus.connected) {
      Future.microtask(() {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TransferScreen()),
          );
        }
      });
    }

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              FloatingNavbar(
                title: widget.isSender ? 'ارسال فایل' : 'دریافت فایل',
                onBack: () {
                  ref.read(sessionProvider.notifier).reset();
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  child: widget.isSender
                      ? _buildSender(session)
                      : _buildReceiver(),
                ),
              ),
              const AirhopFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSender(SessionState session) {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          'برای اتصال اسکن کنید',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'کد QR را در دستگاه مقابل اسکن کنید',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 26),

        // فریم QR با حلقه رادار و گوشه‌های اسکنر
        _QrWithRadar(code: session.pairingCode),
        const SizedBox(height: 16),

        // منتظر اتصال با آیکون پالس
        const _WaitingIndicator(),
        const SizedBox(height: 24),

        // کد جفت‌سازی
        const Text(
          'کد جفت‌سازی',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _CodeBoxes(code: session.pairingCode),
        const SizedBox(height: 12),
        const Text(
          'یا کد را وارد کنید',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.glassBgStrong,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const Icon(Icons.keyboard_rounded,
              color: AppColors.textSecondary, size: 22),
        ),
      ],
    );
  }

  Widget _buildReceiver() {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          'اسکن کد QR',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'کد QR دستگاه فرستنده را اسکن کنید',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 22),

        // اسکنر بارکد
        _BarcodeScanner(onScanned: (code) {
          if (code.isNotEmpty) _join(code.toUpperCase());
        }),
        const SizedBox(height: 20),

        // ورود دستی
        const Text(
          'یا کد را به صورت دستی وارد کنید',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: '••••••',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 26),
            ),
            onChanged: (v) {
              if (v.length == 6) _join(v.toUpperCase());
            },
          ),
        ),
      ],
    );
  }

  Future<void> _join(String code) async {
    if (code.length != 6) return;
    final device = await ref.read(deviceProvider.notifier).ensureReady();
    if (!mounted) return;
    await ref.read(sessionProvider.notifier).startReceiving(code, device);
  }
}

/// فریم QR با لوگو وسط + حلقه‌های رادار پالس‌دار + گوشه‌های اسکنر.
class _QrWithRadar extends StatefulWidget {
  const _QrWithRadar({required this.code});

  final String code;

  @override
  State<_QrWithRadar> createState() => _QrWithRadarState();
}

class _QrWithRadarState extends State<_QrWithRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // حلقه‌های رادار پالس‌دار
          AnimatedBuilder(
            animation: _radar,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(260, 260),
                painter: _RadarPainter(progress: _radar.value),
              );
            },
          ),
          // فریم QR
          Container(
            width: 210,
            height: 210,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.45),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: widget.code.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: widget.code,
                        version: QrVersions.auto,
                        size: 186,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0A0A18),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0A0A18),
                        ),
                      ),
                      // لوگو وسط QR
                      Container(
                        width: 46,
                        height: 46,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/airhop_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
          ),
          // گوشه‌های اسکنر (براکت‌های L)
          ..._scannerCorners(),
        ],
      ),
    );
  }

  List<Widget> _scannerCorners() {
    const color = AppColors.primarySoft;
    const length = 28.0;
    const thickness = 3.5;
    const offset = 16.0;
    final positions = [
      // بالا-راست
      Alignment.topRight,
      Alignment.topLeft,
      Alignment.bottomRight,
      Alignment.bottomLeft,
    ];
    return [
      for (final pos in positions)
        Align(
          alignment: pos,
          child: Container(
            margin: EdgeInsets.all(offset),
            width: length,
            height: length,
            decoration: BoxDecoration(
              border: Border(
                top: pos == Alignment.topRight || pos == Alignment.topLeft
                    ? const BorderSide(color: color, width: thickness)
                    : BorderSide.none,
                bottom: pos == Alignment.bottomRight ||
                        pos == Alignment.bottomLeft
                    ? const BorderSide(color: color, width: thickness)
                    : BorderSide.none,
                left: pos == Alignment.topLeft || pos == Alignment.bottomLeft
                    ? const BorderSide(color: color, width: thickness)
                    : BorderSide.none,
                right: pos == Alignment.topRight || pos == Alignment.bottomRight
                    ? const BorderSide(color: color, width: thickness)
                    : BorderSide.none,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
    ];
  }
}

/// نقاش حلقه‌های رادار.
class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final p = (progress + i / 3) % 1.0;
      final radius = 105 + p * 25;
      final opacity = (1.0 - p) * 0.5;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primary.withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// آیکون «منتظر اتصال...» با نقطه پالس‌دار.
class _WaitingIndicator extends StatefulWidget {
  const _WaitingIndicator();

  @override
  State<_WaitingIndicator> createState() => _WaitingIndicatorState();
}

class _WaitingIndicatorState extends State<_WaitingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return CustomPaint(
              size: const Size(20, 20),
              painter: _PulseDotPainter(progress: _c.value),
            );
          },
        ),
        const SizedBox(width: 10),
        const Text(
          'منتظر اتصال...',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}

class _PulseDotPainter extends CustomPainter {
  _PulseDotPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // نقطه مرکزی
    canvas.drawCircle(
        center, 4, Paint()..color = AppColors.primarySoft);
    // دو قوس هم‌مرکز نبض‌دار
    for (var i = 0; i < 2; i++) {
      final p = (progress + i / 2) % 1.0;
      canvas.drawCircle(
        center,
        6 + p * 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.primary.withOpacity((1 - p) * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulseDotPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// نمایش کد ۶ رقمی در box های جدا با گرادیان.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final digits = code.padRight(6, '·').split('');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 6; i++) ...[
          Container(
            width: 46,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: code.isEmpty
                ? Text(
                    digits[i],
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : GradientText(
                    digits[i],
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          if (i < 5) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// اسکنر بارکد (QR) برای بخش دریافت.
class _BarcodeScanner extends StatelessWidget {
  const _BarcodeScanner({required this.onScanned});

  final ValueChanged<String> onScanned;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MobileScanner(
              onDetect: (capture) {
                final codes = capture.barcodes;
                if (codes.isNotEmpty && codes.first.rawValue != null) {
                  onScanned(codes.first.rawValue!);
                }
              },
            ),
            // overlay گوشه‌ها
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.primarySoft.withOpacity(0.4),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
