/// SKILL: mensaena-design
/// Page-Transitions — Cinematic-Foundation Phase A (V23).
///
/// `mensaenaTransition` ist die Standard-Transition fuer ALLE Routen:
/// Fade-In + subtiler Scale (0.97 → 1.0) in 300ms `Curves.easeOutCubic`.
/// Cinematic, ohne zu lange zu wirken.
///
/// Anwendung über `go_router` mit `pageBuilder`:
/// ```dart
/// GoRoute(
///   path: '/dashboard/posts/:id',
///   pageBuilder: (ctx, st) => mensaenaTransition<void>(
///     key: st.pageKey,
///     child: PostDetailScreen(postId: st.pathParameters['id']!),
///   ),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Cinematic-Mensaena-Transition (V24): filmischer Tiefen-Schnitt.
///
/// EINTRETENDE Seite: Fade + Depth-Zoom (0.92 → 1.0) + sanfter Aufwärts-
/// Parallax (14 px → 0). Wirkt wie eine Kamera, die auf die neue Szene
/// zufährt.
///
/// VERLASSENDE Seite (secondaryAnimation): zieht sich leicht zurück
/// (1.0 → 0.96) und dimmt (1.0 → 0.4 Opacity) — der „stacked layers"-
/// Effekt von Netflix/iOS, bei dem die alte Szene hinter die neue gleitet.
///
/// Alles nur Transform + Opacity → GPU-leicht, ARM32/64-tauglich.
CustomTransitionPage<T> mensaenaTransition<T>({
  required LocalKey key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 340),
  Duration reverseDuration = const Duration(milliseconds: 260),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final inCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final outCurve = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInOutCubic,
      );

      // Eintretende Seite.
      final enterScale =
          Tween<double>(begin: 0.92, end: 1.0).animate(inCurve);
      final enterSlide = Tween<double>(begin: 14.0, end: 0.0).animate(inCurve);

      // Verlassende Seite (zieht sich nach hinten + dimmt).
      final exitScale =
          Tween<double>(begin: 1.0, end: 0.96).animate(outCurve);
      final exitDim =
          Tween<double>(begin: 1.0, end: 0.4).animate(outCurve);

      return AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        builder: (context, _) {
          return Opacity(
            opacity: inCurve.value * exitDim.value,
            child: Transform.translate(
              offset: Offset(0, enterSlide.value),
              child: Transform.scale(
                scale: enterScale.value * exitScale.value,
                child: child,
              ),
            ),
          );
        },
        child: child,
      );
    },
  );
}
