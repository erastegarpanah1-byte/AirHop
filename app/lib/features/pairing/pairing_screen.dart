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

    // نمایش خطا در صورت fail
    if (session.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${session.error}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
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
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
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
        const SizedBox(height: 6),
        const Text(
          'برای اتصال اسکن کنید',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'کد QR را در دستگاه مقابل اسکن کنید',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),

        _QrWithRadar(code: session.pairingCode),
        const SizedBox(height: 10),

        const _WaitingIndicator(),
        const SizedBox(height: 14),

        const Text(
          'کد جفت‌سازی',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _CodeBoxes(code: session.pairingCode),
        const SizedBox(height: 10),
        const Text(
          'یا کد را وارد کنید',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.glassBgStrong,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const Icon(Icons.keyboard_rounded,
              color: AppColors.textSecondary, size: 20),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildReceiver() {
    return Column(
      children: [
        const SizedBox(height: 6),
        const Text(
          'اسکن کد QR',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'کد QR دستگاه فرستنده را اسکن کنید',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),

        _BarcodeScanner(onScanned: (code) {
          if (code.isNotEmpty) _join(code.toUpperCase());
        }),
        const SizedBox(height: 14),

        const Text(
          'یا کد را به صورت دستی وارد کنید',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: '••••••',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 24),
            ),
            onChanged: (v) {
              if (v.length == 6) _join(v.toUpperCase());
            },
          ),
        ),
        const SizedBox(height: 6),
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
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _radar,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(230, 230),
                painter: _RadarPainter(progress: _radar.value),
              );
            },
          ),
          Container(
            width: 186,
            height: 186,
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
                        size: 162,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0A0A18),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0A0A18),
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
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
          ..._scannerCorners(),
        ],
      ),
    );
  }

  List<Widget> _scannerCorners() {
    const color = AppColors.primarySoft;
    const length = 26.0;
    const thickness = 3.5;
    const offset = 14.0;
    final positions = [
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
      final radius = 92 + p * 22;
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
              size: const Size(18, 18),
              painter: _PulseDotPainter(progress: _c.value),
            );
          },
        ),
        const SizedBox(width: 10),
        const Text(
          'منتظر اتصال...',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
    canvas.drawCircle(center, 4, Paint()..color = AppColors.primarySoft);
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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 6; i++) ...[
            Container(
            width: 40,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: code.isEmpty
                ? Text(
                    digits[i],
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : GradientText(
                    digits[i],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
              if (i < 5) const SizedBox(width: 7),
            ],
          ],
        ),
      );
  }
}

/// اسکنر بارکد (QR) برای بخش دریافت.
class _BarcodeScanner extends StatefulWidget {
  const _BarcodeScanner({required this.onScanned});

  final ValueChanged<String> onScanned;

  @override
  State<_BarcodeScanner> createState() => _BarcodeScannerState();
}

class _BarcodeScannerState extends State<_BarcodeScanner> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  String? _lastScanned;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      // جلوگیری از فراخوانی تکراری برای یک کد
      if (raw == _lastScanned) continue;
      _lastScanned = raw;
      widget.onScanned(raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 230,
        height: 230,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: AppColors.textMuted, size: 28),
                      const SizedBox(height: 8),
                      const Text(
                        'دوربین در دسترس نیست',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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
