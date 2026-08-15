import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/data/device_service.dart';
import '../../core/domain/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../send/send_screen.dart';
import '../transfer/transfer_screen.dart';

/// صفحه‌ی جفت‌سازی.
///
/// - Sender: یک QR + کد ۶ رقمی شخصی تولید می‌کند که نباید به اشتراک گذاشته شود.
/// - Receiver: کد را وارد (یا اسکن) می‌کند.
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
    // شروع جلسه فقط برای sender انجام می‌شود
    if (widget.isSender) {
      Future.microtask(_begin);
    }
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

    // Sender: وقتی دستگاه مقصد شناخته شد → صفحه ارسال
    if (widget.isSender && session.status == PairingStatus.readyToSend) {
      Future.microtask(() {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SendScreen()),
          );
        }
      });
    }

    // Receiver: وقتی متصل شد → صفحه انتقال (دریافت)
    if (!widget.isSender && session.status == PairingStatus.connected) {
      Future.microtask(() {
        if (context.mounted) {
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        ref.read(sessionProvider.notifier).reset();
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.isSender ? 'ارسال فایل' : 'دریافت فایل',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const Spacer(),
                if (widget.isSender) _buildSenderCard(session),
                if (!widget.isSender) _buildReceiverCard(),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// کد شخصی sender: QR + کد، با هشدار خصوصی بودن.
  Widget _buildSenderCard(SessionState session) {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'کلید اتصال شخصی تو',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'این کد مخصوص توست و نباید آن را با کسی به اشتراک بگذاری.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 24),
          if (session.pairingCode.isNotEmpty) ...[
            // QR داخل قاب سفید
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: session.pairingCode,
                version: QrVersions.auto,
                size: 190,
              ),
            ),
            const SizedBox(height: 24),
            // کد متنی بزرگ با فاصله‌گذاری
            Text(
              session.pairingCode,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
            ),
          ] else ...[
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'در حال ساخت کلید اتصال...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'منتظر اتصال دسکتاپ...',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// ورود کد توسط receiver.
  Widget _buildReceiverCard() {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'کلید اتصال را وارد کن',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
              ),
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: '••••••',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 28),
              ),
              onChanged: (v) {
                if (v.length == 6) {
                  _joinRoom(v.toUpperCase());
                }
              },
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'اتصال خودکار پس از وارد کردن کلید',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Future<void> _joinRoom(String code) async {
    final device = await ref.read(deviceProvider.notifier).ensureReady();
    if (!mounted) return;
    await ref.read(sessionProvider.notifier).startReceiving(code, device);
  }
}
