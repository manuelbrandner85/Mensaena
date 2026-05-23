import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/app_release.dart';
import '../../repositories/app_releases_repository.dart';
import '../../services/apk_installer_service.dart';

/// SKILL: mensaena-architektur + mensaena-features
/// UpdateGate — wickelt die ganze App.
/// - Mandatory APK-Release: blockierender Vollbild-Screen mit
///   IN-APP Download (Progress-Bar) → triggert direkt Android-
///   Installer-Intent ueber OpenFilex/FileProvider. User muss
///   nicht raus, kein Browser, kein manueller Download.
/// - Shorebird-Patches: passieren transparent beim App-Launch, kein UI.
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
  double _progress = 0;
  bool _busy = false;
  String? _error;
  bool _waitingInstaller = false;

  Future<void> _downloadAndInstall() async {
    final url = widget.release.apkUrl;
    if (url == null || url.isEmpty) {
      setState(() => _error = 'Keine APK-URL hinterlegt.');
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
      _waitingInstaller = false;
    });

    final result = await ApkInstallerService.downloadAndInstall(
      url: url,
      version: widget.release.version,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
    );

    if (!mounted) return;
    if (result.ok) {
      setState(() {
        _busy = false;
        _waitingInstaller = true;
        _progress = 1;
      });
    } else {
      setState(() {
        _busy = false;
        _error = result.errorMessage ?? 'Update fehlgeschlagen.';
      });
    }
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
                  child: Icon(
                    _waitingInstaller
                        ? LucideIcons.checkCircle2
                        : LucideIcons.download,
                    color:
                        _waitingInstaller ? AppColors.leben : AppColors.amber,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _waitingInstaller
                      ? 'Download abgeschlossen'
                      : 'Update verfügbar',
                  textAlign: TextAlign.center,
                  style: AppTypography.display(
                    size: 30,
                    color: AppColors.ink,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Version ${widget.release.version}',
                  textAlign: TextAlign.center,
                  style: AppTypography.mono(size: 14),
                ),
                const SizedBox(height: 18),
                Text(
                  _waitingInstaller
                      ? 'Android öffnet jetzt den System-Installer. Tippe "Installieren" um zu aktualisieren. Falls der Dialog nicht erscheint, drücke unten erneut.'
                      : 'Diese Version ist verpflichtend. Lade sie direkt in der App und installiere sie — kein Browser nötig.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    size: 14,
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
                        Text('Was ist neu',
                            style: AppTypography.label(size: 10)),
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
                if (_busy) ...[
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        backgroundColor: AppColors.elevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.amber,
                        ),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _progress > 0
                            ? '${(_progress * 100).toStringAsFixed(0)} %'
                            : 'Starte Download…',
                        style: AppTypography.mono(
                          size: 12,
                          color: AppColors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.herzrot.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.herzrot),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: AppTypography.body(
                        size: 12,
                        color: AppColors.herzrotWarm,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _downloadAndInstall,
                    icon: Icon(
                      _waitingInstaller
                          ? LucideIcons.refreshCw
                          : LucideIcons.download,
                      size: 18,
                    ),
                    label: Text(
                      _busy
                          ? 'Lade…'
                          : _waitingInstaller
                              ? 'Installer erneut öffnen'
                              : 'Update herunterladen',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Android fragt bei erstem Update evtl. nach Berechtigung '
                  '"Apps aus unbekannten Quellen installieren" — bitte für '
                  'Mensaena erlauben.',
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
    // flutter.yml schreibt: { entries: [{ type, title, description }] }
    final entries = cl['entries'];
    if (entries is List && entries.isNotEmpty) {
      final lines = <String>[];
      for (final raw in entries) {
        if (raw is! Map) continue;
        final title = raw['title']?.toString() ?? '';
        final desc = raw['description']?.toString() ?? '';
        if (title.isEmpty && desc.isEmpty) continue;
        lines.add(title.isEmpty ? '• $desc' : '• $title');
        if (desc.isNotEmpty && desc != title) {
          lines.add('  $desc');
        }
        if (lines.length >= 8) break;
      }
      if (lines.isNotEmpty) {
        final joined = lines.join('\n');
        return joined.length > 400 ? '${joined.substring(0, 397)}…' : joined;
      }
    }
    // Fallback: notes/summary/de (vor Workflow-Format-Change moeglich).
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
