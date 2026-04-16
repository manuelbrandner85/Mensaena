import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/timebank_service.dart';
import 'package:mensaena/models/timebank_entry.dart';

final timebankServiceProvider = Provider<TimebankService>((ref) {
  return TimebankService(ref.watch(supabaseProvider));
});

final timebankEntriesProvider = FutureProvider<List<TimebankEntry>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.read(timebankServiceProvider).getEntries(userId);
});

final timebankBalanceProvider = FutureProvider<Map<String, double>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {'given': 0, 'received': 0, 'balance': 0};
  return ref.read(timebankServiceProvider).getBalance(userId);
});
