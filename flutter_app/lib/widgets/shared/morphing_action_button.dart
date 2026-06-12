/// SKILL: mensaena-design (Premium-Motion / Paket B Mikro-Physik)
/// MorphingActionButton — EIN Button morpht durch seine Zustände:
/// Idle → Spinner → Häkchen (bleibt). Zustands-Feedback am Ort der
/// Aktion statt (nur) im SnackBar.
///
/// Emil-Prinzip: State-Indication ist ein gültiger Animations-Zweck —
/// auch unter Reduce-Motion bleibt der 180-ms-Crossfade (Opacity-only
/// hilft dem Verständnis, keine Bewegung). Nach Erfolg bleibt der
/// Button im Done-Zustand (kommuniziert „bereits erledigt").
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum _Phase { idle, busy, done }

class MorphingActionButton extends StatefulWidget {
  const MorphingActionButton({
    required this.icon,
    required this.label,
    required this.action,
    this.successLabel,
    super.key,
  });

  final IconData icon;
  final String label;

  /// Label im Done-Zustand. null = [label] bleibt.
  final String? successLabel;

  /// true = Erfolg (Button bleibt auf Done), false = zurück zu Idle.
  final Future<bool> Function() action;

  @override
  State<MorphingActionButton> createState() => _MorphingActionButtonState();
}

class _MorphingActionButtonState extends State<MorphingActionButton> {
  _Phase _phase = _Phase.idle;

  Future<void> _run() async {
    if (_phase != _Phase.idle) return;
    setState(() => _phase = _Phase.busy);
    final ok = await widget.action();
    if (!mounted) return;
    setState(() => _phase = ok ? _Phase.done : _Phase.idle);
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_phase) {
      _Phase.busy => const SizedBox(
          key: ValueKey('busy'),
          width: 18,
          height: 18,
          // Flotter Spinner = gefühlte Geschwindigkeit.
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      _Phase.done => Row(
          key: const ValueKey('done'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.check, size: 18),
            const SizedBox(width: 8),
            Text(widget.successLabel ?? widget.label),
          ],
        ),
      _Phase.idle => Row(
          key: const ValueKey('idle'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 18),
            const SizedBox(width: 8),
            Text(widget.label),
          ],
        ),
    };
    return ElevatedButton(
      onPressed: _phase == _Phase.idle ? _run : null,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            // Nie von scale(0): 0.92 reicht für den Morph-Eindruck.
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
              child: child,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}
