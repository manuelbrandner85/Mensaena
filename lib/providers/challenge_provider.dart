import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/challenge_service.dart';
import 'package:mensaena/models/challenge.dart';

final challengeServiceProvider = Provider<ChallengeService>((ref) {
  return ChallengeService(ref.watch(supabaseProvider));
});

final challengesProvider = FutureProvider<List<Challenge>>((ref) async {
  return ref.read(challengeServiceProvider).getChallenges(status: 'active');
});

final challengeDetailProvider = FutureProvider.family<Challenge?, String>((ref, id) async {
  return ref.read(challengeServiceProvider).getChallenge(id);
});
