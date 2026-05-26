/// SKILL: mensaena-features + mensaena-design
/// Mini-Player fuer einen laufenden DM-Call. Erscheint global im
/// DashboardScaffold sobald ActiveCallInfo gesetzt ist und der User
/// nicht auf dem Call-Screen ist. Draggable, tap = zurueck zum Call.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/active_call_provider.dart';

class ActiveCallMiniPlayer extends ConsumerStatefulWidget {
  const ActiveCallMiniPlayer({required this.info, super.key});
  final ActiveCallInfo info;

  @override
  ConsumerState<ActiveCallMiniPlayer> createState() =>
      _ActiveCallMiniPlayerState();
}

class _ActiveCallMiniPlayerState
    extends ConsumerState<ActiveCallMiniPlayer> {
  // Position: relative oben/rechts. User kann den Player verschieben.
  Offset _offset = const Offset(16, 80);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openCall(BuildContext context) {
    final info = widget.info;
    final encRoom = Uri.encodeComponent(info.roomName);
    final encPeer = Uri.encodeComponent(info.peerName);
    context.push('/dashboard/call/${info.callId}?room=$encRoom&peer=$encPeer');
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final elapsed = DateTime.now().difference(info.startedAt);
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      right: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            // d.delta.dx ist von links nach rechts; wir wollen right-anchored
            // → invertieren.
            final nx = (_offset.dx - d.delta.dx).clamp(8.0, size.width - 188);
            final ny = (_offset.dy + d.delta.dy).clamp(40.0, size.height - 200);
            _offset = Offset(nx, ny);
          });
        },
        onTap: () => _openCall(context),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 180,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.leben.withValues(alpha: 0.95),
                  AppColors.leben.withValues(alpha: 0.80),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.leben.withValues(alpha: 0.3),
                  blurRadius: 14,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.phone,
                          size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'call.miniPlayerActive'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(
                            size: 9, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  info.peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13,
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _fmt(elapsed),
                      style: AppTypography.mono(
                        size: 11,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Icon(LucideIcons.expand,
                        size: 12, color: Colors.white70),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
