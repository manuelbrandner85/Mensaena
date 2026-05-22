import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/glow_button.dart';
import '../../routing/routes.dart';

/// Download-Page – Cinema-Variant der Web /download.
/// Cherry-Pick fuer Mobile: F-Droid + Direct-APK. PWA-Sektion entfaellt,
/// weil wir bereits in der nativen App sind (Page dient v.a. zum Teilen
/// und Verweis fuer Browser-Besucher der gleichen Route).
class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  static const String _fdroidRepoUrl = 'https://www.mensaena.de/fdroid/repo';
  static const String _fdroidFingerprint =
      'B1C5EDD7840D0E63A9E305D728A803C4A75C00C31A0CE158B40E9D97E6FB5D9B';
  static const String _fdroidDeepLink =
      'fdroidrepos://www.mensaena.de/fdroid/repo?fingerprint=$_fdroidFingerprint';
  static const String _apkDirectUrl =
      'https://github.com/manuelbrandner85/Mensaena/releases/latest/download/mensaena-release.apk';

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      level: AtmosphereLevel.app,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: MnColors.ink),
          onPressed: () => Navigator.of(context).maybePop().then((popped) {
            if (!popped && context.mounted) context.go(Routes.landing);
          }),
        ),
        title: Text('Mensaena installieren', style: MnTypography.appBarTitle()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _HeroSection(),
                  SizedBox(height: 40),
                  _FDroidSection(),
                  SizedBox(height: 24),
                  _ApkSection(),
                  SizedBox(height: 24),
                  _WhyOpenSource(),
                  SizedBox(height: 64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternal(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ── Hero ─────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '— Installation',
          style: MnTypography.label(
            size: 11,
            color: MnColors.amber,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Hol dir Mensaena\nals echte App.',
          style: MnTypography.display(
            size: 34,
            height: 1.1,
            color: MnColors.ink,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Zwei Wege auf Android: F-Droid (empfohlen, auto-Updates aus '
          'unserem Repo) oder direkter APK-Download. Keine Daten an '
          'Google. Open Source. Reproduzierbar gebaut.',
          style: MnTypography.body(
            size: 15,
            color: MnColors.inkSoft,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ── F-Droid ──────────────────────────────────────────────────────────────
class _FDroidSection extends StatefulWidget {
  const _FDroidSection();

  @override
  State<_FDroidSection> createState() => _FDroidSectionState();
}

class _FDroidSectionState extends State<_FDroidSection> {
  bool _showInstructions = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MnColors.deep.withValues(alpha: 0.7),
        border: Border.all(color: MnColors.lineActive),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.refreshCw,
                  size: 18, color: MnColors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'F-Droid (empfohlen)',
                  style: MnTypography.body(
                    size: 16,
                    color: MnColors.ink,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: MnColors.leben.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Auto-Updates',
                  style: MnTypography.label(
                    size: 9,
                    color: MnColors.lebenSoft,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'F-Droid ist ein Open-Source-App-Store. Wenn er installiert '
            'ist, oeffnet der Button unser Repo direkt — bestaetige '
            'Fingerprint, abonniere, fertig.',
            style: MnTypography.body(
              size: 14,
              color: MnColors.inkSoft,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          GlowButton(
            label: 'In F-Droid öffnen',
            icon: LucideIcons.externalLink,
            onPressed: () => _openExternal(DownloadPage._fdroidDeepLink),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () =>
                setState(() => _showInstructions = !_showInstructions),
            child: Row(
              children: [
                Icon(
                  _showInstructions
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 16,
                  color: MnColors.inkSoft,
                ),
                const SizedBox(width: 6),
                Text(
                  _showInstructions
                      ? 'Anleitung schließen'
                      : 'F-Droid noch nicht installiert?',
                  style: MnTypography.body(
                    size: 13,
                    color: MnColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (_showInstructions) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MnColors.surface.withValues(alpha: 0.5),
                border: Border.all(color: MnColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Step(
                    n: '1',
                    text: 'Lade F-Droid von f-droid.org',
                    link: 'https://f-droid.org',
                  ),
                  _Step(
                    n: '2',
                    text: 'Öffne F-Droid → Einstellungen → Repositories',
                  ),
                  _Step(
                    n: '3',
                    text: 'Tippe "+" und gib die Repo-URL ein',
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 24, top: 6, bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MnColors.voidColor,
                      border: Border.all(color: MnColors.line),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      DownloadPage._fdroidRepoUrl,
                      style: MnTypography.mono(size: 12),
                    ),
                  ),
                  _Step(
                    n: '4',
                    text: 'Bestätige den Fingerprint:',
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 24, top: 6, bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MnColors.voidColor,
                      border: Border.all(color: MnColors.line),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      DownloadPage._fdroidFingerprint,
                      style: MnTypography.mono(size: 11),
                    ),
                  ),
                  _Step(
                    n: '5',
                    text: 'Suche "Mensaena" und installiere',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text, this.link});

  final String n;
  final String text;
  final String? link;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(right: 8, top: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MnColors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: MnColors.amber, width: 0.8),
            ),
            child: Text(
              n,
              style: MnTypography.mono(
                size: 10,
                weight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: link != null
                ? GestureDetector(
                    onTap: () => _openExternal(link!),
                    child: Text(
                      text,
                      style: MnTypography.body(
                        size: 13,
                        color: MnColors.amber,
                        height: 1.5,
                      ),
                    ),
                  )
                : Text(
                    text,
                    style: MnTypography.body(
                      size: 13,
                      color: MnColors.inkSoft,
                      height: 1.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Direct APK ───────────────────────────────────────────────────────────
class _ApkSection extends StatelessWidget {
  const _ApkSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MnColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: MnColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.download,
                  size: 18, color: MnColors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Direkter APK-Download',
                  style: MnTypography.body(
                    size: 16,
                    color: MnColors.ink,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Signierte APK aus GitHub Releases — immer die neueste Version. '
            'Keine Updates ohne dein Zutun, du musst sie manuell '
            'installieren wenn ein neuer Build raus ist.',
            style: MnTypography.body(
              size: 14,
              color: MnColors.inkSoft,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          GlowButton(
            label: 'APK herunterladen',
            icon: LucideIcons.download,
            variant: GlowVariant.secondary,
            onPressed: () => _openExternal(DownloadPage._apkDirectUrl),
          ),
        ],
      ),
    );
  }
}

// ── Why Open Source ──────────────────────────────────────────────────────
class _WhyOpenSource extends StatelessWidget {
  const _WhyOpenSource();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MnColors.surface.withValues(alpha: 0.3),
        border: Border.all(color: MnColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shield,
                  size: 16, color: MnColors.inkSoft),
              const SizedBox(width: 8),
              Text(
                'Warum nicht Play Store?',
                style: MnTypography.label(size: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Mensaena ist Open Source und werbefrei. Wir geben keine Daten '
            'an Google weiter, also kein Play Store. F-Droid prueft jede '
            'App-Version unabhaengig — du musst uns nicht blind vertrauen.',
            style: MnTypography.body(
              size: 13,
              color: MnColors.inkSoft,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
