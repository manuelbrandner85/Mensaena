/// SKILL: mensaena-features + supabase
/// Helper-Repository fuer das Knowledge-/Wiki-Modul (knowledge_articles).
/// Aktuell nur Image-Upload — Liste/Detail/Insert werden direkt im
/// jeweiligen Screen via `sb.from('knowledge_articles')` gemacht.
library;

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class KnowledgeRepository {
  const KnowledgeRepository._();

  /// Upload eines Cover-Bildes zu Supabase Storage.
  /// Bucket-Order: 'knowledge-images' → fallback 'chat-images'.
  /// Returns Public-URL oder null bei Fehler.
  static Future<String?> uploadImage({
    required Uint8List bytes,
    required String userId,
    required String fileExt, // 'jpg' | 'png' | 'webp'
  }) async {
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = '$userId/$filename';
    for (final bucket in const ['knowledge-images', 'chat-images']) {
      try {
        await sb.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: 'image/$fileExt'),
            );
        return sb.storage.from(bucket).getPublicUrl(path);
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
