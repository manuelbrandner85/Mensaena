import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import 'supabase_service.dart';

/// Geteilte Inhalte — App-weit unterstützte Typen für Deep-Links.
/// Spiegelt 1:1 die GoRouter-Detail-Pfade.
enum ShareableType {
  post,
  event,
  group,
  marketplace,
  board,
  knowledge,
  crisis,
  profile,
  organization,
}

extension _SharePath on ShareableType {
  String get path {
    switch (this) {
      case ShareableType.post:         return 'posts';
      case ShareableType.event:        return 'events';
      case ShareableType.group:        return 'groups';
      case ShareableType.marketplace:  return 'marketplace';
      case ShareableType.board:        return 'board';
      case ShareableType.knowledge:    return 'knowledge';
      case ShareableType.crisis:       return 'crisis';
      case ShareableType.profile:      return 'profile';
      case ShareableType.organization: return 'organizations';
    }
  }
}

/// SKILL: mensaena-features
/// Sharing intern (DM) + extern (System-Share-Sheet). Generisch für alle
/// App-Inhalte. Die URLs spiegeln 1:1 die Web-/Deep-Link-Routen
/// `https://www.mensaena.de/dashboard/<typ>/<id>` → öffnen die App via
/// Intent-Filter oder fallen auf die Web-Version zurück.
class ShareService {
  const ShareService._();

  /// Generischer Share — wird für ALLE Inhaltstypen genutzt.
  /// [titleOrText] erscheint im Share-Sheet als Vorschau. Wenn null,
  /// wird "Schau dir das auf Mensaena an" als Default benutzt.
  static Future<void> share({
    required ShareableType type,
    required String id,
    String? titleOrText,
    String? subject,
  }) async {
    final url = buildUrl(type: type, id: id);
    final text = titleOrText == null || titleOrText.trim().isEmpty
        ? 'Schau dir das auf Mensaena an: $url'
        : '$titleOrText\n\n$url';
    await Share.share(text, subject: subject ?? titleOrText);
    if (type == ShareableType.post) {
      await _trackShare(postId: id, platform: 'external');
    }
  }

  /// Erzeugt den App-Deep-Link für einen Inhalt. Die Flutter-App ist
  /// eigenständig — geteilte Links öffnen die App (Schema `mensaena://`),
  /// NICHT mehr die Website www.mensaena.de.
  static String buildUrl({required ShareableType type, required String id}) {
    return 'mensaena://dashboard/${type.path}/$id';
  }

  /// Externe Share via System-Share-Sheet (WhatsApp, Signal, Mail …).
  /// Trackt den Share in post_shares (platform='external'). Beibehalten
  /// für Aufrufer die den alten Post-spezifischen API noch nutzen.
  static Future<void> shareExternal({
    required String postId,
    required String text,
    String? subject,
  }) async {
    await Share.share(text, subject: subject);
    await _trackShare(postId: postId, platform: 'external');
  }

  /// Erzeugt die URL die in einem QR-Code codiert werden soll (Posts).
  static String buildShareUrl({required String postId}) =>
      buildUrl(type: ShareableType.post, id: postId);

  /// Interne Share an einen User (Conversation).
  /// Trackt den Share in post_shares (platform='internal').
  static Future<void> shareInternal({
    required String postId,
    required String toUserId,
  }) async {
    await _trackShare(postId: postId, platform: 'internal');
  }

  static Future<void> _trackShare({
    required String postId,
    required String platform,
  }) async {
    try {
      await sb.from('post_shares').insert({
        'post_id': postId,
        'user_id': SupabaseService.currentUser?.id,
        'platform': platform,
      });
    } catch (_) {
      // analytics-only, kein UX-Impact bei Fehler
    }
  }

  /// Mensaena-Einladung als pre-built Share-Text. Verweist auf die App
  /// (Deep-Link), nicht mehr auf die Website.
  static String inviteText({String? referralCode}) {
    final url = referralCode == null
        ? 'mensaena://invite'
        : 'mensaena://invite?ref=$referralCode';
    return 'Komm zu ${AppConfig.appName} – die Nachbarschafts-App.\n\n$url';
  }
}
