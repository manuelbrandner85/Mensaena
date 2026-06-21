/// SKILL: mensaena-design (Higgsfield-Cinematic)
/// CinematicIntroScreen — immersives Dorf-Intro beim allerersten App-Start
/// (vor dem Login). Vollflaechige, in Higgsfield erzeugte Kamerafahrt durch
/// ein Dorf bei Sonnenuntergang (assets/videos/dorf_intro.mp4, stumm, Loop),
/// darueber scroll-/zeitsynchron einblendende Story-Kapitel im Stil der
/// Web-Landingpage. Endet mit einem CTA zur Registrierung/zum Login.
///
/// Wird nur einmal gezeigt (FlutterSecureStorage-Flag). Bei Decoder-/Asset-
/// Fehler bleibt das Standbild (assets/images/onboarding_arrive.webp) als
/// nahtloser Fallback — kein Bruch.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/haptics.dart';
import '../../widgets/navigation/language_picker.dart';

const _introShownKey = 'cinematic_intro_v1_shown';
const _storage = FlutterSecureStorage();

class _Chapter {
  const _Chapter({
    required this.eyebrowKey,
    required this.titleKey,
    required this.bodyKey,
  });
  final String eyebrowKey;
  final String titleKey;
  final String bodyKey;
}

class CinematicIntroScreen extends ConsumerStatefulWidget {
  const CinematicIntroScreen({super.key});

  @override
  ConsumerState<CinematicIntroScreen> createState() =>
      _CinematicIntroScreenState();

  static Future<bool> shouldShow() async {
    try {
      final raw = await _storage.read(key: _introShownKey);
      return raw != 'true';
    } catch (_) {
      return false; // im Zweifel NICHT zeigen (Login nicht blockieren)
    }
  }

  static Future<void> markShown() async {
    try {
      await _storage.write(key: _introShownKey, value: 'true');
    } catch (_) {}
  }
}

class _CinematicIntroScreenState extends ConsumerState<CinematicIntroScreen> {
  VideoPlayerController? _video;
  bool _videoReady = false;
  Timer? _chapterTimer;
  int _chapter = 0;

  static const _chapters = <_Chapter>[
    _Chapter(
      eyebrowKey: 'intro.c1.eyebrow',
      titleKey: 'intro.c1.title',
      bodyKey: 'intro.c1.body',
    ),
    _Chapter(
      eyebrowKey: 'intro.c2.eyebrow',
      titleKey: 'intro.c2.title',
      bodyKey: 'intro.c2.body',
    ),
    _Chapter(
      eyebrowKey: 'intro.c3.eyebrow',
      titleKey: 'intro.c3.title',
      bodyKey: 'intro.c3.body',
    ),
    _Chapter(
      eyebrowKey: 'intro.c4.eyebrow',
      titleKey: 'intro.c4.title',
      bodyKey: 'intro.c4.body',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initVideo();
    _chapterTimer = Timer.periodic(
      const Duration(milliseconds: 4200),
      (_) {
        if (!mounted) return;
        setState(() => _chapter = (_chapter + 1) % _chapters.length);
      },
    );
  }

  Future<void> _initVideo() async {
    final v = VideoPlayerController.asset(
      'assets/videos/dorf_intro.mp4',
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
      _video = null;
      try {
        await v.dispose();
      } catch (_) {}
    }
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await CinematicIntroScreen.markShown();
    if (!mounted) return;
    context.go('/auth?mode=register');
  }

  Future<void> _skip() async {
    Haptics.tap();
    await CinematicIntroScreen.markShown();
    if (!mounted) return;
    context.go('/auth?mode=login');
  }

  @override
  void dispose() {
    _chapterTimer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ch = _chapters[_chapter];

    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Higgsfield-Kamerafahrt (Loop) oder Standbild-Fallback ──
          if (_videoReady && _video != null)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _video!.value.size.width,
                height: _video!.value.size.height,
                child: VideoPlayer(_video!),
              ),
            )
          else
            Image.asset(
              'assets/images/onboarding_arrive.webp',
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.voidColor),
            ),

          // ── Tiefen-Scrim: oben leicht, unten kräftig für Lesbarkeit ──
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.voidColor.withValues(alpha: 0.45),
                    Colors.transparent,
                    AppColors.voidColor.withValues(alpha: 0.55),
                    AppColors.voidColor.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.34, 0.66, 1.0],
                ),
              ),
            ),
          ),

          // ── Story-Kapitel (Crossfade) ──────────────────────────────
          Align(
            alignment: const Alignment(0, 0.42),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 650),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(_chapter),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '— ${(_chapter + 1).toString().padLeft(2, '0')} / ${ch.eyebrowKey.tr()}',
                      style: AppTypography.label(
                          size: 11, color: AppColors.bronze),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      ch.titleKey.tr(),
                      style: AppTypography.display(
                        size: 34,
                        color: AppColors.ink,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      ch.bodyKey.tr(),
                      style: AppTypography.body(
                        size: 15,
                        color: AppColors.inkSoft,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Sprache (oben links) + Überspringen (oben rechts) ──────
          const Positioned(top: 12, left: 12, child: SafeArea(child: LanguagePicker())),
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: TextButton(
                onPressed: _skip,
                child: Text(
                  'intro.skip'.tr(),
                  style: AppTypography.label(size: 11, color: AppColors.mute),
                ),
              ),
            ),
          ),

          // ── Fortschritts-Punkte + CTA ──────────────────────────────
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _chapters.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _chapter ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _chapter
                              ? AppColors.bronze
                              : AppColors.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: AppColors.voidColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'intro.cta'.tr(),
                        style: AppTypography.body(
                          size: 15,
                          color: AppColors.voidColor,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
