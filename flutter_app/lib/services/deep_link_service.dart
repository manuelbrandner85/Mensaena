import 'dart:async';

/// SKILL: mensaena-architektur
/// Deep-Link Handling — initial Link + Stream fuer eingehende Links.
/// Verarbeitet Mensaena-spezifische Schemas:
///   https://www.mensaena.de/dashboard/posts/<id> → /dashboard/posts/<id>
///   https://www.mensaena.de/auth?ref=<code>     → /auth?ref=<code>
///
/// Phase 1 Skeleton: nur Pfad-Mapping, keine Platform-Channel-Implementierung.
/// Reale Anbindung an app_links/uni_links Package erfolgt in Phase 3
/// (zusammen mit dem Login-Flow der den ref-Param interpretieren muss).
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// Stream eingehender Deep-Links als App-interne Routen.
  Stream<String> get linkStream => _controller.stream;

  /// Konvertiert eine eingehende URL in eine GoRouter-Route.
  /// Returns null wenn URL nicht zu uns gehoert.
  static String? toInternalRoute(Uri uri) {
    if (uri.host.isNotEmpty &&
        !uri.host.contains('mensaena') &&
        uri.scheme != 'mensaena') {
      return null;
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.query.isEmpty ? '' : '?${uri.query}';
    return '$path$query';
  }

  /// Test-/Phase-3-Hook: simuliert einen eingehenden Link.
  void simulateLink(String internalRoute) => _controller.add(internalRoute);

  void dispose() => _controller.close();
}
