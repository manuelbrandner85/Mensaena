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

/// Standard-Mensaena-Transition (Fade + Scale 0.97 → 1.0, 300ms easeOutCubic).
CustomTransitionPage<T> mensaenaTransition<T>({
  required LocalKey key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 300),
  Duration reverseDuration = const Duration(milliseconds: 220),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final scale = Tween<double>(
        begin: 0.97,
        end: 1.0,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: scale,
          child: child,
        ),
      );
    },
  );
}
