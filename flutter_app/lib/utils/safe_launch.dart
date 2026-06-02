/// SKILL: mensaena-features
/// Zentrale, robuste Launch-Hilfe für tel:/mailto:/https:-Links.
///
/// Hintergrund: An vielen Stellen wurde `launchUrl(Uri.parse(raw))` direkt
/// gerufen — ein fehlerhafter Wert (Uri.parse wirft) oder ein fehlender
/// Handler (z.B. kein Telefon-/Mail-Client, Web-Plattform) ließ den Tap mit
/// einer unbehandelten Exception abstürzen. Besonders kritisch bei Notruf-/
/// Hotline-Buttons. `safeLaunch` parst defensiv, fängt Fehler ab und zeigt
/// optional einen Hinweis.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Öffnet [raw] (tel:/mailto:/http(s):/geo: …) robust.
/// - [autoHttps]: ergänzt `https://` wenn kein Schema vorhanden ist.
/// - [context]: wenn gesetzt, wird bei Misserfolg eine Snackbar gezeigt.
/// Gibt true zurück, wenn der Launch (vermutlich) erfolgreich war.
Future<bool> safeLaunch(
  String raw, {
  LaunchMode mode = LaunchMode.platformDefault,
  bool autoHttps = false,
  BuildContext? context,
}) async {
  var url = raw.trim();
  if (autoHttps &&
      !url.startsWith('http://') &&
      !url.startsWith('https://') &&
      !url.contains(':')) {
    url = 'https://$url';
  }
  final messenger = context != null && context.mounted
      ? ScaffoldMessenger.maybeOf(context)
      : null;
  final uri = Uri.tryParse(url);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: mode);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && messenger != null) {
    messenger.showSnackBar(SnackBar(
      content: Text('common.linkOpenFailed'.tr()),
    ));
  }
  return ok;
}
