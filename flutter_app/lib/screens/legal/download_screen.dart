/// SKILL: mensaena-features
/// Download-Seite – native Variante der Web /download.
/// Zwei Installationswege auf Android: F-Droid (empfohlen, Auto-Updates aus
/// unserem Repo via Deep-Link) und direkter signierter APK-Download aus den
/// GitHub Releases. PWA-Sektion entfaellt, da bereits native App.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../widgets/navigation/language_picker.dart';

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  // 1:1 aus der Web-Seite – Eigennamen/URLs, daher kein .tr().
  static const String _fdroidRepoUrl = 'https://www.mensaena.de/fdroid/repo';
  static const String _fdroidFingerprint =
      'B1C5EDD7840D0E63A9E305D728A803C4A75C00C31A0CE158B40E9D97E6FB5D9B';
  static const String _fdroidDeepLink =
      'fdroidrepos://www.mensaena.de/fdroid/repo?fingerprint=$_fdroidFingerprint';
  static const String _apkDirectUrl =
      'https://github.com/manuelbrandner85/Mensaena/releases/latest/download/mensaena-release.apk';

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
        title: Text('download.title'.tr(),
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        actions: const [LanguagePicker(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: const [
            _HeroSection(),
            SizedBox(height: 32),
            _FDroidSection(
              repoUrl: _fdroidRepoUrl,
              fingerprint: _fdroidFingerprint,
              deepLink: _fdroidDeepLink,
            ),
            SizedBox(height: 16),
            _ApkSection(apkUrl: _apkDirectUrl),
            SizedBox(height: 16),
            _WhyOpenSource(),
          ],
        ),
      ),
    );
  }
}

Future<void> _openExternal(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ── Hero ───────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'download.eyebrow'.tr(),
          style: AppTypography.label(size: 11, color: AppColors.amber),
        ),
        const SizedBox(height: 14),
        Text(
          'download.headline'.tr(),
          style: AppTypography.display(
              size: 30, color: AppColors.ink, height: 1.1),
        ),
        const SizedBox(height: 14),
        Text(
          'download.lede'.tr(),
          style: AppTypography.body(
              size: 14, color: AppColors.inkSoft, height: 1.55),
        ),
      ],
    );
  }
}

// ── F-Droid ────────────────────────────────────────────────────────────────
class _FDroidSection extends StatefulWidget {
  const _FDroidSection({
    required this.repoUrl,
    required this.fingerprint,
    required this.deepLink,
  });

  final String repoUrl;
  final String fingerprint;
  final String deepLink;

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
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.refreshCw,
                  size: 18, color: AppColors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'download.fdroidTitle'.tr(),
                  style: AppTypography.body(
                      size: 16, color: AppColors.ink, weight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.leben.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'download.fdroidBadge'.tr(),
                  style:
                      AppTypography.label(size: 9, color: AppColors.lebenSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'download.fdroidDesc'.tr(),
            style: AppTypography.body(
                size: 14, color: AppColors.inkSoft, height: 1.55),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'download.fdroidButton'.tr(),
            icon: LucideIcons.externalLink,
            onTap: () => _openExternal(widget.deepLink),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () =>
                setState(() => _showInstructions = !_showInstructions),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _showInstructions
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.inkSoft,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showInstructions
                        ? 'download.fdroidClose'.tr()
                        : 'download.fdroidNotInstalled'.tr(),
                    style:
                        AppTypography.body(size: 13, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
          if (_showInstructions) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Step(n: '1', textKey: 'download.step1'),
                  const _Step(n: '2', textKey: 'download.step2'),
                  const _Step(n: '3', textKey: 'download.step3'),
                  _CodeBlock(
                    label: 'download.repoUrlLabel'.tr(),
                    value: widget.repoUrl,
                  ),
                  const _Step(n: '4', textKey: 'download.step4'),
                  _CodeBlock(
                    label: 'download.fingerprintLabel'.tr(),
                    value: widget.fingerprint,
                  ),
                  const _Step(n: '5', textKey: 'download.step5'),
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
  const _Step({required this.n, required this.textKey});

  final String n;
  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(right: 10, top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.amber.withValues(alpha: 0.6)),
            ),
            child: Text(
              n,
              style: AppTypography.mono(
                  size: 10, color: AppColors.amber, weight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              textKey.tr(),
              style: AppTypography.body(
                  size: 13, color: AppColors.inkSoft, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 28, top: 6, bottom: 6),
      padding: const EdgeInsets.all(10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.voidColor,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label(size: 9, color: AppColors.mute)),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: AppTypography.mono(size: 11, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

// ── Direct APK ─────────────────────────────────────────────────────────────
class _ApkSection extends StatelessWidget {
  const _ApkSection({required this.apkUrl});

  final String apkUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.download,
                  size: 18, color: AppColors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'download.apkTitle'.tr(),
                  style: AppTypography.body(
                      size: 16, color: AppColors.ink, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'download.apkDesc'.tr(),
            style: AppTypography.body(
                size: 14, color: AppColors.inkSoft, height: 1.55),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'download.apkButton'.tr(),
            icon: LucideIcons.download,
            filled: false,
            onTap: () => _openExternal(apkUrl),
          ),
        ],
      ),
    );
  }
}

// ── Why Open Source ────────────────────────────────────────────────────────
class _WhyOpenSource extends StatelessWidget {
  const _WhyOpenSource();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shield, size: 16, color: AppColors.mute),
              const SizedBox(width: 8),
              Text('download.whyTitle'.tr(),
                  style: AppTypography.label(size: 10, color: AppColors.mute)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'download.whyDesc'.tr(),
            style: AppTypography.body(
                size: 13, color: AppColors.inkSoft, height: 1.55),
          ),
        ],
      ),
    );
  }
}

// ── Shared Button ──────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: filled
            ? AppColors.amber
            : AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: filled
                  ? null
                  : Border.all(color: AppColors.bronze.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: filled ? AppColors.voidColor : AppColors.amber),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTypography.body(
                    size: 14,
                    color: filled ? AppColors.voidColor : AppColors.amber,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
