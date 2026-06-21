/// SKILL: mensaena-design (Web-Parität CreatePostPage.tsx)
/// Wiederverwendbares Gerüst für Beitrags-Erstellungs-Screens im Web-Look:
/// Gradient-Kopf (Modul-Akzentfarbe) + weiße/elevated Card-Sektionen.
/// Spiegelt src/components/shared/CreatePostPage.tsx (Gradient-Header,
/// rounded-2xl Card-Sektionen mit Titel-Heading).
///
/// Bestandteile:
///  - CreatePostScaffold: Gradient-Kopf + scrollbarer Body aus [sections] + [footer]
///  - CreateCard: eine Card-Sektion (Titel optional + Icon + Inhalt)
///  - CreateTypeGrid: Typ-Auswahl als Karten-Grid (Label + Beschreibung, Ring aktiv)
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/animated_entrance.dart';

class CreatePostScaffold extends StatelessWidget {
  const CreatePostScaffold({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.returnRoute,
    required this.sections,
    this.footer,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final String returnRoute;

  /// Card-Sektionen (i.d.R. CreateCard-Widgets) — werden gestaffelt eingeblendet.
  final List<Widget> sections;

  /// Optionaler Footer (z.B. Abbrechen/Veröffentlichen).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: Column(
        children: [
          // ── Gradient-Kopf (Modul-Akzent) ──────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, media.padding.top + 14, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent,
                  Color.lerp(accent, AppColors.voidColor, 0.55) ?? accent,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => context.go(returnRoute),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.arrowLeft,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('create.backToModule'.tr(),
                            style: AppTypography.label(
                                size: 11, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title,
                          style: AppTypography.display(
                              size: 22, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.88),
                    )),
              ],
            ),
          ),
          // ── Body: Card-Sektionen ──────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                for (var i = 0; i < sections.length; i++)
                  AnimatedEntrance(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: sections[i],
                    ),
                  ),
                if (footer != null) ...[
                  const SizedBox(height: 4),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Card-Sektion im Web-Look (rounded-2xl, elevated, optionaler Titel).
class CreateCard extends StatelessWidget {
  const CreateCard({
    required this.child,
    this.title,
    this.icon,
    super.key,
  });

  final Widget child;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.bronze),
                  const SizedBox(width: 8),
                ],
                Text(title!,
                    style: AppTypography.display(size: 16, color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Typ-Auswahl als Karten-Grid (Label + optionale Beschreibung, Ring aktiv).
class CreateTypeOption {
  const CreateTypeOption({required this.value, required this.label, this.desc});
  final String value;
  final String label;
  final String? desc;
}

class CreateTypeGrid extends StatelessWidget {
  const CreateTypeGrid({
    required this.options,
    required this.selected,
    required this.accent,
    required this.onSelect,
    super.key,
  });

  final List<CreateTypeOption> options;
  final String? selected;
  final Color accent;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          _TypeButton(
            option: o,
            active: o.value == selected,
            accent: accent,
            onTap: () => onSelect(o.value),
          ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.option,
    required this.active,
    required this.accent,
    required this.onTap,
  });
  final CreateTypeOption option;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 32 - 8) / 2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: BoxConstraints(minWidth: width, maxWidth: width),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.16)
              : AppColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? accent : AppColors.line,
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(option.label,
                style: AppTypography.body(
                  size: 13,
                  color: active ? AppColors.ink : AppColors.inkSoft,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                )),
            if (option.desc != null) ...[
              const SizedBox(height: 2),
              Text(option.desc!,
                  style: AppTypography.label(size: 9, color: AppColors.mute)),
            ],
          ],
        ),
      ),
    );
  }
}
