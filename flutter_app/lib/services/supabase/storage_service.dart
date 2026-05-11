import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Storage-Helpers fuer die 8 Mensaena-Buckets.
/// Pfad-Konvention: `{userId}/{uuid}.{ext}` damit RLS user-scoped greift.
class StorageService {
  const StorageService();

  SupabaseClient get _c => supabase.client;

  static const avatarsBucket = 'avatars';
  static const postImagesBucket = 'post-images';
  static const chatMediaBucket = 'chat-media';
  static const boardImagesBucket = 'board-images';
  static const eventImagesBucket = 'event-images';
  static const marketplaceBucket = 'marketplace';
  static const wikiImagesBucket = 'wiki-images';
  static const groupImagesBucket = 'group-images';

  Future<String> uploadFile({
    required String bucket,
    required String path,
    required File file,
    String? contentType,
  }) async {
    await _c.storage.from(bucket).upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );
    return _c.storage.from(bucket).getPublicUrl(path);
  }

  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    await _c.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _c.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteFile(String bucket, String path) {
    return _c.storage.from(bucket).remove([path]);
  }
}

const storage = StorageService();
