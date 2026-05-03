import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class _StaticTextPage extends StatelessWidget {
  const _StaticTextPage({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

// Inhalte werden via Supabase-Tabelle / Cloudflare-API geladen oder
// 1:1 aus den entsprechenden Web-Seiten übernommen.

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _StaticTextPage(title: 'Über uns', body: 'Inhalt aus /about wird übernommen.');
}

class AgbPage extends StatelessWidget {
  const AgbPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _StaticTextPage(title: 'AGB', body: 'Inhalt aus /agb wird übernommen.');
}

class DatenschutzPage extends StatelessWidget {
  const DatenschutzPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _StaticTextPage(title: 'Datenschutz', body: 'Inhalt aus /datenschutz wird übernommen.');
}

class ImpressumPage extends StatelessWidget {
  const ImpressumPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _StaticTextPage(title: 'Impressum', body: 'Inhalt aus /impressum wird übernommen.');
}

class KontaktPage extends StatelessWidget {
  const KontaktPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _StaticTextPage(title: 'Kontakt', body: 'Kontaktformular folgt.');
}

class HaftungsausschlussPage extends StatelessWidget {
  const HaftungsausschlussPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _StaticTextPage(title: 'Haftungsausschluss', body: 'Inhalt aus /haftungsausschluss wird übernommen.');
}

class NutzungsbedingungenPage extends StatelessWidget {
  const NutzungsbedingungenPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _StaticTextPage(title: 'Nutzungsbedingungen', body: 'Inhalt aus /nutzungsbedingungen wird übernommen.');
}

class CommunityGuidelinesPage extends StatelessWidget {
  const CommunityGuidelinesPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _StaticTextPage(title: 'Community Guidelines', body: 'Inhalt aus /community-guidelines wird übernommen.');
}
