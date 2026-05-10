import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../theme/app_colors.dart';
import 'update_models.dart';
import 'update_service.dart';

/// Vollbild-Sperre die User nicht überspringen können.
/// Lädt die APK direkt in der App herunter, fragt dann die Install-Permission
/// und triggert den Android Package-Installer-Intent — kein externer Browser.
class MandatoryUpdateScreen extends ConsumerStatefulWidget {
  const MandatoryUpdateScreen({super.key, required this.release});
  final AppRelease release;

  @override
  ConsumerState<MandatoryUpdateScreen> createState() =>
      _MandatoryUpdateScreenState();
}

enum _UpdateState { idle, downloading, installing, error }

class _MandatoryUpdateScreenState
    extends ConsumerState<MandatoryUpdateScreen> {
  _UpdateState _state = _UpdateState.idle;
  double _progress = 0;
  String? _errorMessage;
  String? _filePath;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('screen disposed');
    super.dispose();
  }

  Future<void> _runUpdate() async {
    final url = widget.release.apkUrl;
    if (url == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _state = _UpdateState.downloading;
      _progress = 0;
      _errorMessage = null;
    });

    try {
      // 1. APK herunterladen — Cache-Dir, damit OS bei Bedarf aufräumt.
      final dir = await getTemporaryDirectory();
      final filename = 'mensaena-${widget.release.version}.apk';
      final filePath = '${dir.path}/$filename';

      // Vorhandene Datei löschen (falls Vorgänger-Download halb durch)
      final existing = File(filePath);
      if (existing.existsSync()) {
        existing.deleteSync();
      }

      _cancelToken = CancelToken();
      final dio = Dio();
      await dio.download(
        url,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
        options: Options(
          headers: <String, String>{'Accept': 'application/vnd.android.package-archive'},
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      if (!mounted) return;
      setState(() {
        _state = _UpdateState.installing;
        _filePath = filePath;
      });

      // 2. Install-Permission anfragen (Android 8+ braucht REQUEST_INSTALL_PACKAGES).
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _state = _UpdateState.error;
          _errorMessage =
              'Install-Berechtigung fehlt. Bitte in den Einstellungen erlauben '
              'und erneut versuchen.';
        });
        return;
      }

      // 3. Android Package-Installer-Intent triggern.
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        if (!mounted) return;
        setState(() {
          _state = _UpdateState.error;
          _errorMessage =
              'Konnte Installer nicht öffnen: ${result.message}';
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.error;
        _errorMessage = e.type == DioExceptionType.cancel
            ? 'Download abgebrochen.'
            : 'Download fehlgeschlagen: ${e.message ?? e.type.name}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.error;
        _errorMessage = 'Update fehlgeschlagen: $e';
      });
    }
  }

  void _cancel() {
    _cancelToken?.cancel('user cancelled');
  }

  Future<void> _retry() async {
    if (_filePath != null) {
      // Datei bereits geladen → direkt nochmal Installer-Intent
      setState(() {
        _state = _UpdateState.installing;
        _errorMessage = null;
      });
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _state = _UpdateState.error;
          _errorMessage =
              'Install-Berechtigung fehlt. Bitte in den Einstellungen erlauben.';
        });
        return;
      }
      await OpenFilex.open(_filePath!,
          type: 'application/vnd.android.package-archive');
      return;
    }
    await _runUpdate();
  }

  Future<void> _recheck() async {
    ref.invalidate(updateCheckProvider);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary500,
                            AppColors.primary700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.system_update_alt,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Update verfügbar',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary500.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary500.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.primary500,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Damit alles für dich reibungslos läuft, '
                          'aktualisiere bitte auf die neueste Version. '
                          'Der Download startet direkt in der App.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.ink700,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (r.entries.isNotEmpty) ...[
                  const Text(
                    'Was ist neu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: r.entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _ChangelogTile(entry: r.entries[i]),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (_state == _UpdateState.downloading) _ProgressBar(value: _progress),
                if (_state == _UpdateState.error && _errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emergency500.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.emergency500.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.emergency500,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.ink700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _ActionButton(
                  state: _state,
                  progress: _progress,
                  onStart: _runUpdate,
                  onRetry: _retry,
                  onCancel: _cancel,
                ),
                const SizedBox(height: 8),
                if (_state != _UpdateState.downloading)
                  Center(
                    child: TextButton(
                      onPressed: _recheck,
                      child: const Text(
                        'Bereits installiert? Erneut prüfen',
                        style: TextStyle(
                          color: AppColors.ink400,
                          fontSize: 12,
                        ),
                      ),
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).clamp(0, 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lade APK herunter…',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink700,
                ),
              ),
              Text(
                '$pct %',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value > 0 ? value : null,
              minHeight: 6,
              backgroundColor: AppColors.stone200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.state,
    required this.progress,
    required this.onStart,
    required this.onRetry,
    required this.onCancel,
  });
  final _UpdateState state;
  final double progress;
  final VoidCallback onStart;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _UpdateState.idle:
        return _filledButton(
          onPressed: onStart,
          icon: Icons.download_rounded,
          label: 'Jetzt aktualisieren',
        );
      case _UpdateState.downloading:
        return Row(
          children: [
            Expanded(
              child: _filledButton(
                onPressed: null,
                icon: null,
                label: 'Lade ${(progress * 100).toStringAsFixed(0)} % …',
                showSpinner: true,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Abbrechen'),
              ),
            ),
          ],
        );
      case _UpdateState.installing:
        return _filledButton(
          onPressed: null,
          icon: null,
          label: 'Installer wird geöffnet…',
          showSpinner: true,
        );
      case _UpdateState.error:
        return _filledButton(
          onPressed: onRetry,
          icon: Icons.refresh_rounded,
          label: 'Erneut versuchen',
        );
    }
  }

  Widget _filledButton({
    required VoidCallback? onPressed,
    required IconData? icon,
    required String label,
    bool showSpinner = false,
  }) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: showSpinner
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary500,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _ChangelogTile extends StatelessWidget {
  const _ChangelogTile({required this.entry});
  final ChangelogEntry entry;

  Color get _accent {
    switch (entry.type) {
      case ChangelogType.feature:
        return AppColors.primary500;
      case ChangelogType.improvement:
        return const Color(0xFF3B82F6);
      case ChangelogType.fix:
        return const Color(0xFFD97706);
      case ChangelogType.notice:
        return const Color(0xFF8B5CF6);
      case ChangelogType.unknown:
        return AppColors.ink400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stone200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.type.emoji,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.type.label,
                        style: TextStyle(
                          color: _accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink800,
                  ),
                ),
                if ((entry.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink400,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
