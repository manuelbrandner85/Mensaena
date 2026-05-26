/// SKILL: mensaena-features + mensaena-design
/// PostIntentSelector (Schritt 7): 2-Spalten-Grid mit allen 10 PostIntent
/// + staggered fade-in. Smart-Default aus initialPostType.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post_intent.dart';

class PostIntentSelector extends StatelessWidget {
  const PostIntentSelector({
    required this.onIntentSelected,
    this.initialPostType,
    this.selectedIntent,
    super.key,
  });

  final ValueChanged<PostIntent> onIntentSelected;
  final String? initialPostType;
  final PostIntent? selectedIntent;

  PostIntent get _effectiveSelected =>
      selectedIntent ??
      (initialPostType != null
          ? PostIntent.fromPostType(initialPostType)
          : PostIntent.general);

  @override
  Widget build(BuildContext context) {
    final selected = _effectiveSelected;
    const intents = PostIntent.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('post_intent.title'.tr(),
            style: AppTypography.body(
                size: 14,
                color: AppColors.ink,
                weight: FontWeight.w700)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
          ),
          itemCount: intents.length,
          itemBuilder: (_, i) {
            final intent = intents[i];
            final isSelected = intent == selected;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 220 + (i * 50)),
              curve: Curves.easeOut,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 8),
                  child: child,
                ),
              ),
              child: _IntentTile(
                intent: intent,
                isSelected: isSelected,
                onTap: () => onIntentSelected(intent),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _IntentTile extends StatelessWidget {
  const _IntentTile({
    required this.intent,
    required this.isSelected,
    required this.onTap,
  });

  final PostIntent intent;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.bronze.withValues(alpha: 0.18)
                  : AppColors.elevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.bronze
                    : AppColors.line,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(intent.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    intent.labelKey.tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 12,
                      color: isSelected ? AppColors.ink : AppColors.inkSoft,
                      weight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.bronze,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.check,
                    size: 12, color: AppColors.voidColor),
              ),
            ),
        ],
      ),
    );
  }
}
