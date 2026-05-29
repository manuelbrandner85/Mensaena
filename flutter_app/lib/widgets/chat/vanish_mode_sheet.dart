/// SKILL: mensaena-features (P2) — Vanish-Mode Toggle pro Conversation.
/// Owner-Sheet: aktivieren + Sekunden-Auswahl (1h/24h/7d).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

class VanishModeSheet extends ConsumerStatefulWidget {
  const VanishModeSheet({required this.conversationId, super.key});
  final String conversationId;

  static Future<void> show(BuildContext context,
      {required String conversationId}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => VanishModeSheet(conversationId: conversationId),
    );
  }

  @override
  ConsumerState<VanishModeSheet> createState() => _VanishModeSheetState();
}

class _VanishModeSheetState extends ConsumerState<VanishModeSheet> {
  bool _loading = true;
  bool _enabled = false;
  int _seconds = 3600;
  static const _choices = <(int, String)>[
    (3600, '1h'),
    (86400, '24h'),
    (604800, '7d'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await sb
          .from('conversations')
          .select('vanish_mode_enabled, vanish_seconds')
          .eq('id', widget.conversationId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _enabled = row?['vanish_mode_enabled'] as bool? ?? false;
        _seconds = (row?['vanish_seconds'] as num?)?.toInt() ?? 3600;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      await sb.from('conversations').update({
        'vanish_mode_enabled': _enabled,
        'vanish_seconds': _seconds,
      }).eq('id', widget.conversationId);
      if (mounted) Navigator.pop(context);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.eyeOff,
                  size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text('vanish.title'.tr(),
                  style: AppTypography.display(
                      size: 18, color: AppColors.ink)),
            ]),
            const SizedBox(height: 8),
            Text('vanish.description'.tr(),
                style: AppTypography.body(
                    size: 13, color: AppColors.inkSoft, height: 1.4)),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              activeColor: AppColors.bronze,
              title: Text('vanish.enable'.tr(),
                  style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w600)),
            ),
            if (_enabled) ...[
              const SizedBox(height: 6),
              Text('vanish.lifetime'.tr(),
                  style: AppTypography.label(size: 11)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: _choices
                    .map((c) => ChoiceChip(
                          selected: _seconds == c.$1,
                          label: Text(c.$2),
                          onSelected: (_) => setState(() => _seconds = c.$1),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(LucideIcons.check, size: 14),
              label: Text('common.save'.tr()),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  minimumSize: const Size.fromHeight(44)),
            ),
          ],
        ),
      ),
    );
  }
}
