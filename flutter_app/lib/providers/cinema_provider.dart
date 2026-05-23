import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/theme/cinema_theme.dart';

/// SKILL: mensaena-design
/// Cinema-Theme Riverpod-Provider — verwaltet aktuelle Phase + User-Override.

const _modeStorageKey = 'cinema_mode_v1';
const _storage = FlutterSecureStorage();

/// User-Override-Mode (persistiert in flutter_secure_storage).
class CinemaModeNotifier extends StateNotifier<CinemaMode> {
  CinemaModeNotifier() : super(CinemaMode.auto) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _modeStorageKey);
      state = CinemaModeX.fromKey(raw);
    } catch (_) {
      // ignore — default ist auto
    }
  }

  Future<void> set(CinemaMode mode) async {
    state = mode;
    try {
      await _storage.write(key: _modeStorageKey, value: mode.key);
    } catch (_) {}
  }
}

final cinemaModeProvider =
    StateNotifierProvider<CinemaModeNotifier, CinemaMode>((ref) {
  return CinemaModeNotifier();
});

/// Aktuelle Phase basierend auf Uhrzeit. Refresht alle 60s.
final cinemaPhaseProvider = StreamProvider<CinemaPhase>((ref) async* {
  yield CinemaTheme.resolveForTime(DateTime.now());
  final timer = Stream<void>.periodic(const Duration(seconds: 60));
  await for (final _ in timer) {
    yield CinemaTheme.resolveForTime(DateTime.now());
  }
});

/// Effektive Phase (User-Override gewinnt ueber Auto).
/// Liefert null wenn Mode = off (Effekte komplett aus).
final effectiveCinemaPhaseProvider = Provider<CinemaPhase?>((ref) {
  final mode = ref.watch(cinemaModeProvider);
  switch (mode) {
    case CinemaMode.off:
      return null;
    case CinemaMode.forceNight:
      return CinemaPhase.night;
    case CinemaMode.forceDay:
      return CinemaPhase.day;
    case CinemaMode.forceDusk:
      return CinemaPhase.dusk;
    case CinemaMode.auto:
      return ref.watch(cinemaPhaseProvider).value ??
          CinemaTheme.resolveForTime(DateTime.now());
  }
});
