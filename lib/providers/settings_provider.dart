import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';

final settingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  final profile = await ref.read(profileServiceProvider).getProfile(userId);
  if (profile == null) return {};
  return profile.toJson();
});
