/// SKILL: mensaena-features (Phase 6 F71)
/// Danke-Karte senden — kompaktes Sheet mit 4 Designs + Message-Feld.
/// Empfänger wird vom Caller vorgegeben (Profile-Screen, Interaction-Detail).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/mega_repositories.dart';
import '../../services/haptics.dart';

class SendThankYouSheet extends StatefulWidget {
  const SendThankYouSheet({
    required this.receiverId,
    required this.receiverName,
    this.interactionId,
    super.key,
  });
  final String receiverId;
  final String receiverName;
  final String? interactionId;

  static Future<void> show(
    BuildContext context, {
    required String receiverId,
    required String receiverName,
    String? interactionId,
  }) async {
    Haptics.tap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SendThankYouSheet(
        receiverId: receiverId,
        receiverName: receiverName,
        interactionId: interactionId,
      ),
    );
  }

  @override
  State<SendThankYouSheet> createState() => _SendThankYouSheetState();
}

class _SendThankYouSheetState extends State<SendThankYouSheet> {
  int _design = 1;
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  static const _designs = [
    (id: 1, emoji: '🌻', color: Color(0xFFF59E0B), name: 'sun'),
    (id: 2, emoji: '🌿', color: Color(0xFF7BD389), name: 'leaf'),
    (id: 3, emoji: '🌊', color: Color(0xFF66C7C8), name: 'wave'),
    (id: 4, emoji: '🔥', color: Color(0xFFE26B6B), name: 'fire'),
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    Haptics.confirm();
    final ok = await ThankYouCardsRepository.send(
      receiverId: widget.receiverId,
      designId: _design,
      message: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
      interactionId: widget.interactionId,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    final messenger = ScaffoldMessenger.of(context);
    if (ok) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        ok
            ? 'thanks.sent'.tr(namedArgs: {'name': widget.receiverName})
            : 'thanks.sendFailed'.tr(),
        style: AppTypography.body(
            size: 13,
            color: ok ? AppColors.ink : AppColors.herzrotWarm),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _designs.firstWhere((d) => d.id == _design);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(selected.emoji,
                  style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('thanks.sheetTitle'.tr(),
                        style: AppTypography.body(
                            size: 15,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                    Text(
                      'thanks.recipient'
                          .tr(namedArgs: {'name': widget.receiverName}),
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('thanks.pickDesign'.tr().toUpperCase(),
              style: AppTypography.label(size: 9, color: AppColors.mute)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final d in _designs) ...[
                InkWell(
                  onTap: () => setState(() => _design = d.id),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
                        d.color.withValues(alpha: 0.35),
                        d.color.withValues(alpha: 0.1),
                      ]),
                      border: Border.all(
                        color: _design == d.id
                            ? d.color
                            : d.color.withValues(alpha: 0.3),
                        width: _design == d.id ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(d.emoji,
                        style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _msgCtrl,
            maxLines: 3,
            maxLength: 240,
            style: AppTypography.body(size: 14, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'thanks.messageHint'.tr(),
              hintStyle: AppTypography.caption(),
              filled: true,
              fillColor: AppColors.elevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(LucideIcons.send, size: 16),
              label: Text('thanks.sendBtn'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: selected.color,
                foregroundColor: AppColors.voidColor,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
