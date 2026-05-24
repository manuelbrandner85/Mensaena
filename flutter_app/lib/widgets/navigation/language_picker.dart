/// SKILL: mensaena-design + mensaena-features
/// LanguagePicker — kompaktes Sprach-Wechsel-Menü für jeden AppBar.
///
/// Zeigt aktive Flagge + Sprach-Code (z. B. 🇩🇪 DE). Tap öffnet
/// Popup mit allen 7 Sprachen + optionalem "Auto"-Schalter (per GPS).
/// Bei manueller Auswahl wird Auto-Modus automatisch abgeschaltet.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/locale_provider.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key, this.compact = true});

  /// compact = nur Flagge im AppBar. false = Flagge + Code-Label.
  final bool compact;

  static const Map<String, String> flags = {
    'de': '🇩🇪',
    'en': '🇬🇧',
    'it': '🇮🇹',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'tr': '🇹🇷',
    'ru': '🇷🇺',
  };

  static const Map<String, String> names = {
    'de': 'Deutsch',
    'en': 'English',
    'it': 'Italiano',
    'es': 'Español',
    'fr': 'Français',
    'tr': 'Türkçe',
    'ru': 'Русский',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localeProvider);
    final code = state.activeLocale.languageCode;
    final isAuto = state.mode == LocaleMode.auto;

    return InkWell(
      onTap: () => _openMenu(context, ref),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flags[code] ?? '🌐',
                style: const TextStyle(fontSize: 16)),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(code.toUpperCase(),
                  style: AppTypography.mono(
                      size: 11, color: AppColors.inkSoft)),
            ],
            if (isAuto) ...[
              const SizedBox(width: 3),
              const Icon(LucideIcons.mapPin,
                  size: 9, color: AppColors.bronze),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final state = ref.read(localeProvider);
    final notifier = ref.read(localeProvider.notifier);
    final activeCode = state.activeLocale.languageCode;
    final isAuto = state.mode == LocaleMode.auto;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('settings.language.title'.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
                const SizedBox(height: 16),
                // Auto-Toggle
                InkWell(
                  onTap: () async {
                    await notifier.setAuto(!isAuto, ctx);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isAuto
                          ? AppColors.bronze.withValues(alpha: 0.18)
                          : AppColors.elevated,
                      border: Border.all(
                        color:
                            isAuto ? AppColors.bronze : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.mapPin,
                            size: 18,
                            color: isAuto
                                ? AppColors.bronze
                                : AppColors.mute),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('settings.language.autoMode'.tr(),
                                  style: AppTypography.body(
                                    size: 14,
                                    color: isAuto
                                        ? AppColors.bronze
                                        : AppColors.ink,
                                    weight: FontWeight.w600,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                'settings.language.autoModeHint'.tr(),
                                style: AppTypography.body(
                                    size: 11,
                                    color: AppColors.mute,
                                    height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        if (isAuto)
                          const Icon(LucideIcons.checkCircle2,
                              size: 18, color: AppColors.bronze),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('settings.language.title'.tr().toUpperCase(),
                    style: AppTypography.label(
                        size: 10, color: AppColors.mute)),
                const SizedBox(height: 8),
                // 7 Sprachen
                for (final l in kSupportedLocales)
                  _LangRow(
                    code: l.languageCode,
                    name: names[l.languageCode] ?? l.languageCode,
                    flag: flags[l.languageCode] ?? '🌐',
                    active: activeCode == l.languageCode,
                    onTap: () async {
                      await notifier.setManual(l, ctx);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.code,
    required this.name,
    required this.flag,
    required this.active,
    required this.onTap,
  });

  final String code;
  final String name;
  final String flag;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.bronze.withValues(alpha: 0.15)
              : AppColors.elevated,
          border: Border.all(
            color: active ? AppColors.bronze : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  style: AppTypography.body(
                    size: 14,
                    color: active ? AppColors.bronze : AppColors.ink,
                    weight: active ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
            Text(code.toUpperCase(),
                style:
                    AppTypography.mono(size: 11, color: AppColors.mute)),
            if (active) ...[
              const SizedBox(width: 8),
              const Icon(LucideIcons.checkCircle2,
                  size: 16, color: AppColors.bronze),
            ],
          ],
        ),
      ),
    );
  }
}
