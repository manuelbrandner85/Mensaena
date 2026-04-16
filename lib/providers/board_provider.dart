import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/board_service.dart';
import 'package:mensaena/models/board_post.dart';

final boardServiceProvider = Provider<BoardService>((ref) {
  return BoardService(ref.watch(supabaseProvider));
});

final boardPostsProvider = FutureProvider.family<List<BoardPost>, Map<String, String?>>((ref, params) async {
  return ref.read(boardServiceProvider).getBoardPosts(
    category: params['category'],
    search: params['search'],
  );
});

final boardPostDetailProvider = FutureProvider.family<BoardPost?, String>((ref, postId) async {
  return ref.read(boardServiceProvider).getBoardPost(postId);
});

final boardCommentsProvider = FutureProvider.family<List<BoardComment>, String>((ref, postId) async {
  return ref.read(boardServiceProvider).getComments(postId);
});
