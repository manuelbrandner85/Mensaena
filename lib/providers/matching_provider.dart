import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/matching_service.dart';
import 'package:mensaena/models/match.dart';

final matchingServiceProvider = Provider<MatchingService>((ref) {
  return MatchingService(ref.watch(supabaseProvider));
});

final matchesProvider = FutureProvider<List<Match>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.read(matchingServiceProvider).getMatches(userId);
});

final matchDetailProvider = FutureProvider.family<Match?, String>((ref, matchId) async {
  return ref.read(matchingServiceProvider).getMatch(matchId);
});

final matchCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  return ref.read(matchingServiceProvider).getMatchCounts(userId);
});
