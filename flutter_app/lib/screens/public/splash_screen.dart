import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme/app_colors.dart';
import '../../services/audio_feedback_service.dart';
import '../../services/supabase_service.dart';
import 'onboarding_tour_screen.dart';

/// SKILL: mensaena-design (Higgsfield-Cinematic)
/// Splash-Screen v2 — „Bewusstsein" im Unreal-Engine-Stil.
///
/// Vollflächiges, fotorealistisches Higgsfield-Keyart (kosmische Dusk-
/// Landschaft mit volumetrischen God-Rays, Milchstraße, schwebendem Blatt
/// und goldenen Partikeln — assets/images/splash_cosmos.webp) als Bühne.
/// Darüber das ECHTE Mensaena-Logo (transparentes PNG, Emblem + Wortmarke)
/// mit cinematischem Reveal: Ken-Burns auf dem Hintergrund, Logo schwebt
/// mit 3D-Settle + atmendem Gold-Glow ein, „Tudum"-Punch im Höhepunkt,
/// anamorphotischer Lens-Sweep, Letterbox-Bars + Cinematic-Exit-Flash.
/// Gesamtdauer ~4.4s.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Master-Phasen (t = 0..1):
  //   0.00-0.16: BG-Fade-in + Letterbox + Ken-Burns Start
  //   0.16-0.52: Logo schwebt ein (3D-Settle + Glow-Atmen)
  //   0.52-0.78: Hold + Tagline
  //   0.78-0.88: HÖHEPUNKT — Logo-Punch + Lens-Sweep + Energie-Ring
  //   0.88-0.96: Hold
  //   0.96-1.00: Cinematic-Cut (Weiß-Flash → Schwarz-Zoom-Through)
  late final AnimationController _ctrl;
  late final AnimationController _ambientCtrl; // Partikel + Glow-Atmen
  Timer? _navTimer;

  // Lebendiger Higgsfield-Loop hinter dem Logo. Frame 1 == splash_cosmos.webp
  // (image-to-video mit Start=End-Frame), darum ist das Standbild ein
  // nahtloser Fallback bis Init fertig / bei Decoder-Fehler.
  VideoPlayerController? _video;
  bool _videoReady = false;

  static const _totalDurationMs = 4400;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalDurationMs),
    )..forward();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    // Startup-Sound DIREKT beim Splash (zuverlässiges Timing): vorher lief
    // er erst nach den Background-Init-awaits in main.dart und kam oft zu
    // spät, wenn der Splash schon weg war. Fire-and-forget, fail-silent.
    AudioFeedbackService.instance.playStartupMelody();
    _initVideo();
    _navTimer = Timer(
      const Duration(milliseconds: _totalDurationMs + 200),
      _navigate,
    );
  }

  Future<void> _initVideo() async {
    // mixWithOthers: true → der stumme Loop greift NICHT den Audio-Fokus
    // (sonst würde ExoPlayer den Startup-Sound ducken/abwürgen).
    final v = VideoPlayerController.asset(
      'assets/videos/splash_cosmos.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = v;
    try {
      await v.initialize();
      await v.setLooping(true);
      await v.setVolume(0);
      if (!mounted) {
        await v.dispose();
        return;
      }
      await v.play();
      setState(() => _videoReady = true);
    } catch (_) {
      // Decoder/Asset-Fehler → Standbild bleibt (kein Bruch).
      _video = null;
      try {
        await v.dispose();
      } catch (_) {}
    }
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    if (!SupabaseService.isLoggedIn) {
      context.go('/auth');
      return;
    }
    final shouldOnboard = await OnboardingTourScreen.shouldShow();
    if (!mounted) return;
    context.go(shouldOnboard ? '/onboarding' : '/dashboard');
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _ctrl.dispose();
    _ambientCtrl.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Gold-/Bronze-Akzent passend zum Higgsfield-Keyart.
    const gold = AppColors.bronze;

    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([_ctrl, _ambientCtrl]),
        builder: (_, __) {
          final t = _ctrl.value;
          final bgT = _ease(t / 0.16);
          final logoT = _ease((t - 0.16) / 0.36);
          final taglineT = ((t - 0.52) / 0.20).clamp(0.0, 1.0);
          final climaxT = _bump((t - 0.78) / 0.10);
          final ringT = ((t - 0.78) / 0.18).clamp(0.0, 1.0);
          final ringEased = 1.0 - math.pow(1.0 - ringT, 2).toDouble();
          final flashT = _bump((t - 0.96) / 0.03);
          final exitT = ((t - 0.97) / 0.03).clamp(0.0, 1.0);

          // Ken-Burns: Hintergrund zoomt 1.05 → 1.13 + driftet minimal hoch,
          // sodass die Milchstraße langsam „aufsteigt".
          final bgScale = 1.05 + t * 0.08;
          final bgDriftY = -t * size.height * 0.03;

          // Logo: Reveal-Scale + Tudum-Punch + Exit-Zoom-Through.
          final logoScale =
              0.86 + logoT * 0.14 + climaxT * 0.06 + exitT * 0.55;
          final logoOpacity = logoT.clamp(0.0, 1.0) * (1.0 - exitT);
          final ambient = _ambientCtrl.value * 2 * math.pi;

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Higgsfield-Hintergrund: lebendiger Video-Loop (sobald
              // bereit), sonst das frame-identische Standbild. Ken-Burns
              // auf beidem für zusätzliche Tiefe.
              Transform.translate(
                offset: Offset(0, bgDriftY),
                child: Transform.scale(
                  scale: bgScale,
                  child: Opacity(
                    opacity: bgT,
                    child: (_videoReady && _video != null)
                        ? FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: _video!.value.size.width,
                              height: _video!.value.size.height,
                              child: VideoPlayer(_video!),
                            ),
                          )
                        : Image.asset(
                            'assets/images/splash_cosmos.webp',
                            fit: BoxFit.cover,
                            width: size.width,
                            height: size.height,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                                color: AppColors.voidColor),
                          ),
                  ),
                ),
              ),

              // ── Tiefen-Scrim (oben dunkler fürs Logo, unten Halt) ──
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.voidColor.withValues(alpha: 0.55 * bgT),
                        Colors.transparent,
                        AppColors.voidColor.withValues(alpha: 0.35 * bgT),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Goldene Bokeh-Partikel (driften über das Keyart) ──
              ..._buildParticles(size, gold, bgT, ambient),

              // ── Energie-Ring beim „Tudum" ─────────────────────────
              if (ringT > 0 && ringT < 1)
                Align(
                  alignment: const Alignment(0, -0.34),
                  child: IgnorePointer(
                    child: Container(
                      width: 120 + ringEased * 300,
                      height: 120 + ringEased * 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              gold.withValues(alpha: 0.5 * (1 - ringT)),
                          width: 2.0 * (1 - ringT) + 0.4,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Logo-Lockup (Emblem + Wortmarke) zentriert-oben ───
              Align(
                alignment: const Alignment(0, -0.30),
                child: Transform.scale(
                  scale: logoScale,
                  child: Opacity(
                    opacity: logoOpacity,
                    child: SizedBox(
                      width: size.width * 0.78,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Atmender Gold-Halo hinter dem Emblem.
                          Positioned(
                            top: 0,
                            child: Container(
                              width: size.width * 0.6,
                              height: size.width * 0.6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    gold.withValues(
                                        alpha: (0.22 +
                                                0.10 * math.sin(ambient) +
                                                0.25 * climaxT)
                                            .clamp(0.0, 0.6)),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Das ECHTE Logo — 3D-Settle beim Einschweben.
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0011)
                              ..rotateX((1 - logoT) * 0.45),
                            child: Image.asset(
                              'assets/images/mensaena-logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Anamorphotischer Lens-Sweep im Höhepunkt ──────────
              if (logoT > 0.4)
                Align(
                  alignment: const Alignment(0, -0.30),
                  child: IgnorePointer(
                    child: FractionallySizedBox(
                      widthFactor: 0.9,
                      child: Container(
                        height: 3 + 12 * climaxT,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              gold.withValues(
                                  alpha: 0.08 + 0.4 * climaxT),
                              Colors.white.withValues(
                                  alpha: 0.15 + 0.55 * climaxT),
                              gold.withValues(
                                  alpha: 0.08 + 0.4 * climaxT),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.32, 0.5, 0.68, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  gold.withValues(alpha: 0.4 * climaxT),
                              blurRadius: 24 + 28 * climaxT,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Tagline ───────────────────────────────────────────
              Align(
                alignment: const Alignment(0, 0.86),
                child: Opacity(
                  opacity: taglineT * (1 - exitT) * 0.9,
                  child: Text(
                    'splash.tagline'.tr().toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w600,
                      color: gold.withValues(alpha: 0.85),
                      shadows: const [
                        Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Vignette ──────────────────────────────────────────
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        Colors.transparent,
                        AppColors.voidColor
                            .withValues(alpha: 0.42 + exitT * 0.30),
                      ],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Letterbox Cinema-Bars ─────────────────────────────
              _letterboxBar(size, Alignment.topCenter, bgT),
              _letterboxBar(size, Alignment.bottomCenter, bgT),

              // ── Cinematic-Cut: Weiß-Flash → Schwarz ───────────────
              if (flashT > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.white
                          .withValues(alpha: flashT * 0.8),
                    ),
                  ),
                ),
              if (exitT > 0)
                Positioned.fill(
                  child: ColoredBox(
                    color:
                        AppColors.voidColor.withValues(alpha: exitT),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _letterboxBar(Size size, Alignment alignment, double t) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size.width,
          height: 34.0 * t,
          color: AppColors.voidColor,
        ),
      ),
    );
  }

  // Goldene Bokeh-Partikel auf Lissajous-Kurven (steigen sanft auf).
  List<Widget> _buildParticles(
      Size size, Color gold, double appear, double t) {
    final out = <Widget>[];
    for (var i = 0; i < 12; i++) {
      final ax = 0.10 + (i % 5) * 0.18;
      final ay = 0.20 + (i % 4) * 0.18;
      final phase = i * 0.5;
      final x = (ax + 0.04 * math.sin(t * (1.0 + i % 3) + phase)) * size.width;
      final y = (ay + 0.05 * math.cos(t * (1.2 + (i + 1) % 3) + phase)) *
          size.height;
      final s = 2.0 + (i % 4) * 0.9;
      final twinkle = 0.4 + 0.4 * math.sin(t * (1.3 + i * 0.1) + i);
      out.add(Positioned(
        top: y,
        left: x,
        child: IgnorePointer(
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: gold.withValues(alpha: twinkle * appear * 0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gold.withValues(alpha: 0.4 * twinkle * appear),
                  blurRadius: s * 2.6,
                ),
              ],
            ),
          ),
        ),
      ));
    }
    return out;
  }

  double _ease(double t) {
    final c = t.clamp(0.0, 1.0);
    return 1.0 - math.pow(1.0 - c, 3).toDouble();
  }

  double _bump(double t) {
    final c = t.clamp(0.0, 1.0);
    return math.sin(c * math.pi);
  }
}
