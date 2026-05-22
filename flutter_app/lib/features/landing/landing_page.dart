import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/supabase.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/glow_button.dart';
import '../../routing/routes.dart';

/// Landing-Page – 4-Section-Cut der Web-Version /landing.
/// Sections: Hero / Stats / Features / CTA. Cinema-Dark, immersive Atmosphere.
class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  Future<_PlatformStats?>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_PlatformStats?> _loadStats() async {
    try {
      final data = await sb.rpc('get_platform_stats');
      if (data is Map) {
        final stats = _PlatformStats(
          users: (data['users'] as num?)?.toInt() ?? 0,
          posts: (data['posts'] as num?)?.toInt() ?? 0,
          interactions: (data['interactions'] as num?)?.toInt() ?? 0,
          regions: (data['regions'] as num?)?.toInt() ?? 0,
        );
        // Web hidet das Stats-Modul wenn alle Werte unter 5 sind.
        if (stats.users < 5 &&
            stats.posts < 5 &&
            stats.interactions < 5 &&
            stats.regions < 5) {
          return null;
        }
        return stats;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      level: AtmosphereLevel.immersive,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HeroSection(),
                  const SizedBox(height: 80),
                  _StatsSection(future: _statsFuture),
                  const SizedBox(height: 80),
                  const _FeaturesSection(),
                  const SizedBox(height: 80),
                  const _CtaSection(),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformStats {
  const _PlatformStats({
    required this.users,
    required this.posts,
    required this.interactions,
    required this.regions,
  });
  final int users;
  final int posts;
  final int interactions;
  final int regions;
}

// ── Hero ─────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(label: '— 01 / Deine Nachbarschaft'),
        const SizedBox(height: 20),
        Text(
          'Nachbarschaft,\nneu gedacht.',
          style: MnTypography.display(size: 48, height: 1.05, color: MnColors.ink),
        ),
        const SizedBox(height: 24),
        Text(
          'Hilfe anbieten. Hilfe finden.\nMenschen in deiner Nähe kennenlernen.\nKostenlos, gemeinnützig, von der Gemeinschaft getragen.',
          style: MnTypography.body(size: 16, color: MnColors.inkSoft, height: 1.6),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            GlowButton(
              label: 'Kostenlos starten',
              icon: Icons.arrow_forward,
              variant: GlowVariant.primary,
              onPressed: () => context.go('${Routes.auth}?mode=register'),
            ),
            GlowButton(
              label: 'Mehr erfahren',
              variant: GlowVariant.ghost,
              onPressed: () {
                // Scroll-Hint: in Phase-2-Polish optionale Anchor-Logic.
              },
            ),
          ],
        ),
        const SizedBox(height: 40),
        const _FactsGrid(),
      ],
    );
  }
}

class _FactsGrid extends StatelessWidget {
  const _FactsGrid();

