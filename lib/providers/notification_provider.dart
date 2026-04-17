import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/notification_service.dart';
import 'package:mensaena/models/notification.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(supabaseProvider));
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.read(notificationServiceProvider).getNotifications(userId);
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  return ref.read(notificationServiceProvider).getUnreadCount(userId);
});

final unreadCountsByTypeProvider = FutureProvider<Map<String, int>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  try {
    return await ref.read(notificationServiceProvider).getUnreadCountsByType(userId);
  } catch (_) {
    return const {};
  }
});
