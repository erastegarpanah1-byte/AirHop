import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// یک آیتم سایدبار (آیکون + عنوان).
class SidebarItem {
  const SidebarItem({required this.icon, required this.label, required this.id});
  final IconData icon;
  final String label;
  final String id;
}

/// سایدبار جزیره‌ای شناور با گلاس‌مورفیسم و هاور انیمیشن.
///
/// در حالت عادی فقط آیکون‌ها دیده می‌شوند؛ موقع هاور روی هر آیتم،
/// عنوان آن با انیمیشن نرم باز می‌شود (شبیه macOS dock).
class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SidebarItem> items;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String? _hoveredId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppColors.primary.withOpacity(0.12),
              blurRadius: 40,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in widget.items)
                  _SidebarButton(
                    item: item,
                    selected: item.id == widget.selectedId,
                    hovered: item.id == _hoveredId,
                    onTap: () => widget.onSelect(item.id),
                    onHover: (hovering) {
                      setState(() {
                        _hoveredId = hovering ? item.id : null;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.item,
    required this.selected,
    required this.hovered,
    required this.onTap,
    required this.onHover,
  });

  final SidebarItem item;
  final bool selected;
  final bool hovered;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final bool active = selected || hovered;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: active ? 176 : 52,
          height: 52,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(horizontal: active ? 16 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: active
                ? AppColors.primary.withOpacity(selected ? 0.32 : 0.18)
                : Colors.transparent,
            gradient: selected
                ? AppColors.accentGradient
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: active ? Colors.white : AppColors.textSecondary,
                size: 24,
              ),
              if (active) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: active ? 1.0 : 0.0,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
