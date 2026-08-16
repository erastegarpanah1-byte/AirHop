import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/domain/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_ui.dart';
import '../../core/widgets/airhop_footer.dart';
import '../../core/widgets/file_card.dart';
import '../../core/widgets/floating_navbar.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../transfer/transfer_screen.dart';

/// صفحه ارسال فایل (آپلود).
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final List<FileMetadata> _selected = [];
  bool _sending = false;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final f in result.files) {
            final bytes = f.bytes;
            _selected.add(FileMetadata(
              id: const Uuid().v4(),
              name: f.name,
              size: f.size,
              mimeType: f.extension,
              bytes: bytes != null ? Uint8List.fromList(bytes) : null,
            ));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در انتخاب فایل: $e')),
        );
      }
    }
  }

  Future<void> _addDroppedFiles(List<XFile> dropped) async {
    for (final file in dropped) {
      Uint8List? bytes;
      int size = 0;
      try {
        final data = await file.readAsBytes();
        bytes = data;
        size = data.length;
      } catch (_) {
        try { size = await file.length(); } catch (_) { size = 0; }
      }
      if (!mounted) return;
      setState(() {
        _selected.add(FileMetadata(
          id: const Uuid().v4(),
          name: file.name,
          size: size,
          mimeType: FileUi.extensionOf(file.name),
          bytes: bytes,
        ));
      });
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);
    await ref.read(sessionProvider.notifier).sendFiles(List.from(_selected));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TransferScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final peer = session.peerDevice;
    final peerName = peer != null && peer.name.isNotEmpty ? peer.name : 'دستگاه مقصد';

    return Scaffold(
      body: DropTarget(
        onDragDone: (details) => _addDroppedFiles(details.files),
        child: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                FloatingNavbar(
                  title: 'ارسال فایل',
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'ارسال فایل',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'داری به «$peerName» می‌فرستی',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_selected.isEmpty) ...[
                          _DropZone(onTap: _pickFiles),
                          const SizedBox(height: 18),

                          _SectionDivider(text: 'انواع فایل‌های پشتیبانی‌شده'),
                          const SizedBox(height: 12),
                          const _FileTypeGrid(),
                        ] else ...[
                          const Text(
                            'فایل‌های انتخاب‌شده',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (var i = 0; i < _selected.length; i++) ...[
                            FileCard(
                              name: _selected[i].name,
                              size: _selected[i].size,
                              onRemove: () =>
                                  setState(() => _selected.removeAt(i)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 6),
                          GlassButton(
                            label: _sending ? 'در حال ارسال...' : 'ارسال فایل‌ها',
                            icon: Icons.send_rounded,
                            height: 56,
                            onPressed: _sending ? null : _send,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const AirhopFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Drop zone بزرگ با خط‌چین.
class _DropZone extends StatelessWidget {
  const _DropZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.blueGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.glowBlue.withOpacity(0.5),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(Icons.cloud_upload_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: 14),
            const Text(
              'فایل را بکشید یا لمس کنید',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'فایل‌های خود را اینجا رها کنید',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// جداکننده با خطوط نقطه‌چین کناری.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: AppColors.glassBorder),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: AppColors.glassBorder),
        ),
      ],
    );
  }
}

/// شبکه ۴ کارته انواع فایل.
class _FileTypeGrid extends StatelessWidget {
  const _FileTypeGrid();

  static const _types = [
    (Icons.image_rounded, 'تصویر', 'JPG, PNG, GIF', Color(0xFF34D399)),
    (Icons.videocam_rounded, 'ویدیو', 'MP4, MOV, AVI', AppColors.pink),
    (Icons.description_rounded, 'سند', 'PDF, DOC, TXT', AppColors.accentLight),
    (Icons.folder_zip_rounded, 'فشرده', 'ZIP, RAR, 7Z', Color(0xFFFBBF24)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        for (final t in _types)
          GlassCard(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.$4.withOpacity(0.15),
                  ),
                  child: Icon(t.$1, color: t.$4, size: 21),
                ),
                const SizedBox(height: 8),
                Text(
                  t.$2,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.$3,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
