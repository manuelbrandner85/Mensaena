import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/app_release.dart';
import '../../repositories/app_releases_repository.dart';

/// SKILL: mensaena-architektur + mensaena-features
/// UpdateGate — wickelt die ganze App. Prueft bei Start app_releases:
/// - Wenn neuere mandatory APK existiert: blockierender Vollbild-Screen
///   mit "Update herunterladen" Button (oeffnet apk_url extern).
/// - Wenn neuere optionale APK: kein Block, optionaler Toast in der UI.
/// - Wenn aktuelle Version OK: gibt child durch.
///
/// Shorebird-Patches werden automatisch beim Launch installiert und
/// brauchen kein UI — passieren lautlos.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(updateCheckProvider);
    return check.when(
      loading: () => child,
      error: (_, __) => child,
      data: (c) {
        if (c.isMandatory && c.latest != null) {
          return _MandatoryUpdateScreen(release: c.latest!);
        }
        return child;
      },
    );
  }
}

class _MandatoryUpdateScreen extends StatefulWidget {
  const _MandatoryUpdateScreen({required this.release});
  final AppRelease release;

  @override
  State<_MandatoryUpdateScreen> createState() => _MandatoryUpdateScreenState();
}

class _MandatoryUpdateScreenState extends State<_MandatoryUpdateScreen> {
  bool _launching = false;

  Future<void> _download() async {
    final url = widget.release.apkUrl;
    if (url == null || url.isEmpty) return;
    setState(() => _launching = true);
    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // ignore — User kann manuell auf Link tippen.
    }
    if (mounted) setState(() => _launching = false);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: AppColors.voidColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.download,
                    color: AppColors.amber,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Update verfügbar',
                  textAlign: TextAlign.center,
                  style: AppTypography.display(
                    size: 30,
                    color: AppColors.ink,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Version ${widget.release.version}',
                  textAlign: TextAlign.center,
                  style: AppTypography.mono(size: 14),
                ),
                const SizedBox(height: 20),
                Text(
                  'Diese Version ist verpflichtend. Bitte lade die neueste '
                  'APK herunter und installiere sie, um Mensaena '
                  'weiterzunutzen.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    size: 15,
                    color: AppColors.inkSoft,
                    height: 1.6,
                  ),
                ),
                if (_changelogPreview() != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.5),
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Was ist neu',
                          style: AppTypography.label(size: 10),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _changelogPreview()!,
                          style: AppTypography.body(
                            size: 13,
                            color: AppColors.inkSoft,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _launching ? null : _download,
                    icon: const Icon(LucideIcons.download, size: 18),
                    label: Text(
                      _launching
                          ? 'Wird gestartet…'
                          : 'APK herunterladen & installieren',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Android fragt evtl. nach Berechtigung "Apps aus unbekannten '
                  'Quellen installieren" — bitte erlauben.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _changelogPreview() {
    final cl = widget.release.changelog;
    if (cl.isEmpty) return null;
    // changelog kann verschiedene Formate haben — versuche tolerant zu lesen.
    final notes = cl['notes'] ?? cl['summary'] ?? cl['de'];
    if (notes is String && notes.isNotEmpty) {
      return notes.length > 240 ? '${notes.substring(0, 237)}…' : notes;
    }
    if (notes is List) {
      final lines = notes.whereType<String>().take(4).map((s) => '• $s');
      return lines.join('\n');
    }
    return null;
  }
}
