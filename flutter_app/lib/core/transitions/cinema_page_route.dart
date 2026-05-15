import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Cinema-Page-Transition: Outgoing fadet auf 0 + skaliert auf 0.98,
/// Incoming fadet von 0 auf 1 + skaliert von 1.02 auf 1.0.
/// Die Atmosphaere-Schichten bleiben stehen — der Wechsel passiert
/// AUF der Welt, nicht MIT ihr.
class CinemaPageTransition {
  static CustomTransitionPage<T> build<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Incoming page.
        final incomingScale = Tween<double>(begin: 1.02, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        final incomingFade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

        // Outgoing page (vorige Seite) — fade + minimal scale down.
        final outgoingScale = Tween<double>(begin: 1.0, end: 0.98).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic),
        );
        final outgoingFade = Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
        );

        return FadeTransition(
          opacity: outgoingFade,
          child: ScaleTransition(
            scale: outgoingScale,
            child: FadeTransition(
              opacity: incomingFade,
              child: ScaleTransition(
                scale: incomingScale,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
