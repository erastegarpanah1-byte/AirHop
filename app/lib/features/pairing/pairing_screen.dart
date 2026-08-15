import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/domain/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../transfer/transfer_screen.dart';

/// صفحه‌ی جفت‌سازی — نمایش QR/کد برای sender، یا ورود کد برای receiver.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key, required this.isSender});

  final bool isSender;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isSender) {
      // شروع جلسه‌ی ارسال: ساخت room + دریافت کد
      Future.microtask(() {
        ref.read(sessionProvider.notifier).startSending();
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    // اگر متصل شد، انتقال را شروع کن
    if (session.status == PairingStatus.connected) {
      Future.microtask(() {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const TransferScreen(),
            ),
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
                // هدر
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    const Text(
                      'جفت‌سازی',
                      style: TextStyle(
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

  /// حالت ارسال: نمایش QR + کد عددی.
  Widget _buildSenderCard(SessionState session) {
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'کد اتصال خود را اسکن کنید',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 24),
          if (session.pairingCode.isNotEmpty) ...[
            // QR code داخل یک frame گلس
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: session.pairingCode,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 24),
            // کد متنی بزرگ
            Text(
              session.pairingCode,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 42,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
            ),
          ] else ...[
            // در حال ساخت room
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'در حال ساخت کد اتصال...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'منتظر اتصال دستگاه دیگر...',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// حالت دریافت: ورود کد ۶ رقمی.
  Widget _buildReceiverCard() {
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'کد اتصال را وارد کنید',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 24),
          // فیلد ورود کد
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
                  ref.read(sessionProvider.notifier).startReceiving(v.toUpperCase());
                }
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
