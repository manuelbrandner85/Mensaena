/// SKILL: mensaena-design (Phase 4 — Echtzeit-3D, Stufe 1)
/// OrbitViewer — interaktiver 360°-Dreh-Viewer aus einer Frame-Sequenz.
///
/// Das ehrliche „drehbare Produkt" ohne Game-Engine: ein Objekt wurde aus
/// N gleichmaessig verteilten Winkeln aufgenommen/gerendert; der User
/// zieht horizontal und blaettert dadurch durch die Frames — fuehlt sich
/// an wie eine echte Drehung, ist aber nur Bild-Wechsel. Daher:
///   - laeuft auf JEDEM Geraet fluessig (kein 3D-Rendering, kein Decode),
///   - OTA-faehig (Frames sind Assets, kein natives Paket),
///   - Akku-neutral (rendert nur bei Interaktion neu).
///
/// EffectsGate:
///   full    → interaktiv: Drag + Fling-Momentum (Feder-Abklingen),
///             einmaliger „ziehen zum Drehen"-Hinweis.
///   reduced → interaktiv, aber ohne Auto-Spin/Momentum (nur direkter Drag).
///   none    → statisch: nur der Referenz-Frame, kein Preload der Sequenz.
///
/// Fehlt ein Frame, faellt er auf einen leeren Platz zurueck (nie Crash).
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/effects_gate_provider.dart';

class OrbitViewer extends ConsumerStatefulWidget {
  const OrbitViewer({
    required this.frameAssets,
    this.size = 220,
    this.hintLabel,
    super.key,
  }) : assert(frameAssets.length > 0, 'OrbitViewer braucht >=1 Frame');

  /// Asset-Pfade der Einzelframes, im Uhrzeigersinn 0..360°.
  final List<String> frameAssets;
  final double size;

  /// Optionaler „ziehen zum Drehen"-Hinweis (einmalig, nur full-Profil).
  final String? hintLabel;

  @override
  ConsumerState<OrbitViewer> createState() => _OrbitViewerState();
}

class _OrbitViewerState extends ConsumerState<OrbitViewer>
    with SingleTickerProviderStateMixin {
  late double _frame = 0;
  late final AnimationController _fling =
      AnimationController.unbounded(vsync: this);
  bool _preloaded = false;
  bool _hintShown = false;
  int _lastPreloadCenter = -1;

  int get _count => widget.frameAssets.length;

  // Dekodiert jedes Frame auf exakt display-size Pixel → weniger RAM-Druck.
  ImageProvider _provider(int i) => ResizeImage(
        AssetImage(widget.frameAssets[i]),
        width: widget.size.toInt(),
      );

  @override
  void dispose() {
    _fling.dispose();
    // Alle vorab geladenen Frame-Texturen aus dem ImageCache freigeben.
    for (var i = 0; i < _count; i++) {
      imageCache.evict(_provider(i));
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preloaded) return;
    _preloaded = true;
    final interactive =
        ref.read(effectsProfileProvider) != EffectsProfile.none;
    if (interactive) {
      _preloadWindow(_refIndex);
    } else {
      precacheImage(_provider(_refIndex), context);
    }
  }

  // Referenz-Frame fuer statische Darstellung: leicht gedreht wirkt
  // plastischer als die Frontal-Ansicht.
  int get _refIndex => (_count * 0.12).round() % _count;

  int get _index {
    final i = _frame.round() % _count;
    return i < 0 ? i + _count : i;
  }

  // Laedt nur ±2 Frames um center lazy vor; ist ein No-op wenn center gleich
  // dem letzten Preload-Mittelpunkt ist.
  void _preloadWindow(int center) {
    if (center == _lastPreloadCenter || !mounted) return;
    _lastPreloadCenter = center;
    for (var delta = -2; delta <= 2; delta++) {
      final i = ((center + delta) % _count + _count) % _count;
      precacheImage(_provider(i), context);
    }
  }

  void _onDragUpdate(DragUpdateDetails d, double dragUnit) {
    _fling.stop();
    setState(() {
      // size/2 horizontale Pixel = eine viertel Umdrehung (angenehm direkt).
      _frame += d.primaryDelta! * dragUnit;
      if (!_hintShown) _hintShown = true;
    });
    _preloadWindow(_index);
  }

  void _onDragEnd(DragEndDetails d, double dragUnit, bool momentum) {
    if (!momentum) return;
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 60) return;
    // Fling-Momentum: Frame-Geschwindigkeit klingt reibungsbehaftet ab.
    final sim = FrictionSimulation(
      0.135,
      _frame,
      v * dragUnit,
    );
    _fling
      ..value = _frame
      ..animateWith(sim);
    _fling.addListener(_onFling);
  }

  void _onFling() {
    setState(() => _frame = _fling.value);
    _preloadWindow(_index);
    if (!_fling.isAnimating) _fling.removeListener(_onFling);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(effectsProfileProvider);

    if (profile == EffectsProfile.none) {
      return _frameImage(_refIndex);
    }

    final momentum = profile.isFull;
    // Drag-Empfindlichkeit: ein Viertel der Breite = N/4 Frames.
    final dragUnit = (_count / (widget.size * 2));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, dragUnit),
          onHorizontalDragEnd: (d) => _onDragEnd(d, dragUnit, momentum),
          behavior: HitTestBehavior.opaque,
          child: RepaintBoundary(child: _frameImage(_index)),
        ),
        if (momentum && widget.hintLabel != null && !_hintShown) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swipe, size: 14, color: AppColors.mute),
              const SizedBox(width: 6),
              Text(widget.hintLabel!,
                  style: AppTypography.caption()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _frameImage(int i) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image(
        image: _provider(i),
        fit: BoxFit.contain,
        gaplessPlayback: true, // kein Flackern beim Frame-Wechsel
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
