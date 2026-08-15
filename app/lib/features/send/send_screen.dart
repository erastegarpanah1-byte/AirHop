import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cross_file/cross_file.dart';
import 'package:uuid/uuid.dart';

import '../../core/data/device_service.dart';
import '../../core/domain/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../transfer/transfer_screen.dart';

/// صفحه‌ی ارسال — بعد از سینک شدن نمایش داده می‌شود.
///
/// «داری به [نام دستگاه مقصد] می‌فرستی» + انتخاب چند فایل + دکمه ارسال.
/// روی دسکتاپ از drag & drop هم پشتیبانی می‌کند.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final List<FileMetadata> _selected = [];
  bool _picking = false;
  bool _sending = false;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _pickFiles() async {
    setState(() => _picking = true);
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
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// افزودن فایل‌ها از drag & drop (دسکتاپ).
  Future<void> _addDroppedFiles(List<XFile> dropped) async {
    for (final file in dropped) {
      final name = file.name;

      Uint8List? bytes;
      int size = 0;
      try {
        final data = await file.readAsBytes();
        bytes = data;
        size = data.length;
      } catch (_) {
        try {
          size = await file.length();
        } catch (_) {
          size = 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _selected.add(FileMetadata(
          id: const Uuid().v4(),
          name: name,
          size: size,
          mimeType: name.contains('.') ? name.split('.').last : null,
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
    final peerName = peer != null && peer.name.isNotEmpty
        ? peer.name
        : 'دستگاه مقصد';
    final totalSize = _selected.fold<int>(0, (sum, f) => sum + f.size);

    return Scaffold(
      body: DropTarget(
        onDragDone: (details) => _addDroppedFiles(details.files),
        child: GradientBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'ارسال فایل',
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
                  const SizedBox(height: 8),
                  // اعلان دستگاه مقصد
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.accentGradient,
                          ),
                          child: const Icon(
                            Icons.devices_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'داری به این دستگاه می‌فرستی:',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$peerName  (${peer != null ? DeviceService.platformLabel(peer.platform) : ''})',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassButton(
                    label: _selected.isEmpty
                        ? 'انتخاب فایل‌ها'
                        : '+ افزودن فایل بیشتر',
                    icon: Icons.folder_open_rounded,
                    accentColor: AppColors.accent,
                    height: 60,
                    onPressed: _picking ? null : _pickFiles,
                  ),
                  const SizedBox(height: 20),
                  // لیست فایل‌های انتخاب‌شده
                  Expanded(
                    child: _selected.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  color: AppColors.textMuted.withOpacity(0.5),
                                  size: 64,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'فایل‌ها را اینجا بکشید یا دکمه را بزنید',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _selected.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final f = _selected[i];
                              return GlassCard(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      _iconFor(f),
                                      color: AppColors.accent,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            f.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatBytes(f.size),
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => setState(
                                          () => _selected.removeAt(i)),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: AppColors.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Text(
                            '${_selected.length} فایل  ·  ${_formatBytes(totalSize)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassButton(
                      label: _sending
                          ? 'در حال ارسال...'
                          : 'ارسال (${_selected.length})',
                      icon: Icons.send_rounded,
                      accentColor: AppColors.primary,
                      height: 66,
                      onPressed: _sending ? null : _send,
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(FileMetadata f) {
    final ext = (f.mimeType ?? '').toLowerCase();
    if (ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'png' ||
        ext == 'gif' ||
        ext == 'webp' ||
        ext == 'heic') {
      return Icons.image_rounded;
    }
    if (ext == 'mp4' || ext == 'mov' || ext == 'mkv' || ext == 'avi') {
      return Icons.videocam_rounded;
    }
    if (ext == 'mp3' || ext == 'wav' || ext == 'flac') {
      return Icons.audiotrack_rounded;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (ext == 'zip' || ext == 'rar') return Icons.folder_zip_rounded;
    if (ext == 'doc' || ext == 'docx' || ext == 'txt' || ext == 'md') {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }
}
