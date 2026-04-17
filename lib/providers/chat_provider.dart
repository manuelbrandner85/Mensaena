import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/chat_service.dart';
import 'package:mensaena/models/conversation.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(supabaseProvider));
});

final conversationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.read(chatServiceProvider).getConversations(userId);
});

final messagesProvider = FutureProvider.family<List<Message>, String>((ref, conversationId) async {
  return ref.read(chatServiceProvider).getMessages(conversationId);
});

final chatChannelsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.read(chatServiceProvider).getCommunityConversations(userId);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  return ref.read(chatServiceProvider).getUnreadCount(userId);
});
