/// SKILL: mensaena-design
/// Page-Transitions — Phase 5b: benannte Transition-Familie.
///
/// EIN System statt 147 Einzelentscheidungen. Jede Route deklariert nur
/// noch den NAMEN ihres Übergangs (siehe Tabelle im Phase-5b-Plan):
///
///   AppTransitions.forward    Drill-down (Standard, ex-mensaenaTransition)
///   AppTransitions.surface    Geschwister-Wechsel (Tabs/Bereiche), Fade-Through
///   AppTransitions.sheet      Create-Flows/Composer — schiebt von unten auf
///   AppTransitions.immersive  Vollbild-Räume (Map/Call/Live) — Eintauchen
///   AppTransitions.calm       Krisen-Kontext & A11y — reiner Fade, kurz
///
/// `mensaenaTransition` bleibt als Alias auf `forward` erhalten — die
/// bestehenden ~147 Router-Aufrufstellen brauchen keine Änderung.
///
/// EffectsGate-Integration: JEDE Transition fragt das EffectsProfile —
///   none    → kein Übergang (Screen erscheint sofort)
///   reduced → reiner Fade (180 ms)
///   full    → volle Choreografie
/// Damit sind reduceMotion/seniorMode/Lite-Tier automatisch bedient.
///
/// Bewusst NUR Transform + Opacity (GPU-leicht, Impeller-freundlich,
/// kein Blur/saveLayer mid-flight). Container-Transform (`reveal`) folgt
/// mit dem `animations`-Paket im geplanten Version-Bump.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/effects_gate_provider.dart';

/// Back-Compat-Alias — Standard-Drill-down für alle Bestandsrouten.
CustomTransitionPage<T> mensaenaTransition<T>({
  required LocalKey key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 340),
  Duration reverseDuration = const Duration(milliseconds: 260),
}) =>
    AppTransitions.forward<T>(
      key: key,
      child: child,
      duration: duration,
      reverseDuration: reverseDuration,
    );

class AppTransitions {
  const AppTransitions._();

  /// Liest das EffectsProfile ohne ConsumerWidget (Router-Kontext).
  static EffectsProfile _profileOf(BuildContext context) {
    try {
      return ProviderScope.containerOf(context, listen: false)
          .read(effectsProfileProvider);
    } catch (_) {
      return EffectsProfile.full; // Tests/ohne Scope: volle Effekte.
    }
  }

  /// Gemeinsamer Gate-Wrapper: none = instant, reduced = Fade.
  /// Liefert null wenn die volle Choreografie laufen darf.
  static Widget? _gatedFallback(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    switch (_profileOf(context)) {
      case EffectsProfile.none:
        return child;
      case EffectsProfile.reduced:
        return FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      case EffectsProfile.full:
        return null;
    }
  }

  // ── forward — filmischer Tiefen-Schnitt (Drill-down-Standard) ─────────
  /// EINTRETEND: Fade + Depth-Zoom (0.92→1.0) + Aufwärts-Parallax (14px→0).
  /// VERLASSEND: zieht sich zurück (1.0→0.96) und dimmt auf 0.4 —
  /// der „stacked layers"-Effekt. Nur Transform+Opacity.
  static CustomTransitionPage<T> forward<T>({
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
        final fallback = _gatedFallback(context, animation, child);
        if (fallback != null) return fallback;

        final inCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final outCurve = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeInOutCubic,
        );
        final enterScale =
            Tween<double>(begin: 0.92, end: 1.0).animate(inCurve);
        final enterSlide =
            Tween<double>(begin: 14.0, end: 0.0).animate(inCurve);
        final exitScale =
            Tween<double>(begin: 1.0, end: 0.96).animate(outCurve);
        final exitDim = Tween<double>(begin: 1.0, end: 0.4).animate(outCurve);

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

  // ── surface — Fade-Through für Geschwister-Wechsel (Tabs) ─────────────
  /// Kein Richtungs-Versprechen: alte Seite blendet schnell aus, neue
  /// blendet in der zweiten Hälfte mit Mikro-Zoom (0.96→1.0) ein.
  static CustomTransitionPage<T> surface<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fallback = _gatedFallback(context, animation, child);
        if (fallback != null) return fallback;

        final fadeIn = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
        );
        final zoomIn = Tween<double>(begin: 0.96, end: 1.0).animate(fadeIn);
        return FadeTransition(
          opacity: fadeIn,
          child: ScaleTransition(scale: zoomIn, child: child),
        );
      },
    );
  }

  // ── sheet — Create-Flows/Composer schieben von unten auf ──────────────
  /// Federnd gedämpft (easeOutBack, stark abgeschwächt) — fühlt sich wie
  /// AppMotion.gentle an, ohne dass die Route einen eigenen Controller
  /// bräuchte. Verlassende Seite dimmt nur leicht (bleibt als Kontext).
  static CustomTransitionPage<T> sheet<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fallback = _gatedFallback(context, animation, child);
        if (fallback != null) return fallback;

        final slide = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.18, 1.05, 0.30, 1.0), // gentle-Spring-Näherung
          reverseCurve: Curves.easeInCubic,
        );
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(slide);
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }

  // ── immersive — Eintritt in Vollbild-Räume (Map/Call/Live) ────────────
  /// Verlassende Seite tritt deutlich zurück (0.92) und dimmt stark —
  /// die App bleibt spürbar „dahinter" liegen; neue Seite gleitet auf.
  static CustomTransitionPage<T> immersive<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fallback = _gatedFallback(context, animation, child);
        if (fallback != null) return fallback;

        final inCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final outCurve = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeInOutCubic,
        );
        final enterSlide = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(inCurve);
        final exitScale =
            Tween<double>(begin: 1.0, end: 0.92).animate(outCurve);
        final exitDim = Tween<double>(begin: 1.0, end: 0.25).animate(outCurve);

        return AnimatedBuilder(
          animation: Listenable.merge([animation, secondaryAnimation]),
          builder: (context, _) {
            return Opacity(
              opacity: inCurve.value * exitDim.value,
              child: Transform.scale(
                scale: exitScale.value,
                child: SlideTransition(position: enterSlide, child: child),
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  // ── calm — Krisen-Kontext & maximale Ruhe ──────────────────────────────
  /// Reiner, kurzer Fade. Im Stress-Kontext ist Bewegung Feature-Verzicht.
  static CustomTransitionPage<T> calm<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 160),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (_profileOf(context) == EffectsProfile.none) return child;
        return FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
}
