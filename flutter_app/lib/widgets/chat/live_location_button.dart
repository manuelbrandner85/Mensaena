/// SKILL: mensaena-features (P8) — Live-Location-Share-Button.
/// Im Chat-Input verfügbar; öffnet Sheet mit Dauer-Auswahl 15/30/60min.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/conversations_repository.dart';
import '../../services/haptics.dart';
import '../../services/live_location_service.dart';
import '../../services/location_service.dart';
import '../../widgets/shared/app_snackbar.dart';

class LiveLocationButton extends StatefulWidget {
  const LiveLocationButton({required this.conversationId, super.key});
  final String conversationId;

  @override
  State<LiveLocationButton> createState() => _LiveLocationButtonState();
}

class _LiveLocationButtonState extends State<LiveLocationButton> {
  bool get _activeHere =>
      LiveLocationService.instance.isSharing &&
      LiveLocationService.instance.currentConversationId == widget.conversationId;

  Future<void> _openSheet() async {
    // kind: 'now' = aktuellen Standort einmalig senden, 'live' = Live teilen
    // (minutes), 'stop' = Live beenden.
    final res = await showModalBottomSheet<({String kind, int minutes})>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(LucideIcons.mapPin,
                    size: 18, color: AppColors.bronze),
                const SizedBox(width: 8),
                Text('chat.share_location_title'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
              ]),
              const SizedBox(height: 12),
              // WhatsApp-Stil: zuerst „aktuellen Standort senden".
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(LucideIcons.navigation, color: AppColors.bronze),
                title: Text('chat.share_current_location'.tr()),
                onTap: () =>
                    Navigator.pop(context, (kind: 'now', minutes: 0)),
              ),
              const Divider(),
              Text('chat.share_live_location_hint'.tr(),
                  style: AppTypography.caption()),
              const SizedBox(height: 8),
              for (final m in [15, 30, 60])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(LucideIcons.clock, color: AppColors.bronze),
                  title: Text('chat.share_duration'
                      .tr(namedArgs: {'min': '$m'})),
                  onTap: () =>
                      Navigator.pop(context, (kind: 'live', minutes: m)),
                ),
              if (_activeHere) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.x,
                      color: AppColors.herzrotWarm),
                  title: Text('chat.share_stop'.tr()),
                  onTap: () =>
                      Navigator.pop(context, (kind: 'stop', minutes: 0)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (res == null) return;
    if (res.kind == 'stop') {
      await LiveLocationService.instance.stop();
    } else if (res.kind == 'now') {
      await _sendCurrentLocation();
    } else if (res.kind == 'live') {
      final ok = await LiveLocationService.instance.start(
        conversationId: widget.conversationId,
        duration: Duration(minutes: res.minutes),
      );
      if (!ok && mounted) {
        AppSnackBar.info(context, 'chat.share_no_permission'.tr());
      } else {
        // Sichtbarer Chat-Eintrag mit der aktuellen Position als Startpunkt.
        await _sendCurrentLocation(silentErrors: true);
      }
    }
    if (mounted) setState(() {});
  }

  /// Holt die aktuelle Position und sendet sie als Standort-Nachricht
  /// (`[LOC:lat:lng]`), die im Chat als tippbare Karten-Vorschau erscheint.
  Future<void> _sendCurrentLocation({bool silentErrors = false}) async {
    final pos = await LocationService.getBestPosition();
    if (pos == null) {
      if (!silentErrors && mounted) {
        AppSnackBar.info(context, 'chat.share_no_permission'.tr());
      }
      return;
    }
    final ok = await MessagesRepository.send(
      conversationId: widget.conversationId,
      content: '[LOC:${pos.latitude}:${pos.longitude}]',
    );
    if (!mounted) return;
    if (ok) {
      Haptics.success();
    } else if (!silentErrors) {
      Haptics.error();
      AppSnackBar.error(context, 'common.error'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'chat.share_live_location'.tr(),
      icon: Icon(
        LucideIcons.mapPin,
        size: 20,
        color: _activeHere ? AppColors.bronze : AppColors.inkSoft,
      ),
      onPressed: _openSheet,
    );
  }
}
