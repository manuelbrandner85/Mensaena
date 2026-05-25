/// SKILL: mensaena-design
/// 3D-Tilt-Card — Accelerometer-getriebener Parallax-Effekt.
///
/// Liest das Geraet-Tilting via `sensors_plus.accelerometerEventStream`
/// und kippt den Child-Widget leicht in X/Y-Achse. Subtle (max 6 Grad),
/// damit nicht ablenkend. Ideal fuer Hero-Bilder, Profil-Avatare,
/// Stat-Cards die hervorstechen sollen.
///
/// Reagiert NICHT bei Cinema-Intensity = minimal (Battery-Save).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../config/theme/cinema_theme.dart';
import '../../providers/cinema_provider.dart';

/// Maximaler Kipp-Winkel in Radianten (~6 Grad pro Achse).
const _maxTiltRad = 0.105;

/// Wie stark der Sensor-Wert auf die Animation einschlaegt.
/// Niedriger = ruhiger, hoeher = sportlicher. 0.08 fuehlt sich natuerlich an.
const _sensitivity = 0.08;

/// Wie schnell die Tilt-Werte auf Sensor-Aenderungen reagieren (Low-Pass).
/// 0.15 = 85% Smoothing pro Frame.
const _smoothing = 0.15;

/// Sensor-Sampling-Period — 60 fps = 16ms reicht voellig.
const _sampleInterval = SensorInterval.uiInterval;

class TiltCard extends ConsumerStatefulWidget {
  const TiltCard({
    required this.child,
    this.intensity = 1.0,
    this.perspective = 0.0015,
    this.borderRadius = 14,
    super.key,
  });

  /// Inhalts-Widget (Bild, Card, Container).
  final Widget child;

  /// 0.0–1.5 globale Multiplier; <1.0 fuer subtile Effekte, >1.0 fuer
  /// auffaellige Hero-Bereiche (Profile-Cover). Default 1.0.
  final double intensity;

  /// Perspektive-Tiefe der 3D-Projektion. 0.0015 ist ein guter
  /// Mittelwert, niedriger = flacher, hoeher = staerker.
  final double perspective;

  /// Border-Radius fuer Hit-Test-Clip — damit der Tilt-Effekt nicht
  /// ueber die Card-Kanten hinaus geht.
  final double borderRadius;

  @override
  ConsumerState<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends ConsumerState<TiltCard> {
  StreamSubscription<AccelerometerEvent>? _sub;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _cancelSub();
    try {
      _sub = accelerometerEventStream(samplingPeriod: _sampleInterval)
          .listen(_onSample, onError: (_) {});
    } catch (_) {
      // Sensor not available — gracefully degrade (no tilt animation).
      _sub = null;
    }
  }

  /// Robust cancel: sensors_plus throws "No active stream to cancel" on
  /// Android when the stream wasn't actually active. Swallow that — it
  /// crashes the framework if uncaught during dispose.
  void _cancelSub() {
    final s = _sub;
    if (s == null) return;
    _sub = null;
    try {
      s.cancel();
    } catch (_) {}
  }

  void _onSample(AccelerometerEvent e) {
    // Geraet-Achsen: y = lange Hochkant-Achse (top↑ pos), x = quer (right↑ pos).
    // Negation, damit Card sich beim Vorne-Kippen nach hinten kippt (Parallax).
    final targetX = (-e.y * _sensitivity)
        .clamp(-_maxTiltRad, _maxTiltRad)
        .toDouble();
    final targetY = (e.x * _sensitivity)
        .clamp(-_maxTiltRad, _maxTiltRad)
        .toDouble();
    final nx = _tiltX + (targetX - _tiltX) * _smoothing;
    final ny = _tiltY + (targetY - _tiltY) * _smoothing;
    if (!mounted) return;
    if ((nx - _tiltX).abs() < 0.0005 && (ny - _tiltY).abs() < 0.0005) return;
    setState(() {
      _tiltX = nx;
      _tiltY = ny;
    });
  }

  @override
  void dispose() {
    _cancelSub();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intensity = ref.watch(cinemaIntensityProvider);
    // Battery-Save / Minimal-Modus → kein Tilt
    if (intensity == CinemaIntensity.minimal) {
      return widget.child;
    }
    final mult = widget.intensity * intensity.multiplier;
    final rx = _tiltX * mult;
    final ry = _tiltY * mult;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, widget.perspective)
        ..rotateX(rx)
        ..rotateY(ry)
        // Leichte Translation gibt das "schwebt"-Gefuehl
        ..translate(math.sin(ry) * 4.0, -math.sin(rx) * 4.0),
      child: widget.child,
    );
  }
}
