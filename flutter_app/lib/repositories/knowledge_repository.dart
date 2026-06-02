/// SKILL: mensaena-features + supabase
/// Helper-Repository fuer das Knowledge-/Wiki-Modul (knowledge_articles).
/// Aktuell nur Image-Upload — Liste/Detail/Insert werden direkt im
/// jeweiligen Screen via `sb.from('knowledge_articles')` gemacht.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class KnowledgeRepository {
  const KnowledgeRepository._();

  /// Upload eines Cover-Bildes zu Supabase Storage. Vorher: silently auf
  /// 'chat-images' gefallen, jetzt: nur 'knowledge-images' (Bucket wurde
  /// in Migration 20260602120000 angelegt).
  static Future<String?> uploadImage({
    required Uint8List bytes,
    required String userId,
    required String fileExt, // 'jpg' | 'png' | 'webp'
  }) async {
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = '$userId/$filename';
    try {
      await sb.storage.from('knowledge-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );
      return sb.storage.from('knowledge-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('uploadKnowledgeImage failed: $e');
      return null;
    }
  }
}
