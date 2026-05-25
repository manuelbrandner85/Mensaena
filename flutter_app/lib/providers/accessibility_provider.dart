/// SKILL: mensaena-features
/// Accessibility-Suite (F20): zentrale Prefs fuer
/// - textScale (0.85 / 1.0 / 1.15 / 1.3)
/// - reduceMotion (Bool — schaltet Bloom-Pulse / Konfetti / Animationen aus)
/// - highContrast (Bool — staerkere Borders / kontrastreichere Texte)
///
/// Persistiert on-device in flutter_secure_storage.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class A11yPrefs {
  const A11yPrefs({
    required this.textScale,
    required this.reduceMotion,
    required this.highContrast,
  });

  final double textScale;
  final bool reduceMotion;
  final bool highContrast;

  static const initial = A11yPrefs(
    textScale: 1.0,
    reduceMotion: false,
    highContrast: false,
  );

  A11yPrefs copyWith({
    double? textScale,
    bool? reduceMotion,
    bool? highContrast,
  }) {
    return A11yPrefs(
      textScale: textScale ?? this.textScale,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      highContrast: highContrast ?? this.highContrast,
    );
  }
}

class A11yNotifier extends Notifier<A11yPrefs> {
  static const _storage = FlutterSecureStorage();
  static const _scaleKey = 'mensaena_a11y_text_scale_v1';
  static const _motionKey = 'mensaena_a11y_reduce_motion_v1';
  static const _contrastKey = 'mensaena_a11y_high_contrast_v1';

  @override
  A11yPrefs build() {
    // Initial = default. Async load updated den State danach.
    _load();
    return A11yPrefs.initial;
  }

  Future<void> _load() async {
    try {
      final scale = double.tryParse(
              await _storage.read(key: _scaleKey) ?? '') ??
          1.0;
      final motion = (await _storage.read(key: _motionKey)) == 'true';
      final contrast = (await _storage.read(key: _contrastKey)) == 'true';
      state = A11yPrefs(
        textScale: scale.clamp(0.85, 1.3),
        reduceMotion: motion,
        highContrast: contrast,
      );
    } catch (_) {}
  }

  Future<void> setTextScale(double v) async {
    final next = v.clamp(0.85, 1.3);
    state = state.copyWith(textScale: next);
    try {
      await _storage.write(key: _scaleKey, value: '$next');
    } catch (_) {}
  }

  Future<void> setReduceMotion(bool v) async {
    state = state.copyWith(reduceMotion: v);
    try {
      await _storage.write(key: _motionKey, value: v ? 'true' : 'false');
    } catch (_) {}
  }

  Future<void> setHighContrast(bool v) async {
    state = state.copyWith(highContrast: v);
    try {
      await _storage.write(key: _contrastKey, value: v ? 'true' : 'false');
    } catch (_) {}
  }
}

final a11yProvider = NotifierProvider<A11yNotifier, A11yPrefs>(A11yNotifier.new);

/// Quick-Accessor fuer Widgets ohne Ref. Liefert default wenn kein Provider.
bool reduceMotionFromRef(WidgetRef ref) =>
    ref.read(a11yProvider).reduceMotion;