  static const _facts = <({String k, String v})>[
    (k: 'Preis', v: 'Kostenlos'),
    (k: 'Datenschutz', v: 'DSGVO-konform'),
    (k: 'Organisation', v: 'Gemeinnützig'),
    (k: 'Werbung', v: 'keine'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cross = c.maxWidth < 460 ? 2 : 4;
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          children: _facts
              .map((f) => Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MnColors.deep.withValues(alpha: 0.5),
                      border: Border.all(color: MnColors.line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(f.k,
                            style: MnTypography.label(
                                size: 10, color: MnColors.mute)),
                        const SizedBox(height: 4),
                        Text(f.v,
                            style: MnTypography.body(
                                size: 14,
                                color: MnColors.ink,
                                weight: FontWeight.w600)),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ── Stats ────────────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.future});
  final Future<_PlatformStats?>? future;

  static const _labels = [
    ('users', 'Aktive Nachbarn'),
    ('posts', 'Hilfsangebote'),
    ('interactions', 'Interaktionen'),
    ('regions', 'Nachbarschaften'),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlatformStats?>(
      future: future,
      builder: (context, snap) {
        final stats = snap.data;
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (stats == null) {
          // Schwelle nicht erreicht → Modul ausblenden wie im Web.
          return const SizedBox.shrink();
        }
        final values = <int>[
          stats.users,
          stats.posts,
          stats.interactions,
          stats.regions,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Eyebrow(label: '— 02 / Die Gemeinschaft in Zahlen'),
            const SizedBox(height: 16),
            Text(
              'Echte Nachbarschaft, live aktualisiert.',
              style: MnTypography.display(
                  size: 28, height: 1.1, color: MnColors.ink),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, c) {
                final cross = c.maxWidth < 520 ? 2 : 4;
                return GridView.count(
                  crossAxisCount: cross,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.4,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  children: List.generate(_labels.length, (i) {
                    return _StatTile(
                      label: _labels[i].$2,
                      value: values[i],
                    );
                  }),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutQuart,
      builder: (context, v, _) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: MnColors.surface.withValues(alpha: 0.6),
            border: Border.all(color: MnColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: MnTypography.label(
                      size: 10, color: MnColors.mute)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatDe(v.toInt()),
                        style: MnTypography.mono(
                            size: 32,
                            color: MnColors.amber,
                            weight: FontWeight.w600),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 4),
                    child: Text('+',
                        style: MnTypography.mono(
                            size: 14, color: MnColors.amberSoft)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDe(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Features ─────────────────────────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  static const _feats = <({String num, String title, String desc})>[
    (
      num: '01',
      title: 'Hyperlokal.',
      desc:
          'Finde Hilfe und Angebote direkt in deiner Straße. Mit der interaktiven Karte siehst du auf einen Blick, was in deiner Nachbarschaft passiert.',
    ),
    (
      num: '02',
      title: 'Hilfe geben & nehmen.',
      desc:
          'Ob Einkaufshilfe, Werkzeug leihen oder Nachhilfe – biete an was du kannst und finde Unterstützung wenn du sie brauchst.',
    ),
    (
      num: '03',
      title: 'Vertrauen & Sicherheit.',
      desc:
          'Unser Bewertungssystem hilft dir, vertrauenswürdige Nachbarn zu erkennen. Melde- und Blockier-Funktionen sorgen für ein sicheres Miteinander.',
    ),
    (
      num: '04',
      title: 'Direkter Kontakt.',
      desc:
          'Schreib deinen Nachbarn direkt über unseren Chat. Privat, sicher und ohne deine Telefonnummer teilen zu müssen.',
    ),
    (
      num: '05',
      title: 'Gemeinnützig.',
      desc:
          'Mensaena ist kostenlos, werbefrei und gehört der Gemeinschaft. Keine versteckten Kosten, keine Datenverkäufe, kein Profit.',
    ),
    (
      num: '06',
      title: 'Krisenhilfe.',
      desc:
          'Bei Naturkatastrophen, Stromausfällen oder anderen Krisen aktiviert Mensaena den Krisenmodus für schnelle Nachbarschaftshilfe.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(label: '— 03 / Was Mensaena auszeichnet'),
        const SizedBox(height: 16),
        Text(
          'Sechs Prinzipien, die den Unterschied zwischen\nPlattform und Gemeinschaft machen.',
          style: MnTypography.display(
              size: 26, height: 1.15, color: MnColors.ink),
        ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, c) {
            final cross = c.maxWidth < 600 ? 1 : 2;
            return GridView.count(
              crossAxisCount: cross,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: cross == 1 ? 2.6 : 1.3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              children: _feats.map(_featureCard).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _featureCard(({String num, String title, String desc}) f) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MnColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: MnColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(f.num,
                  style: MnTypography.mono(
                      size: 13, color: MnColors.amber)),
              const SizedBox(width: 10),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: MnColors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(f.title,
              style: MnTypography.display(
                  size: 22, height: 1.15, color: MnColors.ink)),
          const SizedBox(height: 10),
          Text(f.desc,
              style: MnTypography.body(
                  size: 14, color: MnColors.inkSoft, height: 1.55)),
        ],
      ),
    );
  }
}

// ── CTA ──────────────────────────────────────────────────────────────────
class _CtaSection extends StatelessWidget {
  const _CtaSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MnColors.deep.withValues(alpha: 0.8),
            MnColors.surface.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: MnColors.lineActive),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(label: '— 09 / Bereit?'),
          const SizedBox(height: 14),
          Text(
            'Deine Nachbarschaft\nwartet auf dich.',
            style: MnTypography.display(
                size: 30, height: 1.1, color: MnColors.ink),
          ),
          const SizedBox(height: 14),
          Text(
            'Schließ dich einer wachsenden Gemeinschaft an, die zeigt, dass Nachbarschaftshilfe mehr ist als nur ein Wort.',
            style: MnTypography.body(
                size: 15, color: MnColors.inkSoft, height: 1.6),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              GlowButton(
                label: 'Jetzt kostenlos starten',
                icon: Icons.arrow_forward,
                variant: GlowVariant.primary,
                onPressed: () =>
                    context.go('${Routes.auth}?mode=register'),
              ),
              GlowButton(
                label: 'Bereits dabei? Anmelden',
                variant: GlowVariant.ghost,
                onPressed: () => context.go(Routes.auth),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared ───────────────────────────────────────────────────────────────
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: MnTypography.label(
        size: 11,
        color: MnColors.amber,
        letterSpacing: 0.15,
      ),
    );
  }
}
