import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-design
/// 1:1-Pendant zu `src/components/shared/OnboardingTour.tsx`.
/// 6-Step Cinema-Tour, gated auf flutter_secure_storage Key
/// `onboarding-completed-v1`.
class OnboardingTour {
  const OnboardingTour._();

  static const _key = 'mensaena_onboarding_completed_v1';
  static const _storage = FlutterSecureStorage();

  /// Zeigt die Tour, falls noch nicht gesehen.
  static Future<void> maybeShow(BuildContext context) async {
    try {
      final done = await _storage.read(key: _key);
      if (done == '1') return;
    } catch (_) {}
    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'OnboardingTour',
      barrierDismissible: false,
      barrierColor: AppColors.voidColor.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const _OnboardingTourSheet(),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    );
    try {
      await _storage.write(key: _key, value: '1');
    } catch (_) {}
  }

  static Future<void> replay(BuildContext context) async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
    return maybeShow(context);
  }
}

class _OnboardingTourSheet extends StatefulWidget {
  const _OnboardingTourSheet();

  @override
  State<_OnboardingTourSheet> createState() => _OnboardingTourSheetState();
}

class _OnboardingTourSheetState extends State<_OnboardingTourSheet> {
  int _step = 0;

  static const _steps = [
    (
      icon: LucideIcons.sparkles,
      eyebrow: 'Willkommen',
      title: 'Schön, dass du da bist.',
      body:
          'Mensaena ist dein Ort für gelebte Nachbarschaftshilfe. In sechs kurzen Schritten zeigen wir dir, wie du dich sicher und mühelos einfindest.',
      tint: AppColors.teal,
    ),
    (
      icon: LucideIcons.compass,
      eyebrow: 'Dein Dashboard',
      title: 'Der Überblick auf einen Blick.',
      body:
          'Im Dashboard findest du alle wichtigen Informationen auf einen Blick: neue Anfragen, Angebote aus deiner Nachbarschaft und persönliche Empfehlungen.',
      tint: AppColors.lebenSoft,
    ),
    (
      icon: LucideIcons.map,
      eyebrow: 'Die Karte',
      title: 'Hilfe in deiner Umgebung.',
      body:
          'Auf der interaktiven Karte siehst du, wo in deiner Nähe gerade Hilfe gebraucht oder angeboten wird. Tippe auf einen Pin und lerne deine Nachbarn kennen.',
      tint: AppColors.tealSoft,
    ),
    (
      icon: LucideIcons.plusCircle,
      eyebrow: 'Dein erster Beitrag',
      title: 'Teile, was du bieten oder suchen kannst.',
      body:
          'Egal ob du Werkzeug verleihst, beim Einkauf helfen willst oder selbst Unterstützung brauchst – ein Beitrag ist in wenigen Sekunden erstellt.',
      tint: AppColors.bronze,
    ),
    (
      icon: LucideIcons.messageCircle,
      eyebrow: 'Nachrichten',
      title: 'Direkt miteinander sprechen.',
      body:
          'Alles, was zwischen Nachbarn passiert, läuft über sichere Direktnachrichten. Freundlich, respektvoll, DSGVO-konform.',
      tint: AppColors.leben,
    ),
    (
      icon: LucideIcons.users,
      eyebrow: 'Gemeinschaft',
      title: 'Gemeinsam stark.',
      body:
          'Mensaena lebt vom Miteinander. Sei respektvoll, hilfsbereit und offen – dann wirst du schnell merken, wie herzlich deine Nachbarschaft ist.',
      tint: AppColors.amber,
    ),
  ];

  void _next() {
    if (_step >= _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  void _skip() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final s = _steps[_step];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Skip-Button rechts oben
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _skip,
                      icon: const Icon(LucideIcons.x,
                          size: 14, color: AppColors.mute),
                      label: Text('Überspringen',
                          style: AppTypography.label(
                              size: 10, color: AppColors.mute)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Tint-Glow + Icon
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          s.tint.withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.tint.withValues(alpha: 0.18),
                        border: Border.all(
                            color: s.tint.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: s.tint.withValues(alpha: 0.32),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Icon(s.icon, size: 28, color: s.tint),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Eyebrow
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.tint.withValues(alpha: 0.10),
                        border: Border.all(
                            color: s.tint.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s.eyebrow.toUpperCase(),
                        style: AppTypography.label(
                          size: 9,
                          color: s.tint,
                          letterSpacing: 0.30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title (Cinema-Serif)
                  Text(
                    s.title,
                    textAlign: TextAlign.center,
                    style: AppTypography.display(
                      size: 26,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Body
                  Text(
                    s.body,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.inkSoft,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Progress-Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin:
                            const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _step ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _step
                              ? AppColors.bronze
                              : AppColors.line,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.inkSoft,
                            side:
                                const BorderSide(color: AppColors.line),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                          ),
                          onPressed: _step == 0 ? null : _back,
                          icon: const Icon(LucideIcons.arrowLeft,
                              size: 14),
                          label: const Text('Zurück'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.bronze,
                            foregroundColor: AppColors.voidColor,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          onPressed: _next,
                          icon: Icon(
                            _step == _steps.length - 1
                                ? LucideIcons.checkCircle
                                : LucideIcons.arrowRight,
                            size: 16,
                          ),
                          label: Text(
                            _step == _steps.length - 1
                                ? 'Los geht\'s'
                                : 'Weiter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
