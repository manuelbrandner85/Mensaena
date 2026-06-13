import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/emergency_alert.dart';
import '../repositories/emergency_repository.dart';

/// Aktive Notfall-Alerts in der Nähe (RLS-gefiltert, <500 m).
/// autoDispose: Realtime-Channel wird beim Widget-Dispose geschlossen.
final emergencyAlertsProvider =
    StreamProvider.autoDispose<List<EmergencyAlert>>((ref) {
  return EmergencyRepository.watchNearby();
});
