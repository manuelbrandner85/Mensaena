/// SKILL: mensaena-features (Phase 14 F81)
/// Lese-Modus für Posts — Toggle. Wenn aktiviert:
///   - Beschreibung größer + leadingHeight 1.7
///   - Auto-Hide aller Stats/Action-Icons
///   - Hintergrund maximal kontraststark (deep statt surface)
///   - Bilder verkleinert auf Thumbnail-Strip oben
///
/// State pro Session in einem Riverpod-StateProvider. KEIN persisted
/// Storage — beim nächsten App-Start standardmäßig wieder aus.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';

/// Globaler Lese-Modus-State (Session-bound).
final readingModeProvider = StateProvider<bool>((_) => false);

class ReadingModeToggle extends ConsumerWidget {
  const ReadingModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(readingModeProvider);
    return IconButton(
      tooltip: on
          ? 'reading.exit'.tr()
          : 'reading.enter'.tr(),
      icon: Icon(
        on ? LucideIcons.bookOpen : LucideIcons.book,
        size: 18,
        color: on ? AppColors.amber : AppColors.bronze,
      ),
      onPressed: () =>
          ref.read(readingModeProvider.notifier).state = !on,
    );
  }
}
