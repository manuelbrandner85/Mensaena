import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/post_service.dart';
import 'package:mensaena/models/post.dart';

final postServiceProvider = Provider<PostService>((ref) {
  return PostService(ref.watch(supabaseProvider));
});

final postsProvider = FutureProvider.family<List<Post>, Map<String, String?>>((ref, params) async {
  return ref.read(postServiceProvider).getPosts(
    type: params['type'],
    category: params['category'],
    search: params['search'],
    status: params['status'],
  );
});

final postDetailProvider = FutureProvider.family<Post?, String>((ref, postId) async {
  return ref.read(postServiceProvider).getPost(postId);
});

final userPostsProvider = FutureProvider.family<List<Post>, String>((ref, userId) async {
  return ref.read(postServiceProvider).getUserPosts(userId);
});

final savedPostsProvider = FutureProvider<List<Post>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.read(postServiceProvider).getSavedPosts(userId);
});

final nearbyPostsProvider = FutureProvider.family<List<Post>, Map<String, double>>((ref, coords) async {
  return ref.read(postServiceProvider).getNearbyPosts(
    lat: coords['lat']!,
    lng: coords['lng']!,
    radiusKm: coords['radius'] ?? 50,
  );
});
