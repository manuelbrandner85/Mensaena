import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase/database_service.dart';

/// Stream aller aktuell aktiven Krisen aus der `crises`-Tabelle.
/// Trigger fuer den globalen Atmosphaere-Shift (CinemaScaffold isCrisis).
final activeCrisesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return db.watchActiveCrises();
});

/// Bool-Shortcut: gibt es UEBERHAUPT eine aktive Krise?
final isCrisisActiveProvider = Provider<bool>((ref) {
  final asyncCrises = ref.watch(activeCrisesProvider);
  return asyncCrises.maybeWhen(
    data: (list) => list.isNotEmpty,
    orElse: () => false,
  );
});

/// Die "primary" Krise (juengster Eintrag), oder null.
final primaryCrisisProvider = Provider<Map<String, dynamic>?>((ref) {
  final list = ref.watch(activeCrisesProvider).asData?.value ?? const [];
  return list.isEmpty ? null : list.first;
});
