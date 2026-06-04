/// SKILL: mensaena-features
/// Generischer Markdown-Renderer für Legal-/Info-Seiten.
/// Wiederverwendet für /impressum, /datenschutz, /agb,
/// /haftungsausschluss, /nutzungsbedingungen, /community-guidelines,
/// /about, /kontakt.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../widgets/navigation/language_picker.dart';
import 'legal_content.dart';

class LegalPageScreen extends StatelessWidget {
  const LegalPageScreen({super.key, required this.contentKey});

  final String contentKey;

  @override
  Widget build(BuildContext context) {
    final title = LegalContent.titles[contentKey] ?? 'Information';
    final body = LegalContent.body(contentKey) ?? '_Inhalt nicht gefunden._';
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      appBar: AppBar(
        backgroundColor: AppColors.deep,
        leading: IconButton(
          tooltip: 'common.back'.tr(),
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.ink),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          title,
          style: AppTypography.display(size: 18, color: AppColors.ink),
        ),
        actions: const [LanguagePicker(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: Markdown(
          data: body,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          onTapLink: (text, href, _) async {
            if (href == null) return;
            final uri = Uri.tryParse(href);
            if (uri == null) return;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          selectable: true,
          styleSheet: _styles(),
        ),
      ),
    );
  }

  MarkdownStyleSheet _styles() {
    return MarkdownStyleSheet(
      h1: AppTypography.display(size: 26, color: AppColors.ink, height: 1.2),
      h1Padding: const EdgeInsets.only(top: 4, bottom: 12),
      h2: AppTypography.display(size: 18, color: AppColors.amber, height: 1.3),
      h2Padding: const EdgeInsets.only(top: 22, bottom: 8),
      h3: AppTypography.body(size: 16, color: AppColors.ink, weight: FontWeight.w700),
      h3Padding: const EdgeInsets.only(top: 14, bottom: 4),
      p: AppTypography.body(size: 14, color: AppColors.inkSoft, height: 1.55),
      strong: AppTypography.body(size: 14, color: AppColors.ink, weight: FontWeight.w700),
      em: AppTypography.body(size: 14, color: AppColors.inkSoft).copyWith(
        fontStyle: FontStyle.italic,
      ),
      listBullet: AppTypography.body(size: 14, color: AppColors.bronze),
      a: AppTypography.body(size: 14, color: AppColors.amber).copyWith(
        decoration: TextDecoration.underline,
      ),
      blockquote: AppTypography.body(size: 14, color: AppColors.inkSoft).copyWith(
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: const Border(
          left: BorderSide(color: AppColors.bronze, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      code: AppTypography.mono(size: 12, color: AppColors.amber),
      codeblockDecoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(8),
      ),
      tableBorder: TableBorder.all(color: AppColors.line),
      tableCellsPadding: const EdgeInsets.all(8),
    );
  }
}

/// Spenden-Seite hat ein interaktives QR-/IBAN-Element, deshalb eigene
/// Implementierung — kein reines Markdown.
class SpendenScreen extends StatelessWidget {
  const SpendenScreen({super.key});

  static const String _iban = 'DE79 1001 0178 6303 9229 28';
  static const String _bic = 'REVODEB2';
  static const String _bank = 'Revolut Bank UAB';
  static const String _empfaenger = 'Mensaena';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      appBar: AppBar(
        backgroundColor: AppColors.deep,
        leading: IconButton(
          tooltip: 'common.back'.tr(),
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.ink),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text('legal.donate'.tr(),
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        actions: const [LanguagePicker(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Damit Nachbarschaft möglich bleibt.',
              style: AppTypography.display(
                  size: 26, color: AppColors.ink, height: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Mensaena ist 100% werbefrei und für alle kostenlos. Damit das so bleibt, finanzieren wir uns ausschließlich durch Spenden.',
              style: AppTypography.body(
                  size: 14, color: AppColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 24),
            _badges(),
            const SizedBox(height: 24),
            _bankCard(context),
            const SizedBox(height: 24),
            Text('legal.donateUseTitle'.tr(),
                style: AppTypography.display(
                    size: 18, color: AppColors.amber)),
            const SizedBox(height: 8),
            _transparencyRow('Server & Infrastruktur', '~30 €/Monat'),
            _transparencyRow('Domain & SSL', '~15 €/Jahr'),
            _transparencyRow('SMS-Verifikation', '~0,05 €/Nutzer:in'),
            _transparencyRow('Entwicklung', 'ehrenamtlich'),
            const SizedBox(height: 24),
            Text('legal.donateTiersTitle'.tr(),
                style: AppTypography.display(
                    size: 18, color: AppColors.amber)),
            const SizedBox(height: 8),
            _tier('🤍 Unterstützer', '1 Spende oder ab 5€',
                'Spender-Badge im Chat'),
            _tier('💛 Förderer', '3 Spenden oder ab 25€',
                'Umfragen erstellen, Eigenen Kanal anlegen'),
            _tier('🧡 Partner', '5 Spenden oder ab 50€',
                'Livestream-Events planen, Ankündigungen posten'),
            _tier('❤️ Botschafter', '10 Spenden oder ab 100€',
                'Post-Boost, Profil-Banner'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                'Mensaena ist derzeit nicht als gemeinnützig im Sinne der Abgabenordnung anerkannt. Spenden sind daher nicht steuerlich absetzbar — wir arbeiten daran.',
                style: AppTypography.body(
                    size: 12, color: AppColors.mute, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badges() {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Badge(text: 'SEPA-Standard'),
        _Badge(text: 'Keine Werbung'),
        _Badge(text: '100% transparent'),
        _Badge(text: 'Open Source'),
      ],
    );
  }

  Widget _bankCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('legal.donateBankTitle'.tr(),
              style: AppTypography.display(size: 16, color: AppColors.bronze)),
          const SizedBox(height: 12),
          _bankRow(context, 'Empfänger', _empfaenger),
          _bankRow(context, 'IBAN', _iban, copyable: true),
          _bankRow(context, 'BIC', _bic, copyable: true),
          _bankRow(context, 'Bank', _bank),
          const SizedBox(height: 8),
          Text(
            'Tippe auf IBAN oder BIC, um den Wert zu kopieren.',
            style: AppTypography.label(size: 10, color: AppColors.mute),
          ),
        ],
      ),
    );
  }

  Widget _bankRow(BuildContext context, String label, String value,
      {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: AppTypography.label(size: 10, color: AppColors.mute),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: copyable
                  ? () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text('$label kopiert: $value'),
                        ),
                      );
                    }
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: AppTypography.mono(
                          size: 13, color: AppColors.ink),
                    ),
                  ),
                  if (copyable)
                    const Icon(LucideIcons.copy,
                        size: 14, color: AppColors.mute),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transparencyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTypography.body(
                    size: 13, color: AppColors.inkSoft)),
          ),
          Text(value,
              style: AppTypography.mono(size: 12, color: AppColors.bronze)),
        ],
      ),
    );
  }

  Widget _tier(String title, String requirement, String benefits) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                  weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(requirement,
              style: AppTypography.label(size: 10, color: AppColors.mute)),
          const SizedBox(height: 6),
          Text(benefits,
              style: AppTypography.body(
                  size: 12, color: AppColors.inkSoft, height: 1.4)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bronze.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: AppTypography.label(size: 10, color: AppColors.bronze)),
    );
  }
}
