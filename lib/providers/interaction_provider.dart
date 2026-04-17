import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/interaction_service.dart';
import 'package:mensaena/models/interaction.dart';

final interactionServiceProvider = Provider<InteractionService>((ref) {
  return InteractionService(ref.watch(supabaseProvider));
});

final interactionsProvider = FutureProvider<List<Interaction>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.read(interactionServiceProvider).getInteractions(userId);
});

final interactionDetailProvider = FutureProvider.family<Interaction?, String>((ref, id) async {
  return ref.read(interactionServiceProvider).getInteraction(id);
});

final interactionStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  return ref.read(interactionServiceProvider).getStats(userId);
});
