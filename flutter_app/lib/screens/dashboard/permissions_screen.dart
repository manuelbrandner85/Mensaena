/// SKILL: mensaena-features
/// Zentrale Berechtigungs-Übersicht: zeigt jeden Status (erteilt / nicht
/// erteilt / dauerhaft abgelehnt) und bietet pro Eintrag eine Aktion an —
/// Direkt-Erlauben, In-Einstellungen-öffnen, oder Setup-Flow (Akku).
/// Kein passiver Audit-Screen: ein Tap erteilt die Berechtigung direkt.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/battery_optimization_prompt.dart';
import '../../widgets/shared/permission_rationale_sheet.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  // androidSdk == 0 → nicht-Android oder noch nicht geladen.
  int _androidSdk = 0;
  // Statuskarte aller relevanten Berechtigungen.
  final Map<Permission, PermissionStatus> _status = {};
  // Pro Eintrag: nutzt einen eigenen async-Refresh-Lock, damit ein Tap nicht
  // im Doppelclick mehrere Permission-Dialoge stapelt.
  final Set<Permission> _busy = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Wenn der User aus den App-Einstellungen zurückkehrt, Status neu lesen.
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAll());
    }
  }

  Future<void> _init() async {
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        _androidSdk = info.version.sdkInt;
      } catch (_) {/* Default 0 → konservative Branch */}
    }
    await _refreshAll();
  }

  /// Liste der angezeigten Einträge, dynamisch je nach Android-Version.
  List<_PermEntry> _entries() {
    final useMediaPerms = _androidSdk >= 33;
    return [
      _PermEntry(
        permission: Permission.camera,
        icon: LucideIcons.camera,
        labelKey: 'permissions.items.camera',
        descKey: 'permissions.items.cameraDesc',
        rationale: PermissionRationaleKey.camera,
      ),
      _PermEntry(
        permission: Permission.microphone,
        icon: LucideIcons.mic,
        labelKey: 'permissions.items.microphone',
        descKey: 'permissions.items.microphoneDesc',
        rationale: PermissionRationaleKey.microphone,
      ),
      _PermEntry(
        // Android 13+: READ_MEDIA_IMAGES + _VIDEO laufen über `photos`.
        // Android ≤12: storage deckt READ_EXTERNAL_STORAGE ab.
        permission: useMediaPerms ? Permission.photos : Permission.storage,
        icon: LucideIcons.image,
        labelKey: 'permissions.items.photos',
        descKey: 'permissions.items.photosDesc',
        rationale: PermissionRationaleKey.photos,
      ),
      if (useMediaPerms)
        _PermEntry(
          permission: Permission.audio,
          icon: LucideIcons.music,
          labelKey: 'permissions.items.audioFiles',
          descKey: 'permissions.items.audioFilesDesc',
          rationale: PermissionRationaleKey.audio,
        ),
      _PermEntry(
        permission: Permission.locationWhenInUse,
        icon: LucideIcons.mapPin,
        labelKey: 'permissions.items.location',
        descKey: 'permissions.items.locationDesc',
        rationale: PermissionRationaleKey.location,
      ),
      _PermEntry(
        permission: Permission.notification,
        icon: LucideIcons.bell,
        labelKey: 'permissions.items.notifications',
        descKey: 'permissions.items.notificationsDesc',
        rationale: PermissionRationaleKey.notification,
      ),
      // "Geräte in der Nähe" — Android 12+ (Bluetooth-Headset für Calls).
      if (_androidSdk == 0 || _androidSdk >= 31)
        _PermEntry(
          permission: Permission.bluetoothConnect,
          icon: LucideIcons.bluetooth,
          labelKey: 'permissions.items.nearby',
          descKey: 'permissions.items.nearbyDesc',
          rationale: PermissionRationaleKey.nearby,
        ),
      _PermEntry(
        permission: Permission.phone,
        icon: LucideIcons.phoneCall,
        labelKey: 'permissions.items.phone',
        descKey: 'permissions.items.phoneDesc',
        rationale: PermissionRationaleKey.phone,
      ),
      // Spezialfall: Akku-Optimierung läuft über eigenen Setup-Flow
      // (Samsung braucht 2 Schritte) — kein einfaches request().
      _PermEntry(
        permission: Permission.ignoreBatteryOptimizations,
        icon: LucideIcons.batteryCharging,
        labelKey: 'permissions.items.battery',
        descKey: 'permissions.items.batteryDesc',
        customAction: _openBatterySetup,
      ),
    ];
  }

  Future<void> _refreshAll() async {
    for (final e in _entries()) {
      try {
        _status[e.permission] = await e.permission.status;
      } catch (_) {
        _status[e.permission] = PermissionStatus.denied;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _onTap(_PermEntry e) async {
    if (_busy.contains(e.permission)) return;
    if (e.customAction != null) {
      await e.customAction!();
      await _refreshAll();
      return;
    }
    final current = _status[e.permission] ?? PermissionStatus.denied;
    // Permanent verweigerte Permissions können wir nicht mehr per Dialog
    // anfordern — Rationale wäre verwirrend (nichts würde danach passieren),
    // also gehen wir direkt in die App-Einstellungen.
    if (current.isPermanentlyDenied || current.isRestricted) {
      setState(() => _busy.add(e.permission));
      try {
        await openAppSettings();
        _status[e.permission] = await e.permission.status;
      } catch (_) {} finally {
        if (mounted) setState(() => _busy.remove(e.permission));
      }
      return;
    }
    // Vor dem System-Dialog kurz erklären, warum — User klickt danach mit
    // höherer Wahrscheinlichkeit „Erlauben".
    if (e.rationale != null) {
      final cont = await showPermissionRationale(context, e.rationale!);
      if (!cont || !mounted) return;
    }
    setState(() => _busy.add(e.permission));
    try {
      await e.permission.request();
      _status[e.permission] = await e.permission.status;
    } catch (_) {/* permission_handler-Edgecase ignorieren */} finally {
      if (mounted) {
        setState(() => _busy.remove(e.permission));
      }
    }
  }

  Future<void> _openBatterySetup() => showBatteryOptimizationSetup(context);

  Future<void> _grantAll() async {
    for (final e in _entries()) {
      if (e.customAction != null) continue; // Akku separat
      final s = _status[e.permission];
      if (s != null && (s.isGranted || s.isLimited)) continue;
      if (s != null && (s.isPermanentlyDenied || s.isRestricted)) continue;
      if (e.rationale != null) {
        if (!mounted) return;
        final cont = await showPermissionRationale(context, e.rationale!);
        if (!mounted) return;
        if (!cont) continue;
      }
      try {
        await e.permission.request();
      } catch (_) {}
    }
    await _refreshAll();
  }

  ({String label, Color color, IconData icon}) _statusBadge(
      PermissionStatus s) {
    if (s.isGranted) {
      return (
        label: 'permissions.granted'.tr(),
        color: AppColors.leben,
        icon: LucideIcons.checkCircle2,
      );
    }
    if (s.isLimited) {
      return (
        label: 'permissions.limited'.tr(),
        color: AppColors.amber,
        icon: LucideIcons.alertCircle,
      );
    }
    if (s.isPermanentlyDenied) {
      return (
        label: 'permissions.permanent'.tr(),
        color: AppColors.herzrotWarm,
        icon: LucideIcons.settings,
      );
    }
    if (s.isRestricted) {
      return (
        label: 'permissions.restricted'.tr(),
        color: AppColors.herzrotWarm,
        icon: LucideIcons.shieldAlert,
      );
    }
    if (s.isProvisional) {
      return (
        label: 'permissions.provisional'.tr(),
        color: AppColors.amber,
        icon: LucideIcons.alertCircle,
      );
    }
    if (s.isDenied) {
      return (
        label: 'permissions.denied'.tr(),
        color: AppColors.inkSoft,
        icon: LucideIcons.circle,
      );
    }
    return (
      label: 'permissions.unknown'.tr(),
      color: AppColors.mute,
      icon: LucideIcons.helpCircle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    return DashboardScaffold(
      title: 'permissions.title'.tr(),
      currentRoute: '/dashboard/settings/permissions',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'permissions.intro'.tr(),
            style: AppTypography.body(
              size: 13,
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _grantAll,
            icon: const Icon(LucideIcons.shieldCheck, size: 16),
            label: Text('permissions.grantAll'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.amber,
              side:
                  BorderSide(color: AppColors.amber.withValues(alpha: 0.5)),
              minimumSize: const Size.fromHeight(42),
            ),
          ),
          const SizedBox(height: 18),
          for (final e in entries) _tile(e),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: openAppSettings,
            icon: const Icon(LucideIcons.externalLink, size: 14),
            label: Text('permissions.openAppSettings'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _tile(_PermEntry e) {
    final s = _status[e.permission] ?? PermissionStatus.denied;
    final badge = _statusBadge(s);
    final busy = _busy.contains(e.permission);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badge.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(e.icon, size: 18, color: badge.color),
        ),
        title: Text(
          e.labelKey.tr(),
          style: AppTypography.body(
            size: 14,
            color: AppColors.ink,
            weight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            e.descKey.tr(),
            style: AppTypography.body(
              size: 12,
              color: AppColors.inkSoft,
              height: 1.35,
            ),
          ),
        ),
        trailing: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.amber,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badge.icon, size: 14, color: badge.color),
                  const SizedBox(width: 6),
                  Text(
                    badge.label,
                    style: AppTypography.label(size: 10, color: badge.color),
                  ),
                ],
              ),
        onTap: busy ? null : () => _onTap(e),
      ),
    );
  }
}

class _PermEntry {
  const _PermEntry({
    required this.permission,
    required this.icon,
    required this.labelKey,
    required this.descKey,
    this.customAction,
    this.rationale,
  });

  final Permission permission;
  final IconData icon;
  final String labelKey;
  final String descKey;
  // Wenn gesetzt, übersteuert sie den Standard-request()-Flow (z. B. Akku).
  final Future<void> Function()? customAction;
  // Optionales Pre-Dialog-Sheet, das nutzwertfokussiert erklärt, warum
  // wir diese Berechtigung brauchen — vor dem eigentlichen System-Dialog.
  final PermissionRationaleKey? rationale;
}
