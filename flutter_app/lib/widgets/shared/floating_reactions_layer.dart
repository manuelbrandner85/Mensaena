/// SKILL: mensaena-features + mensaena-design
/// FloatingReactionsLayer — animierte Emojis steigen vom unteren
/// Bildrand hoch und fade-en aus. Wie FaceTime/TikTok-Live.
///
/// Controller-Pattern: parent uebergibt einen Controller, ruft
/// controller.spawn('❤️') auf wenn Reaktion ankommt.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class FloatingReactionsController extends ChangeNotifier {
  final List<_Reaction> _items = <_Reaction>[];

  /// Read-only-View fuer den Layer. Typ ist intentional Object damit
  /// _Reaction privat bleibt — der Layer-Widget weiss intern wie er es
  /// rendert via _items[i] direkten Zugriff.
  int get itemCount => _items.length;

  void spawn(String emoji) {
    final r = _Reaction(
      emoji: emoji,
      id: DateTime.now().microsecondsSinceEpoch,
      startX: math.Random().nextDouble() * 0.8 + 0.1,
      drift: (math.Random().nextDouble() - 0.5) * 0.2,
    );
    _items.add(r);
    notifyListeners();
    // Auto-remove nach 3s
    Future<void>.delayed(const Duration(milliseconds: 3000), () {
      _items.removeWhere((x) => x.id == r.id);
      if (!_disposed) notifyListeners();
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _Reaction {
  _Reaction({
    required this.emoji,
    required this.id,
    required this.startX,
    required this.drift,
  });
  final String emoji;
  final int id;
  final double startX;
  final double drift;
}

class FloatingReactionsLayer extends StatelessWidget {
  const FloatingReactionsLayer({required this.controller, super.key});

  final FloatingReactionsController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              for (final r in controller._items)
                _FloatingReactionItem(reaction: r, key: ValueKey(r.id)),
            ],
          );
        },
      ),
    );
  }
}

class _FloatingReactionItem extends StatefulWidget {
  const _FloatingReactionItem({required this.reaction, super.key});
  final _Reaction reaction;
  @override
  State<_FloatingReactionItem> createState() => _FloatingReactionItemState();
}

class _FloatingReactionItemState extends State<_FloatingReactionItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Crash-Fix (BoxParentData → StackParentData, 1288 Live-Crashes):
    // Vorher gab dieses build() ein `Positioned` zurück, das innerhalb
    // von `LayoutBuilder` + `AnimatedBuilder` saß. Der `LayoutBuilder`
    // erzeugt ein eigenes RenderObject mit BoxParentData, sodass das
    // Positioned beim Mount versuchte, StackParentData auf einen
    // BoxParentData-Parent zu setzen → TypeCast-Crash.
    //
    // Lösung: Positioned.fill ALS ÄUSSERSTES Widget (sitzt direkt
    // unter Stack), darin Transform.translate für die animierte
    // Position. Ergebnis: visuell identisch, kein ParentData-Mismatch.
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _progress,
            builder: (_, __) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;
              final t = _progress.value;
              final y = h - 60 - (h - 100) * t;
              final x = w * widget.reaction.startX +
                  math.sin(t * math.pi * 2) * 30 +
                  widget.reaction.drift * w * t;
              final opacity = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3);
              final scale = 0.5 + 0.6 * math.min(t * 4, 1.0);
              return Stack(
                children: [
                  Positioned(
                    left: x.clamp(0.0, w - 40),
                    top: y.clamp(0.0, h - 40),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale,
                          child: Text(
                            widget.reaction.emoji,
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Bottom-Bar mit 6 Reaktions-Emojis. Caller bekommt onSpawn-Callback —
/// dort: lokal spawnen + via RoomEvents an alle senden.
class ReactionPickerBar extends StatelessWidget {
  const ReactionPickerBar({required this.onPick, super.key});
  final void Function(String emoji) onPick;

  static const List<String> emojis = [
    '❤️',
    '👏',
    '😂',
    '🎉',
    '🙏',
    '🌟',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in emojis) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onPick(e),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
