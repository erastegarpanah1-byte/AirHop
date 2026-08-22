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
import '../../core/widgets/gradient_background.dart';
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
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        _PairingCodeDisplay(code: session.pairingCode),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildReceiver() {
    return Column(
      children: [
        const SizedBox(height: 6),
        const Text(
          'دریافت فایل',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'کد جفت‌سازی را وارد کنید یا QR را اسکن کنید',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),

        _BarcodeScanner(
          onScanned: (code) {
            _codeController.text = code;
            _join();
          },
        ),
        const SizedBox(height: 14),

        const Text(
          'یا وارد کردن کد ۶ رقمی',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 200,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              maxLength: 6,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
              ),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '------',
                hintStyle: TextStyle(color: AppColors.textMuted, letterSpacing: 6),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accentLight, width: 2),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.glassBorder),
                ),
              ),
              onChanged: (val) {
                if (val.length == 6) _join();
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) return;

    final device = await ref.read(deviceProvider.notifier).ensureReady();
    if (!mounted) return;
    await ref.read(sessionProvider.notifier).startReceiving(code, device);
  }
}

class _QrWithRadar extends StatelessWidget {
  const _QrWithRadar({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _RadarAnimation(),
          if (code.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.glowPurple.withOpacity(0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: QrImageView(
                data: code,
                version: QrVersions.auto,
                size: 162,
                gapless: true,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1E1E2C),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1E1E2C),
                ),
              ),
            )
          else
            const CircularProgressIndicator(color: AppColors.accentLight),
        ],
      ),
    );
  }
}

class _RadarAnimation extends StatefulWidget {
  @override
  State<_RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<_RadarAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          painter: _RadarPainter(progress: _c.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (var i = 0; i < 3; i++) {
      final t = (progress - i * 0.33) % 1.0;
      if (t < 0) continue;

      final radius = maxRadius * t;
      final opacity = (1.0 - t).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = AppColors.glowPurple.withOpacity(opacity * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _WaitingIndicator extends StatelessWidget {
  const _WaitingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentLight,
          ),
        ),
        SizedBox(width: 8),
        Text(
          'منتظر اتصال گیرنده...',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PairingCodeDisplay extends StatelessWidget {
  const _PairingCodeDisplay({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final chars = code.split('');

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (chars.isEmpty)
            const Text(
              '------',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            )
          else
            for (final char in chars) ...[
              Container(
                width: 32,
                height: 44,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  char,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _BarcodeScanner extends StatefulWidget {
  const _BarcodeScanner({required this.onScanned});

  final ValueChanged<String> onScanned;

  @override
  State<_BarcodeScanner> createState() => _BarcodeScannerState();
}

class _BarcodeScannerState extends State<_BarcodeScanner> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    torchEnabled: false,
  );
  bool _joined = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_joined) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _joined = true;
      try {
        _controller.stop();
      } catch (_) {}
      widget.onScanned(raw);
      break;
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
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accentLight.withOpacity(0.55), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
