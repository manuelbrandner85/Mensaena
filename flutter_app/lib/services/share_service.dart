import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import 'supabase_service.dart';

/// SKILL: mensaena-features
/// Sharing intern (DM) + extern (System-Share-Sheet). QR-Code-Trigger
/// liefert nur die zu codierende URL — Rendering uebernimmt qr_flutter
/// im UI-Layer (damit Tests ohne Plugin laufen).
class ShareService {
  const ShareService._();

  /// Externe Share via System-Share-Sheet (WhatsApp, Signal, Mail...).
  /// Trackt den Share in post_shares (platform='external').
  static Future<void> shareExternal({
    required String postId,
    required String text,
    String? subject,
  }) async {
    await Share.share(text, subject: subject);
    await _trackShare(postId: postId, platform: 'external');
  }

  /// Erzeugt die URL die in einem QR-Code codiert werden soll.
  static String buildShareUrl({
    required String postId,
  }) {
    return 'https://www.mensaena.de/dashboard/posts/$postId';
  }

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

  /// Mensaena-Einladung als pre-built Share-Text.
  static String inviteText({String? referralCode}) {
    final url = referralCode == null
        ? '${AppConfig.appName.toLowerCase()}.de'
        : 'mensaena.de?ref=$referralCode';
    return 'Komm zu Mensaena – die Nachbarschafts-Plattform.\n\n$url';
  }
}
