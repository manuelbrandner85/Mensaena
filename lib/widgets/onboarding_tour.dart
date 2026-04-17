import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';

class OnboardingTour extends ConsumerStatefulWidget {
  const OnboardingTour({super.key});

  @override
  ConsumerState<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends ConsumerState<OnboardingTour> {
  final _pageCtrl = PageController();
  int _current = 0;
  bool _dismissed = false;

  static const _steps = [
    _Step(
      icon: Icons.waving_hand,
      color: Color(0xFF1EAAA6),
      title: 'Willkommen bei Mensaena!',
      body: 'Deine Nachbarschaftshilfe-Plattform. Hier findest du Hilfe und kannst selbst helfen.',
    ),
    _Step(
      icon: Icons.explore,
      color: Color(0xFF3B82F6),
      title: 'Beiträge in deiner Nähe',
      body: 'Auf dem Dashboard siehst du aktuelle Hilfsgesuche und Angebote aus deiner Nachbarschaft.',
    ),
    _Step(
      icon: Icons.add_circle_outline,
      color: Color(0xFF10B981),
      title: 'Erstelle deinen ersten Beitrag',
      body: 'Tippe auf "Erstellen" in der Navigationsleiste um einen Beitrag zu veröffentlichen.',
    ),
    _Step(
      icon: Icons.chat_bubble_outline,
      color: Color(0xFF8B5CF6),
      title: 'Chatte mit Nachbarn',
      body: 'Über den Chat-Tab kannst du direkt mit anderen in Kontakt treten.',
    ),
    _Step(
      icon: Icons.favorite,
      color: Color(0xFFF59E0B),
      title: 'Viel Spaß beim Helfen!',
      body: 'Du bist bereit. Entdecke deine Nachbarschaft und hilf mit, sie besser zu machen.',
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    setState(() => _dismissed = true);
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      try {
        await ref.read(supabaseProvider).from('profiles').update({'onboarding_completed': true}).eq('id', userId);
        ref.invalidate(currentProfileProvider);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    if (_dismissed || profile == null || profile.onboardingCompleted == true) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _steps.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (_, i) {
                      final step = _steps[i];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(color: step.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                            child: Icon(step.icon, size: 32, color: step.color),
                          ),
                          const SizedBox(height: 20),
                          Text(step.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          Text(step.body, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5), textAlign: TextAlign.center),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_steps.length, (i) => Container(
                    width: _current == i ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _current == i ? AppColors.primary500 : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: _complete,
                      child: const Text('Überspringen'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        if (_current < _steps.length - 1) {
                          _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        } else {
                          _complete();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary500, foregroundColor: Colors.white),
                      child: Text(_current == _steps.length - 1 ? 'Los geht\'s!' : 'Weiter'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Step({required this.icon, required this.color, required this.title, required this.body});
}
