import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/crisis_service.dart';
import 'package:mensaena/models/crisis.dart';

final crisisServiceProvider = Provider<CrisisService>((ref) {
  return CrisisService(ref.watch(supabaseProvider));
});

final crisesProvider = FutureProvider<List<Crisis>>((ref) async {
  return ref.read(crisisServiceProvider).getCrises();
});

final activeCrisesProvider = FutureProvider<List<Crisis>>((ref) async {
  return ref.read(crisisServiceProvider).getActiveCrises();
});

final crisisDetailProvider = FutureProvider.family<Crisis?, String>((ref, crisisId) async {
  return ref.read(crisisServiceProvider).getCrisis(crisisId);
});

final crisisHelpersProvider = FutureProvider.family<List<CrisisHelper>, String>((ref, crisisId) async {
  return ref.read(crisisServiceProvider).getHelpers(crisisId);
});

final crisisUpdatesProvider = FutureProvider.family<List<CrisisUpdate>, String>((ref, crisisId) async {
  return ref.read(crisisServiceProvider).getUpdates(crisisId);
});

final crisisStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.read(crisisServiceProvider).getCrisisStats();
});
