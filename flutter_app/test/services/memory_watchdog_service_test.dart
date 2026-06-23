import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/services/memory_watchdog_service.dart';

void main() {
  group('MemoryWatchdogService.evictAllDataCaches', () {
    test('runs without throwing on an empty/fresh state', () {
      expect(MemoryWatchdogService.instance.evictAllDataCaches, returnsNormally);
    });

    test('is idempotent — repeated calls stay safe', () {
      MemoryWatchdogService.instance.evictAllDataCaches();
      expect(MemoryWatchdogService.instance.evictAllDataCaches, returnsNormally);
    });
  });
}
