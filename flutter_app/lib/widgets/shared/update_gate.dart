import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/app_release.dart';
import '../../providers/shorebird_patch_provider.dart';
import '../../repositories/app_releases_repository.dart';
import '../../services/apk_installer_service.dart';
import '../../services/shorebird_patch_service.dart';
import '../effects/bloom.dart';
import '../effects/cinema_overlay.dart';
import '../effects/glass_card.dart';
import '../effects/vignette.dart';

/// SKILL: mensaena-architektur + mensaena-features + mensaena-design
/// UpdateGate v7 — Cinematic-Polish.
///
/// Visuelle Architektur (Mandatory-Screen):
///   - CinemaOverlay als ambient Wrapper (Sky-Body + Phasen-Atmosphäre)
///   - Vignette unten dezent (Lesbarkeit-first)
///   - Zentriertes Launcher-Logo mit Bloom-Glow (amber, intensity 0.6)
///   - Release-Notes-Card als GlassCard.strong, scrollable, max 240dp
///   - Bronze-Gradient Circular Progress (80dp) während Download
///   - Cinema-Buttons: "Jetzt aktualisieren" (bronze) + "Später" (mute)
///
/// Banner-Modus (optionales Update + User wählt "Später"):
///   - 56dp Top-Banner mit Icon + Title/Subtitle + Close-X
///   - Persistiert via flutter_secure_storage Key
///     `mensaena_update_dismissed_v<version>` — gleiche Version
///     öffnet im selben Cycle nicht erneut den Vollbild-Screen.
///
/// Bestehende Funktionen 1:1 erhalten:
///   - APK-Download mit Progress (ApkInstallerService)
///   - Install via open_filex / PackageInstaller-Intent
///   - Mandatory-Flag-Check (blockiert, kein "Später")
///   - Shorebird-Patches passieren transparent (kein UI)
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate>
    with WidgetsBindingObserver {
  static const _storage = FlutterSecureStorage();
  static const _dismissKeyPrefix = 'mensaena_update_dismissed_v';

  bool _dismissed = false;
  String? _dismissedVersion;
  Timer? _periodicPatchCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Bei jedem Foreground-Resume + alle 3min: Patch-Server fragen.
    // Shorebird's auto_update lief frueher als alleinige Quelle, das
    // war zu spaet — der User sah den Restart-Banner oft erst beim
    // naechsten Cold-Start (also nie). Jetzt zwingt der Timer einen
    // aktiven Check + Download waehrend die App offen ist.
    _periodicPatchCheck = Timer.periodic(
      const Duration(minutes: 3),
      (_) => unawaited(
          ShorebirdPatchService.instance.checkAndDownloadPatch()),
    );
  }

  @override
  void dispose() {
    _periodicPatchCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Beim Resume: Patch-Check sofort. Vor allem wichtig wenn die App
      // im Background lange offen war — der frische Cold-Start-Trigger
      // ist dann veraltet.
      unawaited(ShorebirdPatchService.instance.checkAndDownloadPatch());
      // Auch das App-Release neu pruefen (mandatory APK).
      ref.invalidate(updateCheckProvider);
    }
  }

  Future<void> _dismissForVersion(String version) async {
    await _storage.write(
      key: '$_dismissKeyPrefix$version',
      value: '1',
    );
    if (!mounted) return;
    setState(() {
      _dismissed = true;
      _dismissedVersion = version;
    });
  }

  Future<bool> _isDismissed(String version) async {
    if (_dismissedVersion == version) return _dismissed;
    final v = await _storage.read(key: '$_dismissKeyPrefix$version');
    return v == '1';
  }

  Future<void> _reopen() async {
    setState(() {
      _dismissed = false;
      _dismissedVersion = null;
    });
  }

  /// Wenn kein APK-Update vorliegt: pruefe ob ein Shorebird-OTA-Patch
  /// heruntergeladen wurde. Wenn ja → blende oben den Restart-Banner ein.
  Widget _maybePatchBanner() {
    final patchCheck = ref.watch(shorebirdPatchCheckProvider);
    return patchCheck.when(
      loading: () => widget.child,
      error: (_, __) => widget.child,
      data: (result) {
        if (!result.patchReady) return widget.child;
        return _PatchRestartBanner(
          patchNumber: result.nextPatchNumber,
          child: widget.child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(updateCheckProvider);
    return check.when(
      // Waehrend updateCheckProvider laeuft (100-500ms Supabase-Roundtrip):
      // NICHT widget.child zeigen — bei pending mandatory wuerde der User
      // sonst kurz die App benutzen koennen bevor der Block-Screen kommt.
      loading: () => const _MandatoryLoadingPlaceholder(),
      error: (_, __) => widget.child,
      data: (c) {
        final latest = c.latest;
        if (!c.hasUpdate || latest == null) {
          // Kein APK-Update → Shorebird-OTA-Patch-Check.
          return _maybePatchBanner();
        }

        if (c.isMandatory) {
          return _UpdateFullScreen(
            release: latest,
            isMandatory: true,
            onLater: null,
          );
        }

        // Optionales Update — Banner-Modus möglich
        return FutureBuilder<bool>(
          future: _isDismissed(latest.version),
          builder: (context, snap) {
            final dismissed = snap.data ?? _dismissed;
            if (dismissed) {
              return _BannerWrapper(
                release: latest,
                onTap: _reopen,
                onClose: () => _dismissForVersion(latest.version),
                child: widget.child,
              );
            }
            return _UpdateFullScreen(
              release: latest,
              isMandatory: false,
              onLater: () => _dismissForVersion(latest.version),
            );
          },
        );
      },
    );
  }
}

/// Cinema-Vollbild-Update-Screen (mandatory oder optional).
class _UpdateFullScreen extends StatefulWidget {
  const _UpdateFullScreen({
    required this.release,
    required this.isMandatory,
    required this.onLater,
  });

  final AppRelease release;
  final bool isMandatory;
  final VoidCallback? onLater;

  @override
  State<_UpdateFullScreen> createState() => _UpdateFullScreenState();
}

class _UpdateFullScreenState extends State<_UpdateFullScreen> {
  double _progress = 0;
  bool _busy = false;
  String? _error;
  bool _waitingInstaller = false;

  Future<void> _downloadAndInstall() async {
    final url = widget.release.apkUrl;
    if (url == null || url.isEmpty) {
      setState(() => _error = 'errors.noApkUrl'.tr());
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
        _error = result.errorMessage ?? 'update.failed'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mandatory: System-Navigation komplett verstecken. immersiveSticky
    // bringt sie kurz wieder wenn der User vom Rand wischt, blendet sie
    // aber nach 2-3s automatisch wieder aus — der User kann nicht
    // dauerhaft zum Home wechseln ohne aktive Bedienung.
    if (widget.isMandatory) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return PopScope(
      // Hardware-Back-Button komplett tot. Bei isMandatory ist das
      // zwingend: User darf den Block-Screen nicht durch Back-Tap
      // entkommen. Bei optionalem Update bleibt es ebenfalls aus, weil
      // der Screen sonst weg waere und der User keine Chance haette
      // "Spaeter" zu tippen — er waere wieder im App-Inhalt.
      canPop: false,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: AppColors.voidColor,
          // CinemaOverlay als ambient Hintergrund-Wrapper
          child: CinemaOverlay(
            child: Stack(
              children: [
                // Dezente Vignette unten für Tiefe
                const Positioned.fill(
                  child: VignetteOverlay(intensity: 0.18),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: _buildContent(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        // Zentriertes Logo mit Bloom-Glow (amber)
        Bloom(
          color: AppColors.amber,
          intensity: 0.6,
          radius: 30,
          child: ClipOval(
            child: Container(
              width: 92,
              height: 92,
              color: AppColors.voidColor,
              child: _waitingInstaller
                  ? const Icon(
                      LucideIcons.checkCircle2,
                      color: AppColors.leben,
                      size: 44,
                    )
                  : Image.asset(
                      'assets/launcher/icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        LucideIcons.download,
                        color: AppColors.amber,
                        size: 44,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          _waitingInstaller
              ? 'update.downloadComplete'.tr()
              : 'update.title'.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.display(
            size: 28,
            color: AppColors.ink,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'v${widget.release.version}',
          textAlign: TextAlign.center,
          style: AppTypography.mono(size: 13, color: AppColors.amberWarm),
        ),
        const SizedBox(height: 14),
        Text(
          _waitingInstaller
              ? 'update.installerHint'.tr()
              : (widget.isMandatory
                  ? 'update.mandatoryDescription'.tr()
                  : 'update.optionalDescription'.tr()),
          textAlign: TextAlign.center,
          style: AppTypography.body(
            size: 14,
            color: AppColors.inkSoft,
            height: 1.55,
          ),
        ),
        if (_changelogPreview() != null) ...[
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: GlassCard.strong(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.sparkles,
                        size: 14,
                        color: AppColors.amberWarm,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'update.releaseNotesTitle'.tr(),
                        style: AppTypography.label(size: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        _changelogPreview()!,
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.inkSoft,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: 28),
          _BronzeCircularProgress(progress: _progress),
          const SizedBox(height: 12),
          Text(
            _progress > 0
                ? '${(_progress * 100).toStringAsFixed(0)} %'
                : 'update.downloading'.tr(),
            style: AppTypography.mono(
              size: 12,
              color: AppColors.bronzeSoft,
            ),
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
            child: Column(
              children: [
                Text(
                  _error!,
                  style: AppTypography.body(
                    size: 12,
                    color: AppColors.herzrotWarm,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _downloadAndInstall,
                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                    label: Text('common.retry'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.herzrotWarm,
                      side: const BorderSide(color: AppColors.herzrot),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        // CTA — Bronze gradient FilledButton
        _BronzeCtaButton(
          onPressed: _busy ? null : _downloadAndInstall,
          icon: _busy
              ? LucideIcons.loader
              : _waitingInstaller
                  ? LucideIcons.refreshCw
                  : LucideIcons.download,
          label: _busy
              ? 'update.downloading'.tr()
              : _waitingInstaller
                  ? 'update.openInstaller'.tr()
                  : 'update.cta'.tr(),
        ),
        if (!widget.isMandatory && widget.onLater != null && !_busy) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onLater,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: AppColors.mute.withValues(alpha: 0.4),
                ),
                foregroundColor: AppColors.inkSoft,
              ),
              child: Text(
                'update.later'.tr(),
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          ),
        ],
        // Nach erfolgreichem Download: "App schliessen" + Hinweistext.
        // Wenn der User den PackageInstaller versehentlich abgebrochen
        // hat, hat er hiermit eine saubere Exit-Option statt im
        // _waitingInstaller-Zustand festzuhaengen.
        if (_waitingInstaller) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => SystemNavigator.pop(),
              icon: const Icon(LucideIcons.power, size: 16),
              label: Text('update.closeApp'.tr()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                    color: AppColors.mute.withValues(alpha: 0.4)),
                foregroundColor: AppColors.inkSoft,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'update.installManualHint'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.caption(),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'update.unknownSourcesHint'.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.caption(),
        ),
      ],
    );
  }

  String? _changelogPreview() {
    final cl = widget.release.changelog;
    if (cl.isEmpty) return null;
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
        if (lines.length >= 16) break;
      }
      if (lines.isNotEmpty) {
        return lines.join('\n');
      }
    }
    final notes = cl['notes'] ?? cl['summary'] ?? cl['de'];
    if (notes is String && notes.isNotEmpty) {
      return notes;
    }
    if (notes is List) {
      final lines = notes.whereType<String>().take(6).map((s) => '• $s');
      return lines.join('\n');
    }
    return null;
  }
}

/// Bronze-Gradient Circular Progress (80dp Diameter).
/// Linear sweep mit 4-color stops: bronzeDeep → bronze → bronzeSoft → amberWarm.
class _BronzeCircularProgress extends StatelessWidget {
  const _BronzeCircularProgress({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _BronzeArcPainter(progress: progress),
        child: const Center(
          child: Bloom(
            color: AppColors.bronze,
            intensity: 0.4,
            radius: 14,
            child: Icon(
              LucideIcons.download,
              size: 22,
              color: AppColors.bronzeSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _BronzeArcPainter extends CustomPainter {
  _BronzeArcPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 6) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = AppColors.elevated.withValues(alpha: 0.6);
    canvas.drawCircle(center, radius, track);

    // Bronze-Gradient sweep
    const gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: <Color>[
        AppColors.bronzeDeep,
        AppColors.bronze,
        AppColors.bronzeSoft,
        AppColors.amberWarm,
      ],
      stops: <double>[0.0, 0.4, 0.75, 1.0],
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    final sweep = progress > 0
        ? progress.clamp(0.0, 1.0) * 2 * math.pi
        : 0.45 * 2 * math.pi; // indeterminate-Stub

    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _BronzeArcPainter old) =>
      old.progress != progress;
}

/// Bronze-Gradient CTA-Button — FilledButton-Look mit Bloom.
class _BronzeCtaButton extends StatelessWidget {
  const _BronzeCtaButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      child: Bloom(
        color: AppColors.bronze,
        intensity: enabled ? 0.45 : 0.0,
        radius: 22,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enabled
                  ? const [
                      AppColors.bronze,
                      AppColors.bronzeDeep,
                    ]
                  : [
                      AppColors.elevated,
                      AppColors.surface,
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.bronzeSoft.withValues(alpha: 0.35),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: enabled
                          ? AppColors.inkWarm
                          : AppColors.mute,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: AppTypography.body(
                        size: 15,
                        color: enabled
                            ? AppColors.inkWarm
                            : AppColors.mute,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner-Modus — 56dp Top-Banner über dem Child-Content.
class _BannerWrapper extends StatelessWidget {
  const _BannerWrapper({
    required this.release,
    required this.onTap,
    required this.onClose,
    required this.child,
  });

  final AppRelease release;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: AppColors.voidColor,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.bronzeDeep.withValues(alpha: 0.95),
                        AppColors.bronze.withValues(alpha: 0.85),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.bronzeSoft.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Bloom(
                        color: AppColors.amber,
                        intensity: 0.4,
                        radius: 10,
                        child: Icon(
                          LucideIcons.arrowDownCircle,
                          color: AppColors.inkWarm,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'update.bannerTitle'.tr(),
                              style: AppTypography.body(
                                size: 13,
                                color: AppColors.inkWarm,
                              ),
                            ),
                            Text(
                              'update.bannerSubtitle'.tr(),
                              style: AppTypography.caption(
                                color: AppColors.bronzeSoft,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(
                          LucideIcons.x,
                          color: AppColors.inkSoft,
                          size: 18,
                        ),
                        splashRadius: 18,
                        tooltip: 'common.close'.tr(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Neutraler Lade-Screen waehrend updateCheckProvider noch laeuft.
/// Verhindert dass der User kurz die App benutzt bevor ein mandatory
/// Update den Block-Screen zeigt.
class _MandatoryLoadingPlaceholder extends StatelessWidget {
  const _MandatoryLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: AppColors.voidColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Bloom(
                color: AppColors.amber,
                intensity: 0.4,
                radius: 20,
                child: ClipOval(
                  child: Container(
                    width: 72,
                    height: 72,
                    color: AppColors.voidColor,
                    child: Image.asset(
                      'assets/launcher/icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        LucideIcons.shield,
                        color: AppColors.amber,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.bronze,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gruener nicht-blockierender Banner wenn ein Shorebird OTA-Patch
/// bereitsteht und ein App-Restart noetig ist.
class _PatchRestartBanner extends StatefulWidget {
  const _PatchRestartBanner({required this.child, this.patchNumber});
  final Widget child;
  final int? patchNumber;

  @override
  State<_PatchRestartBanner> createState() => _PatchRestartBannerState();
}

class _PatchRestartBannerState extends State<_PatchRestartBanner> {
  int? _dismissedPatchNumber;

  @override
  void didUpdateWidget(covariant _PatchRestartBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Wenn eine NEUE Patch-Nummer vorliegt: dismissed-State resetten,
    // damit der Banner auch nach mehrfachem Schliessen bei jedem neuen
    // Patch wieder erscheint. Verhindert "Patch verpasst weil ich X
    // getippt habe"-Falle.
    if (oldWidget.patchNumber != widget.patchNumber) {
      if (_dismissedPatchNumber != widget.patchNumber) {
        _dismissedPatchNumber = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedPatchNumber != null &&
        _dismissedPatchNumber == widget.patchNumber) {
      return widget.child;
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: AppColors.voidColor,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.leben.withValues(alpha: 0.95),
                      AppColors.leben.withValues(alpha: 0.80),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.lebenSoft.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Bloom(
                      color: AppColors.leben,
                      intensity: 0.4,
                      radius: 10,
                      child: Icon(
                        LucideIcons.refreshCw,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'update.patchBannerTitle'.tr(),
                            style: AppTypography.body(
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'update.patchBannerSubtitle'.tr(),
                            style: AppTypography.caption(color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => SystemNavigator.pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white24,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: Text(
                        'update.patchRestart'.tr(),
                        style: AppTypography.label(
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => setState(
                          () => _dismissedPatchNumber = widget.patchNumber),
                      icon: const Icon(LucideIcons.x,
                          color: Colors.white70, size: 18),
                      splashRadius: 18,
                      tooltip: 'common.close'.tr(),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}
