import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Generisches Shader-Layer: laedt einen .frag (FragmentProgram), bindet
/// uSize + uTime + bis zu 2 zusaetzliche Float-Uniforms und rendert per
/// CustomPaint. Stiller Fallback (leerer Container), solange das Programm
/// nicht geladen ist oder die Plattform Fragment-Shader nicht unterstuetzt.
class ShaderLayer extends StatefulWidget {
  final String assetPath;
  final double Function(double t)? extraUniform;
  final double Function(double t)? extraUniform2;
  final BlendMode blendMode;

  const ShaderLayer({
    super.key,
    required this.assetPath,
    this.extraUniform,
    this.extraUniform2,
    this.blendMode = BlendMode.srcOver,
  });

  @override
  State<ShaderLayer> createState() => _ShaderLayerState();
}

class _ShaderLayerState extends State<ShaderLayer>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late final AnimationController _ctrl;
  late final Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _stopwatch = Stopwatch()..start();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(widget.assetPath);
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (_) {
      // Stiller Fallback (kein GPU / Web ohne Impeller / fehlendes Asset).
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _ShaderPainter(
              shader: _shader!,
              time: _stopwatch.elapsedMilliseconds / 1000.0,
              extra: widget.extraUniform?.call(_ctrl.value) ?? 0,
              extra2: widget.extraUniform2?.call(_ctrl.value) ?? 0,
              blendMode: widget.blendMode,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final double extra;
  final double extra2;
  final BlendMode blendMode;

  _ShaderPainter({
    required this.shader,
    required this.time,
    required this.extra,
    required this.extra2,
    required this.blendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform-Reihenfolge MUSS zur .frag-Datei passen:
    // 0,1: uSize (vec2)  |  2: uTime  |  3: extra  |  4: extra2
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, extra)
      ..setFloat(4, extra2);

    final paint = Paint()
      ..shader = shader
      ..blendMode = blendMode;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter old) =>
      old.time != time || old.extra != extra || old.extra2 != extra2;
}
