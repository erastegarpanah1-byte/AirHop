import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/gradient_background.dart';
import '../core/widgets/sidebar.dart';
import 'home/home_screen.dart';
import 'pairing/pairing_screen.dart';
import 'transfer/transfer_screen.dart';

/// Shell دسکتاپ — سایدبار جزیره‌ای + محتوای فعال.
///
/// فقط روی ویندوز/مک/لینوکس اجرا می‌شود. چیدمانی حرفه‌ای با سایدبار
/// آیکونی شناور (گلاس‌مورفیسم + هاور انیمیشن) ارائه می‌دهد.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _index = 0;

  static const _items = [
    SidebarItem(id: 'home', icon: Icons.home_rounded, label: 'خانه'),
    SidebarItem(id: 'send', icon: Icons.upload_rounded, label: 'ارسال فایل'),
    SidebarItem(id: 'receive', icon: Icons.download_rounded, label: 'دریافت فایل'),
    SidebarItem(id: 'transfer', icon: Icons.swap_horiz_rounded, label: 'انتقال'),
  ];

  Widget _activeView() {
    switch (_items[_index].id) {
      case 'home':
        return const HomeScreen();
      case 'send':
        return const PairingScreen(isSender: true);
      case 'receive':
        return const PairingScreen(isSender: false);
      case 'transfer':
        return const TransferScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Row(
          children: [
            // سایدبار باریک در سمت چپ
            Padding(
              padding: const EdgeInsets.all(16),
              child: Sidebar(
                items: _items,
                selectedId: _items[_index].id,
                onSelect: (id) {
                  setState(() {
                    _index = _items.indexWhere((e) => e.id == id);
                  });
                },
              ),
            ),
            // محتوای اصلی
            Expanded(
              child: _activeView(),
            ),
          ],
        ),
      ),
    );
  }
}
