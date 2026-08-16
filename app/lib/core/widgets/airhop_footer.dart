import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// فوتر تگ‌لاین: آیکون سپر + «انتقال مستقیم و امن».
class AirhopFooter extends StatelessWidget {
  const AirhopFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.cyanBlueGradient,
            ),
            child: const Icon(Icons.shield_rounded,
                color: Colors.white, size: 13),
          ),
          const SizedBox(width: 8),
          const Text(
            'انتقال مستقیم و امن، نیازمند اتصال اینترنت',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
