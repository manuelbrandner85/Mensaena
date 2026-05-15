import 'package:flutter/material.dart';

import '../painters/crisis_atmosphere.dart';
import '../painters/fireflies.dart';
import '../painters/lantern_particles.dart';
import '../painters/vignette.dart';
import '../theme/colors.dart';
import 'shader_layers.dart';

/// Die "Welt" hinter jedem Screen.
///
/// Reihenfolge der Schichten (von unten nach oben):
///   1. void-Background
///   2. Atmosphaeren-Shader (FBM-Nebel)
///   3. Wet-Reflection-Shader (nur immersive)
///   4. Laternenpartikel
///   5. Gluehwuermchen (nur immersive)
///   6. Vignette
///   7. Film-Grain
///   8. Krisen-Overlay (wenn isCrisis)
///   9. Page-Content
///   10. AppBar (optional, oben drauf via SafeArea)
///   11. BottomNav (optional)
enum AtmosphereLevel {
  /// Alle 8 Schichten. Splash, Auth, Landing-Hero.
  immersive,

  /// Reduziert: 20 Partikel, keine Fireflies, kein Wet-Asphalt.
  /// Dashboard, Karte, Chat, Profile etc.
  app,

  /// Nur Vignette + Grain. Admin, Einstellungen.
  focus,

  /// Eigenstaendiger Krisen-Layer. Wird zusaetzlich zu app aktiviert.
  crisis,
}

class CinemaScaffold extends StatelessWidget {
  final Widget body;
  final AtmosphereLevel level;
  final bool isCrisis;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const CinemaScaffold({
    super.key,
    required this.body,
    this.level = AtmosphereLevel.app,
    this.isCrisis = false,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  bool get _showFog => level == AtmosphereLevel.immersive || level == AtmosphereLevel.app;
  bool get _showWet => level == AtmosphereLevel.immersive;
  bool get _showLanterns => level != AtmosphereLevel.focus;
  bool get _showFireflies => level == AtmosphereLevel.immersive;
  bool get _showGrain => true;

  int get _lanternCount {
    switch (level) {
      case AtmosphereLevel.immersive:
        return 40;
      case AtmosphereLevel.app:
        return 20;
      case AtmosphereLevel.focus:
        return 0;
      case AtmosphereLevel.crisis:
        return 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: MnColors.voidColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Tiefer Nacht-Hintergrund (gradient void -> deep).
          const _NightGradient(),

          // 2. Atmosphaeren-Shader (Bodennebel).
          if (_showFog && !reduceMotion)
            ShaderLayer(
              assetPath: 'shaders/atmosphere.frag',
              extraUniform: (_) => 0.0, // uScroll (kann spaeter gebunden werden)
              extraUniform2: (_) => isCrisis ? 1.0 : 0.0, // uCrisis
            ),

          // 3. Wet-Reflection-Shader (Asphalt unten).
          if (_showWet && !reduceMotion)
            const ShaderLayer(assetPath: 'shaders/wet_reflection.frag'),

          // 4. Laternenpartikel.
          if (_showLanterns)
            LanternParticlesWidget(
              count: reduceMotion ? (_lanternCount ~/ 2) : _lanternCount,
              crisisShift: isCrisis,
            ),

          // 5. Gluehwuermchen.
          if (_showFireflies && !reduceMotion) const FirefliesWidget(),

          // 6. Asymmetrische Vignette (immer).
          const VignetteWidget(),

          // 7. Film-Grain (immer, sehr subtil).
          if (_showGrain && !reduceMotion)
            const ShaderLayer(
              assetPath: 'shaders/film_grain.frag',
              blendMode: BlendMode.overlay,
            ),

          // 8. Krisen-Overlay.
          if (isCrisis && !reduceMotion) const CrisisAtmosphere(),

          // 9. Eigentlicher Page-Content.
          Positioned.fill(child: body),
        ],
      ),
    );
  }
}

/// Tiefer Nacht-Verlauf: oben void, unten deep mit ganz leichtem
/// Amber-Touch (warmes Licht von unten).
class _NightGradient extends StatelessWidget {
  const _NightGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MnColors.voidColor,
            MnColors.deep,
            Color(0xFF161F36),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
    );
  }
}
