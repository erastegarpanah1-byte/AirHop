import 'dart:io';
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
        for (final f in result.files) {
          Uint8List? bytes;
          // برای فایل‌های زیر ۵ مگابایت بایت‌ها را لود می‌کنیم تا سریع ارسال شوند
          // اما برای فایل‌های بزرگتر (مثل ۱۰۰ مگابایت روی اندروید ۷) به هیچ وجه bytes را یکجا لود نمی‌کنیم تا کرش نکند!
          if (f.size < 5 * 1024 * 1024) {
            bytes = f.bytes;
            if (bytes == null && f.path != null) {
              try {
                bytes = await File(f.path!).readAsBytes();
              } catch (_) {}
            }
          }
          if (!mounted) return;
          setState(() {
            _selected.add(FileMetadata(
              id: const Uuid().v4(),
              name: f.name,
              size: f.size,
              mimeType: f.extension,
              bytes: bytes,
              // ذخیره مسیر واقعی برای استریم مستقیم موقع ارسال
              path: f.path, 
            ));
          });
        }
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

class _DropZone extends StatelessWidget {
  const _DropZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      glowColor: AppColors.glowPurple,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glowPurple.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              color: AppColors.accentLight,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'کشیدن و رها کردن فایل یا انتخاب',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'پشتیبانی از انواع فایل‌ها تا حجم نامحدود',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 140,
            child: GlassButton(
              label: 'انتخاب فایل',
              icon: Icons.add_rounded,
              height: 44,
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.glassBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.glassBorder)),
      ],
    );
  }
}

class _FileTypeGrid extends StatelessWidget {
  const _FileTypeGrid();

  @override
  Widget build(BuildContext context) {
    const list = [
      _TypeItem(icon: Icons.image_rounded, title: 'تصاویر', color: Colors.purple),
      _TypeItem(icon: Icons.video_collection_rounded, title: 'ویدیوها', color: Colors.blue),
      _TypeItem(icon: Icons.audiotrack_rounded, title: 'موزیک', color: Colors.green),
      _TypeItem(icon: Icons.insert_drive_file_rounded, title: 'اسناد', color: Colors.orange),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: list.map((item) => Expanded(child: item)).toList(),
    );
  }
}

class _TypeItem extends StatelessWidget {
  const _TypeItem({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color.withOpacity(0.85), size: 24),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}