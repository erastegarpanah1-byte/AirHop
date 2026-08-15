import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/device_service.dart';
import 'core/theme/app_theme.dart';
import 'features/desktop_shell.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: FileTransferApp()));
}

class FileTransferApp extends StatelessWidget {
  const FileTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirHop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // روی دسکتاپ shell سایدباری، روی موبایل صفحه‌ی ساده
      home: isDesktop ? const DesktopShell() : const HomeScreen(),
    );
  }
}
