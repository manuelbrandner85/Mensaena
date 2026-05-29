/// SKILL: mensaena-features (P9) — Event QR-Code Check-in.
/// Veranstalter zeigt QR (Event-ID), Teilnehmer scannt → INSERT in
/// event_checkins.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/wave_final_providers.dart';

class EventQrCheckinSheet extends ConsumerStatefulWidget {
  const EventQrCheckinSheet({
    required this.eventId,
    required this.eventTitle,
    required this.isOrganizer,
    super.key,
  });

  final String eventId;
  final String eventTitle;
  final bool isOrganizer;

  static Future<void> show(
    BuildContext context, {
    required String eventId,
    required String eventTitle,
    required bool isOrganizer,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EventQrCheckinSheet(
        eventId: eventId,
        eventTitle: eventTitle,
        isOrganizer: isOrganizer,
      ),
    );
  }

  @override
  ConsumerState<EventQrCheckinSheet> createState() =>
      _EventQrCheckinSheetState();
}

class _EventQrCheckinSheetState extends ConsumerState<EventQrCheckinSheet> {
  bool _scanning = false;
  String? _resultMsg;

  String get _payload => 'mensaena://event-checkin/${widget.eventId}';

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanning) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      if (!raw.startsWith('mensaena://event-checkin/')) continue;
      final id = raw.substring('mensaena://event-checkin/'.length);
      setState(() => _scanning = true);
      final ok =
          await ref.read(eventCheckinsRepoProvider).checkIn(id);
      if (!mounted) return;
      setState(() {
        _resultMsg =
            ok ? 'events.checkin_success'.tr() : 'events.checkin_failed'.tr();
        _scanning = false;
      });
      ref.invalidate(eventCheckinCountProvider(id));
      ref.invalidate(eventCheckinStatusProvider(id));
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(eventCheckinCountProvider(widget.eventId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(LucideIcons.qrCode,
                  size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Expanded(
                child: Text('events.checkin_title'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
              ),
              count.maybeWhen(
                data: (c) => Text(
                    'events.checkin_count'.tr(namedArgs: {'n': '$c'}),
                    style: AppTypography.caption()),
                orElse: () => const SizedBox.shrink(),
              ),
            ]),
            const SizedBox(height: 4),
            Text(widget.eventTitle, style: AppTypography.caption()),
            const SizedBox(height: 18),
            if (widget.isOrganizer)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _payload,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              )
            else
              SizedBox(
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MobileScanner(onDetect: _onDetect),
                ),
              ),
            const SizedBox(height: 14),
            if (_resultMsg != null)
              Text(_resultMsg!,
                  style: AppTypography.body(size: 13, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(
              widget.isOrganizer
                  ? 'events.checkin_organizer_hint'.tr()
                  : 'events.checkin_scan_hint'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.caption(),
            ),
          ],
        ),
      ),
    );
  }
}
