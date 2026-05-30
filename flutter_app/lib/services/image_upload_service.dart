/// SKILL: mensaena-features
/// Zentrale Bild-Upload-Hilfe für Create-Screens. Lädt lokale Bilder in einen
/// Supabase-Storage-Bucket und liefert die öffentlichen URLs zurück.
///
/// Vorher war die Upload-Schleife pro Create-Screen kopiert. Diese Hilfe
/// vereinheitlicht Content-Type-Erkennung, Pfad-Schema (uid/timestamp-i.ext)
/// und Fehler-Callback, sodass Krise/Brett/Gruppen denselben Pfad nutzen.
library;

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class ImageUploadService {
  const ImageUploadService._();

  /// Lädt [files] in [bucket] hoch (Default `post-images`) und gibt die
  /// öffentlichen URLs zurück. Pro Fehler wird [onError] mit dem 1-basierten
  /// Index + Meldung aufgerufen, der Rest wird weiter hochgeladen.
  static Future<List<String>> upload(
    List<File> files, {
    String bucket = 'post-images',
    void Function(int index, String error)? onError,
  }) async {
    final urls = <String>[];
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return urls;
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final raw = file.path.split('.').last.toLowerCase();
      final ext = (raw.length <= 4 && raw.isNotEmpty) ? raw : 'jpg';
      final contentType = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' || 'heif' => 'image/heic',
        _ => 'image/jpeg',
      };
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}-$i.$ext';
      try {
        await sb.storage.from(bucket).upload(
              path,
              file,
              fileOptions:
                  FileOptions(upsert: false, contentType: contentType),
            );
        urls.add(sb.storage.from(bucket).getPublicUrl(path));
      } catch (e) {
        onError?.call(i + 1, '$e');
      }
    }
    return urls;
  }
}
