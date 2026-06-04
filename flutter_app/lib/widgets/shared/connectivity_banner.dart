/// SKILL: mensaena-features
/// Globaler Offline-Banner (H6): zeigt eine schmale Leiste oben, wenn keine
/// Internetverbindung besteht — und kurz "Wieder online" beim Reconnect.
/// App-weit gemountet (app.dart), damit JEDER Screen das Feedback bekommt
/// statt stiller Fehler beim Senden/Laden.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;
  bool _showReconnected = false;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    try {
      _sub = Connectivity().onConnectivityChanged.listen(_onChange);
      // Initial-Status (nicht blockierend).
      unawaited(Connectivity().checkConnectivity().then(_onChange));
    } catch (_) {/* connectivity_plus evtl. nicht verfügbar → Banner aus */}
  }

  void _onChange(List<ConnectivityResult> res) {
    if (!mounted) return;
    final online = res.any((r) => r != ConnectivityResult.none);
    if (!online && !_offline) {
      setState(() {
        _offline = true;
        _showReconnected = false;
      });
    } else if (online && _offline) {
      // War offline → jetzt online: kurz "Wieder online" zeigen, dann weg.
      setState(() {
        _offline = false;
        _showReconnected = true;
      });
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showReconnected = false);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _offline || _showReconnected;
    return IgnorePointer(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _offline
                    ? AppColors.herzrot.withValues(alpha: 0.92)
                    : AppColors.leben.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 14,
                    spreadRadius: -4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _offline ? LucideIcons.wifiOff : LucideIcons.wifi,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _offline
                        ? 'common.offlineBanner'.tr()
                        : 'common.backOnline'.tr(),
                    style: AppTypography.body(
                      size: 12.5,
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
