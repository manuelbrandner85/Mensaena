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

/// Spenden-Seite hat interaktive Elemente (Betrags-Chips, IBAN-Copy),
/// deshalb eigene Implementierung — kein reines Markdown.
class SpendenScreen extends StatefulWidget {
  const SpendenScreen({super.key});

  @override
  State<SpendenScreen> createState() => _SpendenScreenState();
}

class _SpendenScreenState extends State<SpendenScreen> {
  static const String _iban = 'DE79 1001 0178 6303 9229 28';
  static const String _ibanPlain = 'DE79100101786303922928';
  static const String _bic = 'REVODEB2';
  static const String _bank = 'Revolut Bank UAB';
  static const String _empfaenger = 'Mensaena';

  static const List<int> _presets = [1, 3, 5, 10, 25];

  int _selectedAmount = 3;
  bool _isCustom = false;
  final TextEditingController _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  double get _finalAmount {
    if (!_isCustom) return _selectedAmount.toDouble();
    return double.tryParse(_customCtrl.text.replaceAll(',', '.')) ?? 0;
  }

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
              'legal.donateHeroTitle'.tr(),
              style: AppTypography.display(
                  size: 26, color: AppColors.ink, height: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'legal.donateHeroLede'.tr(),
              style: AppTypography.body(
                  size: 14, color: AppColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 24),
            _badges(),
            const SizedBox(height: 24),
            _amountSection(),
            const SizedBox(height: 24),
            _bankCard(context),
            const SizedBox(height: 24),
            Text('legal.donateUseTitle'.tr(),
                style: AppTypography.display(size: 18, color: AppColors.amber)),
            const SizedBox(height: 8),
            _transparencyRow(
                'legal.donateTransServer'.tr(), 'legal.donateTransServerValue'.tr()),
            _transparencyRow(
                'legal.donateTransDomain'.tr(), 'legal.donateTransDomainValue'.tr()),
            _transparencyRow(
                'legal.donateTransSms'.tr(), 'legal.donateTransSmsValue'.tr()),
            _transparencyRow(
                'legal.donateTransDev'.tr(), 'legal.donateTransDevValue'.tr()),
            const SizedBox(height: 24),
            Text('legal.donateTiersTitle'.tr(),
                style: AppTypography.display(size: 18, color: AppColors.amber)),
            const SizedBox(height: 8),
            _tier('legal.donateTier1Title'.tr(), 'legal.donateTier1Req'.tr(),
                'legal.donateTier1Ben'.tr(), threshold: 5),
            _tier('legal.donateTier2Title'.tr(), 'legal.donateTier2Req'.tr(),
                'legal.donateTier2Ben'.tr(), threshold: 25, popular: true),
            _tier('legal.donateTier3Title'.tr(), 'legal.donateTier3Req'.tr(),
                'legal.donateTier3Ben'.tr(), threshold: 50),
            _tier('legal.donateTier4Title'.tr(), 'legal.donateTier4Req'.tr(),
                'legal.donateTier4Ben'.tr(), threshold: 100),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                'legal.donateTaxNote'.tr(),
                style: AppTypography.body(
                    size: 12, color: AppColors.mute, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Index der höchsten Tier-Stufe, die der gewählte Betrag erreicht
  /// (-1 = keine). Highlightet genau eine Karte.
  int get _reachedTierIndex {
    const thresholds = [5, 25, 50, 100];
    var idx = -1;
    for (var i = 0; i < thresholds.length; i++) {
      if (_finalAmount >= thresholds[i]) idx = i;
    }
    return idx;
  }

  Widget _badges() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Badge(text: 'legal.donateBadgeSepa'.tr()),
        _Badge(text: 'legal.donateBadgeNoAds'.tr()),
        _Badge(text: 'legal.donateBadgeTransparent'.tr()),
        _Badge(text: 'legal.donateBadgeOpenSource'.tr()),
      ],
    );
  }

  Widget _amountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('legal.donateAmountTitle'.tr(),
            style: AppTypography.display(size: 18, color: AppColors.amber)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final amount in _presets)
              _AmountChip(
                label: '$amount €',
                active: !_isCustom && _selectedAmount == amount,
                onTap: () => setState(() {
                  _selectedAmount = amount;
                  _isCustom = false;
                }),
              ),
            _AmountChip(
              label: 'legal.donateCustom'.tr(),
              active: _isCustom,
              onTap: () => setState(() => _isCustom = true),
            ),
          ],
        ),
        if (_isCustom) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _customCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            onChanged: (_) => setState(() {}),
            style: AppTypography.body(size: 16, color: AppColors.ink),
            decoration: InputDecoration(
              labelText: 'legal.donateCustomLabel'.tr(),
              labelStyle: AppTypography.label(size: 11, color: AppColors.mute),
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.5),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.amber, width: 2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bankCard(BuildContext context) {
    final amount = _finalAmount;
    final amountStr =
        amount > 0 ? amount.toStringAsFixed(2).replaceAll('.', ',') : '';
    final purpose = amount > 0
        ? '${'legal.donatePurposeValue'.tr()} – $amountStr €'
        : 'legal.donatePurposeValue'.tr();
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
          _bankRow(context, 'legal.donateBankRecipient'.tr(), _empfaenger),
          _bankRow(context, 'IBAN', _iban, copyValue: _ibanPlain),
          _bankRow(context, 'BIC', _bic, copyValue: _bic),
          _bankRow(context, 'legal.donateBankBank'.tr(), _bank),
          _bankRow(context, 'legal.donatePurpose'.tr(), purpose,
              copyValue: purpose),
          const SizedBox(height: 8),
          Text(
            'legal.donateBankCopyHint'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute),
          ),
        ],
      ),
    );
  }

  Widget _bankRow(BuildContext context, String label, String value,
      {String? copyValue}) {
    final copyable = copyValue != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.label(size: 10, color: AppColors.mute),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: copyable
                  ? () async {
                      await Clipboard.setData(ClipboardData(text: copyValue));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text('legal.donateBankCopied'
                              .tr(namedArgs: {'label': label})),
                        ),
                      );
                    }
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style:
                          AppTypography.mono(size: 13, color: AppColors.ink),
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
                style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
          ),
          Text(value,
              style: AppTypography.mono(size: 12, color: AppColors.bronze)),
        ],
      ),
    );
  }

  Widget _tier(String title, String requirement, String benefits,
      {required int threshold, bool popular = false}) {
    final highlight = _reachedTierIndex >= 0 &&
        const [5, 25, 50, 100].indexOf(threshold) == _reachedTierIndex;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.amber.withValues(alpha: 0.10)
            : AppColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? AppColors.amber : AppColors.line,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
              ),
              if (popular)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('legal.donatePopular'.tr(),
                      style: AppTypography.label(
                          size: 9, color: AppColors.voidColor)),
                ),
            ],
          ),
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

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.amber.withValues(alpha: 0.18)
              : AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(
            color: active ? AppColors.amber : AppColors.line,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTypography.mono(
            size: 14,
            color: active ? AppColors.amber : AppColors.inkSoft,
            weight: FontWeight.w600,
          ),
        ),
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
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: AppTypography.label(size: 10, color: AppColors.bronze)),
    );
  }
}
