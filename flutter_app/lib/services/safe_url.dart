/// SKILL: mensaena-architektur
/// URL- und Route-Validation gegen Hijacking.
///
/// Verwendet ueberall wo Daten aus FCM-Payloads, Push-Notifications oder
/// externen APIs in `context.go()` oder `launchUrl()` fliessen.
library;

import 'package:url_launcher/url_launcher.dart';

/// Validiert eine interne Route (z.B. aus FCM-data['url']). Akzeptiert
/// nur `/dashboard/...` oder `/auth?...` — alles andere (externe URLs,
/// admin-Pfade ohne dashboard-Prefix, Schemes) wird verworfen.
///
/// Returns null bei ungueltigem Input.
String? safeInternalRoute(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  // Keine Schemes erlauben (kein http://, kein javascript:, kein file://)
  if (raw.contains('://')) return null;
  if (raw.contains(':') && !raw.startsWith('/')) return null;
  // Muss mit Slash beginnen.
  if (!raw.startsWith('/')) return null;
  // Whitelist von Top-Level-Pfaden.
  const allowedPrefixes = [
    '/dashboard',
    '/auth',
  ];
  for (final p in allowedPrefixes) {
    if (raw == p || raw.startsWith('$p/') || raw.startsWith('$p?')) {
      return raw;
    }
  }
  return null;
}

/// Sicherer `launchUrl`-Wrapper. Akzeptiert nur http:// und https://
/// Schemes — verhindert javascript:, file://, content://, intent://
/// Injection via kompromittierte Upstream-APIs.
///
/// Returns true wenn Launch erfolgreich, false sonst (inkl. invalider URL).
Future<bool> safeLaunchUrl(String? raw,
    {LaunchMode mode = LaunchMode.externalApplication}) async {
  if (raw == null || raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  // Host muss existieren (verhindert https:/path-tricks).
  if (uri.host.isEmpty) return false;
  try {
    return await launchUrl(uri, mode: mode);
  } catch (_) {
    return false;
  }
}

/// Spezialvariante fuer `mailto:` / `tel:` Schemes (legitime user-tap
/// Aktionen). Lehnt alles andere ab.
Future<bool> safeLaunchContact(String? raw) async {
  if (raw == null || raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  if (uri.scheme != 'mailto' && uri.scheme != 'tel' && uri.scheme != 'sms') {
    return false;
  }
  try {
    return await launchUrl(uri);
  } catch (_) {
    return false;
  }
}
