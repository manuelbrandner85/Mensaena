/// SKILL: mensaena-design
/// AnimatedStatNumber — Bloomberg-Style Number-Tween. Zahlen "rollen"
/// von ihrem alten Wert zum neuen anstatt hart umzuspringen. Nutzt die
/// AppTypography.stat() für konsistenten Premium-Look.
///
/// Lite-Mode-bewusst: bei aktivem Lite-Mode entfällt die Animation,
/// der neue Wert wird direkt gesetzt → schont alte Geräte.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/device_tier_service.dart';

class AnimatedStatNumber extends ConsumerWidget {
  const AnimatedStatNumber({
    required this.value,
    this.style,
    this.size = 44,
    this.color = AppColors.ink,
    this.weight = FontWeight.w800,
    this.duration = const Duration(milliseconds: 700),
    this.formatter,
    super.key,
  });

  final int value;
  final TextStyle? style;
  final double size;
  final Color color;
  final FontWeight weight;
  final Duration duration;
  final String Function(int)? formatter;

  static String _defaultFormat(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lite = ref.watch(liteModeActiveProvider);
    final effectiveStyle =
        style ?? AppTypography.stat(size: size, color: color, weight: weight);
    final fmt = formatter ?? _defaultFormat;
    if (lite) {
      // Im Lite-Mode keine Tween-Animation — direkter Wert.
      return Text(fmt(value), style: effectiveStyle);
    }
    // TweenAnimationBuilder verhält sich so: ändert sich das Tween-Objekt
    // (hier weil `value` und damit `end` neu ist), animiert er VOM zuletzt
    // gerenderten Wert ZUM neuen `end`. Initial begin=0 → erstmals rollt
    // die Zahl elegant von 0 hoch.
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(fmt(v), style: effectiveStyle),
    );
  }
}
