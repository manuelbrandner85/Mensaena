import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/user_profile.dart';

class ProfileService {
  final SupabaseClient _client;

  ProfileService(this._client);

  Future<UserProfile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<UserProfile?> getMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return getProfile(userId);
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', userId);
  }

  Future<String?> uploadAvatar(String userId, Uint8List bytes, String ext) async {
    final path = '$userId/avatar.$ext';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    await updateProfile(userId, {'avatar_url': url});
    return url;
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    final data = await _client
        .from('profiles')
        .select()
        .or('name.ilike.%$query%,nickname.ilike.%$query%')
        .limit(20);
    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getProfileStats(String userId) async {
    final posts = await _client
        .from('posts')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('user_id', userId)
        .eq('status', 'active');

    final interactions = await _client
        .from('interactions')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('helper_id', userId)
        .eq('status', 'completed');

    final ratings = await _client
        .from('trust_ratings')
        .select('score')
        .eq('rated_id', userId);

    double avgRating = 0;
    if ((ratings as List).isNotEmpty) {
      final sum = ratings.fold<int>(0, (s, r) => s + (r['score'] as int));
      avgRating = sum / ratings.length;
    }

    return {
      'posts_count': posts.count ?? 0,
      'interactions_count': interactions.count ?? 0,
      'ratings_count': (ratings).length,
      'average_rating': avgRating,
    };
  }
}
