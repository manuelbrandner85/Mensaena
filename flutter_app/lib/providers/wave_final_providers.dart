/// SKILL: mensaena-features — Wave-Final Riverpod-Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/wave_final_repositories.dart';

final accountDeletionRepoProvider =
    Provider<AccountDeletionRepository>((ref) => AccountDeletionRepository());
final userStreaksRepoProvider =
    Provider<UserStreaksRepository>((ref) => UserStreaksRepository());
final karmaLogRepoProvider =
    Provider<KarmaLogRepository>((ref) => KarmaLogRepository());
final eventCheckinsRepoProvider =
    Provider<EventCheckinsRepository>((ref) => EventCheckinsRepository());
final streamClipsRepoProvider =
    Provider<StreamClipsRepository>((ref) => StreamClipsRepository());

final accountDeletionStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ref.read(accountDeletionRepoProvider).current();
});

final userStreakProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ref.read(userStreaksRepoProvider).current();
});

final karmaLogProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(karmaLogRepoProvider).recent();
});

final eventCheckinCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, eventId) async {
  return ref.read(eventCheckinsRepoProvider).count(eventId);
});

final eventCheckinStatusProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, eventId) async {
  return ref.read(eventCheckinsRepoProvider).hasCheckedIn(eventId);
});
