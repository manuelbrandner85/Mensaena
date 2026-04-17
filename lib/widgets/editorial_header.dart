import 'package:flutter/material.dart';
import 'package:mensaena/config/theme.dart';

class EditorialHeader extends StatelessWidget {
  final String section;
  final String number;
  final String title;
  final String subtitle;
  final String? accentWord;
  final IconData icon;
  final Color? iconBgColor;

  const EditorialHeader({
    super.key,
    required this.section,
    required this.number,
    required this.title,
    required this.subtitle,
    this.accentWord,
    required this.icon,
    this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = iconBgColor ?? AppColors.primary50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meta label
        Text(
          '§ $number / $section'.toUpperCase(),
          style: AppTextStyles.metaLabel,
        ),
        const SizedBox(height: 16),

        // Icon + Title row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary500.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, size: 24, color: AppColors.primary700),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.pageTitle),
                  const SizedBox(height: 4),
                  _buildSubtitle(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Gradient divider
        Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFd1d5db), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    if (accentWord == null || !subtitle.contains(accentWord!)) {
      return Text(subtitle, style: AppTextStyles.pageSubtitle);
    }

    final parts = subtitle.split(accentWord!);
    return RichText(
      text: TextSpan(
        style: AppTextStyles.pageSubtitle,
        children: [
          TextSpan(text: parts[0]),
          TextSpan(text: accentWord, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }
}
