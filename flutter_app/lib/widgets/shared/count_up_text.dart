/// SKILL: mensaena-design (Premium-Motion / Paket B Mikro-Physik)
/// CountUpText — Zahlen zählen beim ersten Erscheinen hoch statt hart
/// dazustehen (Karma, Zeitbank-Saldo, Stats).
///
/// Emil-Prinzip: Zweck = Zustands-Wahrnehmung („dieser Wert ist lebendig
/// und gehört dir"), kein Dauerfeuer — animiert genau EINMAL pro Mount.
/// EffectsGate: nur auf `full`; reduced/none → statischer Text.
/// Nicht-numerische Werte („3,5 h") → statischer Text (kein Parsen-Raten).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/effects_gate_provider.dart';

class CountUpText extends ConsumerWidget {
  const CountUpText(
    this.value, {
    required this.style,
    this.duration = const Duration(milliseconds: 650),
    super.key,
  });

  /// Anzeigewert. Wird nur animiert, wenn der GESAMTE String eine
  /// ganze Zahl ist — alles andere (formatierte Werte) bleibt statisch.
  final String value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = int.tryParse(value);
    final full = ref.watch(effectsProfileProvider).isFull;
    if (target == null || !full || target == 0) {
      return Text(value, style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: target.toDouble()),
      duration: duration,
      // ease-out: schnelle erste Ziffernsprünge, weiches Einrasten.
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}', style: style),
    );
  }
}
