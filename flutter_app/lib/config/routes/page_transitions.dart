/// SKILL: mensaena-design
/// Page-Transitions — Cinematic-Foundation Phase A.
///
/// `mensaenaTransition` ist die Standard-Transition für Detail-Routen:
/// Slide-Up (16px) + Fade in 300ms mit `Curves.easeOutCubic`.
/// Genug "Schwung" um das Detail als neues Layer einzuführen,
/// ohne zu lange zu wirken.
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

/// Standard-Mensaena-Detail-Transition (Slide-Up + Fade, 300ms easeOutCubic).
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
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}
