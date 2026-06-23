/// SKILL: mensaena-design (Cinema-Hyperreal)
/// CinemaParallax — verschiebt den Hintergrund subtil beim Neigen des Geräts
/// (3D-Tiefe). Nutzt den GETEILTEN Accelerometer (SharedAccelerometer) —
/// niemals eine eigene native Subscription. Updates gedrosselt (≤15 fps) und
/// geglättet. Aktiv NUR bei vollen Effekten + Schalter an; sonst rendert es
/// den child unverändert (kein Sensor, keine Last) → greift auch der
/// Auto-Crash-Schutz (profile fällt auf reduced → Parallax aus).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../providers/cinema_provider.dart';
import '../../providers/effects_gate_provider.dart';
import 'tilt_card.dart' show SharedAccelerometer;

class CinemaParallax extends ConsumerStatefulWidget {
  const CinemaParallax({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CinemaParallax> createState() => _CinemaParallaxState();
}

class _CinemaParallaxState extends ConsumerState<CinemaParallax> {
  StreamSubscription<AccelerometerEvent>? _sub;
  bool _subActive = false;
  double _dx = 0;
  double _dy = 0;
  DateTime _last = DateTime(0);

  static const _minInterval = Duration(milliseconds: 66); // ≤15 fps
  static const _maxShift = 14.0; // px
  static const _smoothing = 0.12;
  static const _gravity = 9.81;

  void _applySub(bool active) {
    if (active && _sub == null) {
      try {
        _sub = SharedAccelerometer.stream().listen(
          _onSample,
          onError: (_) {},
          cancelOnError: false,
        );
      } catch (_) {
        _sub = null;
      }
    } else if (!active && _sub != null) {
      _sub?.cancel().catchError((_) {});
      _sub = null;
      if (mounted && (_dx != 0 || _dy != 0)) {
        setState(() {
          _dx = 0;
          _dy = 0;
        });
      }
    }
  }

  void _onSample(AccelerometerEvent e) {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.difference(_last) < _minInterval) return;
    _last = now;
    final tx =
        (-e.x / _gravity * _maxShift).clamp(-_maxShift, _maxShift).toDouble();
    final ty =
        (e.y / _gravity * _maxShift).clamp(-_maxShift, _maxShift).toDouble();
    final nx = _dx + (tx - _dx) * _smoothing;
    final ny = _dy + (ty - _dy) * _smoothing;
    if ((nx - _dx).abs() < 0.05 && (ny - _dy).abs() < 0.05) return;
    setState(() {
      _dx = nx;
      _dy = ny;
    });
  }

  @override
  void dispose() {
    _sub?.cancel().catchError((_) {});
    _sub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Parallax ist leicht (günstiger Transform) → läuft auf jedem Gerät,
    // sobald der Schalter an ist; nur reduceMotion (isOff) schaltet ab.
    final active = ref.watch(cinemaParallaxProvider) &&
        !ref.watch(effectsProfileProvider).isOff;
    // Subscription nur bei Zustandswechsel an/abmelden (nicht jeden Build).
    if (active != _subActive) {
      _subActive = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySub(active);
      });
    }
    if (!active) return widget.child;
    // Leichte Überskalierung, damit beim Verschieben keine Ränder zeigen.
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scale(1.08)
        ..translate(_dx, _dy),
      child: widget.child,
    );
  }
}
