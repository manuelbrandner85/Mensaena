import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/typography.dart';

/// 5-Tab Bottom-Nav mit angehobenem zentralem "Erstellen"-Button.
class CinemaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCreatePressed;

  const CinemaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onCreatePressed,
  });

  static const _items = [
    (LucideIcons.layoutDashboard, 'Start'),
    (LucideIcons.mapPin, 'Karte'),
    (null, 'Erstellen'), // Center
    (LucideIcons.messageCircle, 'Chat'),
    (LucideIcons.user, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kBottomNavigationBarHeight + 16,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: MnColors.voidColor.withValues(alpha: 0.85),
                    border: const Border(top: BorderSide(color: MnColors.line)),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _items.length; i++)
                Expanded(child: _buildItem(i)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(int i) {
    final item = _items[i];
    final isCenter = i == 2;
    final isActive = i == currentIndex;

    if (isCenter) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: GestureDetector(
          onTap: onCreatePressed ?? () => onTap(i),
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [MnColors.amber, MnColors.amberWarm],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: MnShadows.amberGlow,
            ),
            child: const Icon(LucideIcons.plus, color: MnColors.voidColor, size: 26),
          ),
        ),
      );
    }

    return InkResponse(
      onTap: () => onTap(i),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.$1!,
              size: 22,
              color: isActive ? MnColors.amber : MnColors.mute,
            ),
            const SizedBox(height: 4),
            Text(
              item.$2,
              style: MnTypography.body(
                size: 10,
                color: isActive ? MnColors.amber : MnColors.mute,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
