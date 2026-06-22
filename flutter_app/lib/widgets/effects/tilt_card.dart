/// SKILL: mensaena-design
/// 3D-Tilt-Card — Accelerometer-getriebener Parallax-Effekt.
///
/// CRITICAL: shared singleton accelerometer subscription via
/// _SharedAccelerometer.stream. Vorher hatten N TiltCards jeweils
/// eigene accelerometerEventStream-Subscriptions auf den nativen
/// sensors_plus EventChannel → race conditions beim dispose → die
/// nächste Card cancel'te einen schon-toten Stream → PlatformException
/// "No active stream to cancel" mit Engine-Crash.
///
/// Jetzt: 1 native subscription. Jede TiltCard hört nur den broadcast
/// stream — kein direkter sensor-channel mehr.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../providers/effects_gate_provider.dart';

const _maxTiltRad = 0.105;
const _sensitivity = 0.08;
const _smoothing = 0.15;
const _sampleInterval = SensorInterval.normalInterval;

/// Singleton broadcast stream über sensors_plus. Nur EINE native
/// subscription für ALLE Verbraucher (TiltCards + Cinema-Parallax) — niemals
/// eine zweite native Subscription anlegen (Race-Conditions beim dispose).
class SharedAccelerometer {
  static StreamController<AccelerometerEvent>? _controller;
  static StreamSubscription<AccelerometerEvent>? _nativeSub;
  static int _listenerCount = 0;

  /// Lazy-init und ref-counted: schliesst die native subscription
  /// erst wenn der letzte Listener weg ist.
  static Stream<AccelerometerEvent> stream() {
    _controller ??= StreamController<AccelerometerEvent>.broadcast(
      onListen: _attach,
      onCancel: _maybeDetach,
    );
    return _controller!.stream;
  }

  static void _attach() {
    _listenerCount++;
    if (_nativeSub != null) return;
    try {
      _nativeSub = accelerometerEventStream(samplingPeriod: _sampleInterval)
          .listen(
            (e) => _controller?.add(e),
            onError: (_) {},
            cancelOnError: false,
          );
    } catch (e) {
      debugPrint('[TiltCard] native sensor unavailable: $e');
    }
  }

  static void _maybeDetach() {
    // Guard gegen Unterlauf: doppeltes Detach (schnelle Navigation) darf den
    // Zaehler nicht negativ machen, sonst haelt die naechste TiltCard den
    // Sensor-Stream faelschlich fuer aktiv.
    if (_listenerCount > 0) _listenerCount--;
    if (_listenerCount > 0) return;
    final s = _nativeSub;
    _nativeSub = null;
    // Fire-and-forget cancel. catchError statt try/catch weil
    // cancel() ein Future zurückgibt und der "No active stream to
    // cancel"-Error ASYNCHRON kommt.
    s?.cancel().catchError((_) {});
  }
}

class TiltCard extends ConsumerStatefulWidget {
  const TiltCard({
    required this.child,
    this.intensity = 1.0,
    this.perspective = 0.0015,
    this.borderRadius = 14,
    super.key,
  });

  final Widget child;
  final double intensity;
  final double perspective;
  final double borderRadius;

  @override
  ConsumerState<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends ConsumerState<TiltCard> {
  StreamSubscription<AccelerometerEvent>? _sub;
  double _tiltX = 0;
  double _tiltY = 0;

  // Frame-Throttle: max 15fps statt 60fps für Tilt-Updates.
  // 4 TiltCards × 60 setState/s = 240 Rebuilds/s → jetzt 60 Rebuilds/s.
  DateTime _lastUpdate = DateTime(0);
  static const _minInterval = Duration(milliseconds: 66);

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    try {
      _sub = SharedAccelerometer.stream().listen(
        _onSample,
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      _sub = null;
    }
  }

  void _onSample(AccelerometerEvent e) {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.difference(_lastUpdate) < _minInterval) return;
    _lastUpdate = now;
    final targetX = (-e.y * _sensitivity).clamp(-_maxTiltRad, _maxTiltRad).toDouble();
    final targetY = (e.x * _sensitivity).clamp(-_maxTiltRad, _maxTiltRad).toDouble();
    final nx = _tiltX + (targetX - _tiltX) * _smoothing;
    final ny = _tiltY + (targetY - _tiltY) * _smoothing;
    if ((nx - _tiltX).abs() < 0.001 && (ny - _tiltY).abs() < 0.001) return;
    setState(() {
      _tiltX = nx;
      _tiltY = ny;
    });
  }

  @override
  void dispose() {
    // Cancel ist auf einem broadcast-stream sicher — kein native
    // channel-cancel. Trotzdem fire-and-forget + catchError.
    _sub?.cancel().catchError((_) {});
    _sub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // EffectsGate statt Einzel-Signal: respektiert jetzt auch
    // reduceMotion/seniorMode und Lite-Tier (vorher nur CinemaIntensity).
    final profile = ref.watch(effectsProfileProvider);
    if (profile.isOff) {
      return widget.child;
    }
    final mult = widget.intensity * profile.intensityFactor;
    final rx = _tiltX * mult;
    final ry = _tiltY * mult;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, widget.perspective)
        ..rotateX(rx)
        ..rotateY(ry)
        ..translate(math.sin(ry) * 4.0, -math.sin(rx) * 4.0),
      child: widget.child,
    );
  }
}
