/// SKILL: mensaena-architektur
/// Zentrale Konstanten der App (kein Secret, nur Config).
class AppConfig {
  const AppConfig._();

  static const String appName = 'Mensaena';
  static const String appTagline = 'Nachbarschaftshilfe — einfach gemacht.';
  static const String supportEmail = 'info@mensaena.de';

  /// Default-Radius fuer Nachbarschafts-Suche (km).
  static const int defaultRadiusKm = 10;

  /// Default-AGS fuer NINA-Warnungen (000000000000 = bundesweit).
  static const String defaultAgs = '000000000000';

  /// Geo-Verifizierung Toleranz in Metern.
  static const int geoVerifyToleranceMeters = 2000;

  /// Notification-Cache TTL (Sekunden).
  static const int notifPrefCacheTtlSec = 60;

  /// NINA-Cache TTL (Sekunden).
  static const int ninaCacheTtlSec = 900;

  /// LiveKit JWT Default-Laufzeit (Stunden).
  static const int livekitJwtHours = 4;

  /// Cookie-Banner Localstorage-Key.
  static const String cookieConsentKey = 'mensaena_cookie_consent_v1';
}
