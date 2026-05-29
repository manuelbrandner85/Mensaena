/// SKILL: mensaena-features (P8) — Live-Location-Share-Button.
/// Im Chat-Input verfügbar; öffnet Sheet mit Dauer-Auswahl 15/30/60min.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/live_location_service.dart';

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
    final selected = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
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
                Text('chat.share_live_location'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
              ]),
              const SizedBox(height: 4),
              Text('chat.share_live_location_hint'.tr(),
                  style: AppTypography.caption()),
              const SizedBox(height: 16),
              for (final m in [15, 30, 60])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(LucideIcons.clock, color: AppColors.bronze),
                  title: Text('chat.share_duration'
                      .tr(namedArgs: {'min': '$m'})),
                  onTap: () =>
                      Navigator.pop(context, Duration(minutes: m)),
                ),
              if (_activeHere) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.x,
                      color: AppColors.herzrotWarm),
                  title: Text('chat.share_stop'.tr()),
                  onTap: () => Navigator.pop(context, Duration.zero),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    if (selected == Duration.zero) {
      await LiveLocationService.instance.stop();
    } else {
      final ok = await LiveLocationService.instance.start(
        conversationId: widget.conversationId,
        duration: selected,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('chat.share_no_permission'.tr())));
      }
    }
    if (mounted) setState(() {});
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
