/// SKILL: mensaena-design
/// AppSnackBar — zentraler SnackBar-Helper. Ersetzt die ~180 handgebauten
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))`-Blöcke mit
/// identischem Styling (surface-Background + body-13-Typo).
///
/// Verwendung:
///   AppSnackBar.success(context, 'challenges.createSuccess'.tr());
///   AppSnackBar.error(context, 'common.errorGeneric'.tr());
///   AppSnackBar.info(context, 'map.pinHint'.tr(), action: ...);
///
/// Eingebaute Sicherheit: prüft `context.mounted` — Aufrufe nach einem
/// async gap sind damit gefahrlos (häufigste Crash-Klasse aus dem
/// Phase-1-Audit). Migration der Altaufrufe erfolgt häppchenweise pro
/// Modul; neue Screens nutzen NUR diesen Helper.
library;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class AppSnackBar {
  const AppSnackBar._();

  /// Grün (leben) — Erfolgsmeldungen (gespeichert, erstellt, gesendet).
  static void success(BuildContext context, String message,
      {SnackBarAction? action, Duration? duration}) {
    _show(context, message,
        color: AppColors.leben, action: action, duration: duration);
  }

  /// Warm-Rot (herzrotWarm) — Fehler und abgelehnte Aktionen.
  static void error(BuildContext context, String message,
      {SnackBarAction? action, Duration? duration}) {
    _show(context, message,
        color: AppColors.herzrotWarm, action: action, duration: duration);
  }

  /// Neutral (ink) — Hinweise und Status-Infos.
  static void info(BuildContext context, String message,
      {SnackBarAction? action, Duration? duration}) {
    _show(context, message,
        color: AppColors.ink, action: action, duration: duration);
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color color,
    SnackBarAction? action,
    Duration? duration,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(message,
          style: AppTypography.body(size: 13, color: color)),
      action: action,
      duration: duration ?? const Duration(milliseconds: 4000),
    ));
  }
}
