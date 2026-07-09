import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

/// SKILL: mensaena-architektur
/// Deep-Link Handling — fängt eingehende `https://www.mensaena.de/...`-Links
/// nativ ab (Android-App-Links + iOS-Universal-Links) und reicht sie als
/// interne GoRouter-Routen weiter.
///
/// Mapping:
///   https://www.mensaena.de/dashboard/posts/<id> → /dashboard/posts/<id>
///   https://www.mensaena.de/get/invite/<code>    → /auth?mode=register&ref=<code>
///   https://www.mensaena.de/auth?ref=<code>      → /auth?ref=<code>
///   mensaena://...                                → /...
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  final StreamController<String> _controller =
      StreamController<String>.broadcast();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// Stream eingehender Deep-Links als App-interne Routen.
  Stream<String> get linkStream => _controller.stream;

  /// Einmalige Initialisierung beim App-Start. Hört auf eingehende
  /// Links und holt den Initial-Link (falls die App über einen Link
  /// gekaltstartet wurde). Mehrfach-Aufrufe sind no-op.
  Future<void> initialize({GoRouter? router}) async {
    if (_initialized) return;
    _initialized = true;
    try {
      // Cold-Start-Link.
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial, router);
    } catch (_) {/* fail-silent */}
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, router),
      onError: (_) {/* fail-silent */},
      cancelOnError: false,
    );
  }

  void _handle(Uri uri, GoRouter? router) {
    final route = toInternalRoute(uri);
    if (route == null) return;
    _controller.add(route);
    // Sofort navigieren wenn der Router schon bereit ist.
    router?.go(route);
  }

  /// Konvertiert eine eingehende URL in eine GoRouter-Route.
  /// Returns null wenn URL nicht zu uns gehoert.
  ///
  /// Formate:
  ///   https://www.mensaena.de/get/<typ>/<id>   (Smart-Share-Link, App Link)
  ///       → intern auf /dashboard/<typ>/<id> abgebildet
  ///   https://www.mensaena.de/dashboard/...     (direkter App-Link-Pfad)
  ///   mensaena://dashboard/...                  (Custom-Scheme, JS-Bridge der
  ///       Web-Smart-Link-Seite) → host ist erstes Routen-Segment
  static String? toInternalRoute(Uri uri) {
    final query = uri.query.isEmpty ? '' : '?${uri.query}';
    if (uri.scheme == 'mensaena') {
      // Custom-Scheme: host = erstes Pfadsegment.
      final path = uri.path.isEmpty ? '' : uri.path;
      final route = '/${uri.host}$path'.replaceAll('//', '/');
      return route.isEmpty ? '/' : '$route$query';
    }
    if (uri.host.isNotEmpty && !uri.host.contains('mensaena')) {
      return null;
    }
    var path = uri.path.isEmpty ? '/' : uri.path;
    // Smart-Share-Links: /get/<typ>/<id> ist nur der klickbare Außen-Link →
    // intern auf den echten Detail-Pfad /dashboard/<typ>/<id> abbilden.
    // Ausnahme: /get/invite/<code> hat keinen Dashboard-Screen — das ist
    // ein Einladungscode, der auf die Registrierung (mit Banner) zielt.
    if (path.startsWith('/get/')) {
      final rest = path.substring('/get/'.length);
      final parts = rest.split('/');
      if (parts.length >= 2 && parts[0] == 'invite') {
        return '/auth?mode=register&ref=${parts[1]}';
      }
      path = '/dashboard/$rest';
    }
    return '$path$query';
  }

  /// Test-Hook: simuliert einen eingehenden Link.
  void simulateLink(String internalRoute) => _controller.add(internalRoute);

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _controller.close();
  }
}
