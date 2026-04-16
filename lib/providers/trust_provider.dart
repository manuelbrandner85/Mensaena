import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/trust_service.dart';
import 'package:mensaena/models/trust_rating.dart';

final trustServiceProvider = Provider<TrustService>((ref) {
  return TrustService(ref.watch(supabaseProvider));
});

final trustScoreProvider = FutureProvider.family<TrustScoreData, String>((ref, userId) async {
  return ref.read(trustServiceProvider).getTrustScore(userId);
});

final userRatingsProvider = FutureProvider.family<List<TrustRating>, String>((ref, userId) async {
  return ref.read(trustServiceProvider).getRatingsForUser(userId);
});
