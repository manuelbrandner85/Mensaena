import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme/app_typography.dart';

/// App-Header (AppBar-Wrapper) mit primärer Hintergrundfarbe (Teal-Ton)
/// und weißen Text-/Icon-Farben.
///
/// Konsistente Farbgebung analog zur unteren Navigationsleiste
/// (dashboard_scaffold.dart), aber mit hellem Primary-Ton statt
/// Cinema-Dunkel-Oberfläche.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    super.key,
  });

  final String title;

  /// Optionales führendes Widget (z.B. Back-Button). Falls null, wird
  /// automatisch der Material-Standard-Leading gerendert.
  final Widget? leading;

  /// Optionale Action-Widgets rechts in der AppBar.
  final List<Widget>? actions;

  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AppBar(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      title: Text(
        title,
        style: AppTypography.appBarTitle(color: Colors.white),
      ),
      actions: actions,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    );
  }
}

/// Fertiger Back-Button für AppHeader mit Teal-Hintergrund.
/// Gibt `.tr()`-kompatiblen Tooltip aus und popt die Route.
class AppHeaderBackButton extends StatelessWidget {
  const AppHeaderBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'common.back'.tr(),
      icon: const Icon(LucideIcons.arrowLeft, size: 22, color: Colors.white),
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
