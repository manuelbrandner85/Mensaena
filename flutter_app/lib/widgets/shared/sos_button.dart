/// SKILL: mensaena-features
/// SOSButton — globaler Notfall-Button im Header.
///
/// Pendant zu Web SOSButton + SOSModal. Pulsierender Kreis in rot,
/// Tap oeffnet ein Bottom-Sheet mit den lokalen Notrufnummern aus
/// emergency_numbers (gefiltert nach User-Country).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/haptics.dart';
import '../../services/locale_country_service.dart';
import '../../services/supabase_service.dart';

class SOSButton extends StatefulWidget {
  const SOSButton({super.key});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'sos.tooltip'.tr(),
      button: true,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final v = _anim.value;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Haptics.heavy();
              _showSOSSheet(context);
            },
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.herzrot.withValues(alpha: 0.12 + 0.12 * v),
                border: Border.all(
                  color: AppColors.herzrot.withValues(alpha: 0.4 + 0.3 * v),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                LucideIcons.alertTriangle,
                size: 16,
                color: AppColors.herzrot,
              ),
            ),
          );
        },
      ),
    );
  }
}

void _showSOSSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => const _SOSSheet(),
  );
}

class _SOSSheet extends StatefulWidget {
  const _SOSSheet();

  @override
  State<_SOSSheet> createState() => _SOSSheetState();
}

class _SOSSheetState extends State<_SOSSheet> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load(LocaleCountryService.forContext(context));
  }

  Future<List<Map<String, dynamic>>> _load(String country) async {
    try {
      final rows = await sb
          .from('emergency_numbers')
          .select()
          .eq('country', country)
          .order('sort_order');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      // Fallback DE wenn das User-Land nicht gepflegt ist.
      try {
        final rows = await sb
            .from('emergency_numbers')
            .select()
            .eq('country', 'DE')
            .order('sort_order');
        return List<Map<String, dynamic>>.from(rows as List);
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          // Design: Glass-Strong-Gradient (ohne Blur — Scroll-Sheet).
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF0141C28), Color(0xF6080C14)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(top: BorderSide(color: Color(0x47ECE5D6))),
          ),
          child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mute.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(LucideIcons.shieldAlert,
                      size: 22, color: AppColors.herzrot),
                  const SizedBox(width: 10),
                  Text(
                    'sos.title'.tr(),
                    style: AppTypography.display(
                        size: 20, color: AppColors.herzrot),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'sos.subtitle'.tr(),
                style: AppTypography.body(size: 12, color: AppColors.inkSoft),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.herzrot),
                    );
                  }
                  final rows = snap.data ?? const <Map<String, dynamic>>[];
                  if (rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('sos.empty'.tr(),
                            style: AppTypography.body(
                                size: 13, color: AppColors.mute)),
                      ),
                    );
                  }
                  final grouped = <String, List<Map<String, dynamic>>>{};
                  for (final r in rows) {
                    final cat = (r['category'] as String?) ?? 'general';
                    grouped.putIfAbsent(cat, () => []).add(r);
                  }
                  return ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: AppTypography.label(
                                size: 9, color: AppColors.mute),
                          ),
                        ),
                        for (final r in entry.value) _SOSRow(row: r),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.herzrot,
                          side: const BorderSide(color: AppColors.herzrot),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go('/dashboard/crisis/create');
                        },
                        icon: const Icon(LucideIcons.alertTriangle, size: 16),
                        label: Text('sos.reportCrisis'.tr()),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          ),
        );
      },
    );
  }
}

class _SOSRow extends StatelessWidget {
  const _SOSRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final label = (row['label'] as String?) ?? '';
    final number = (row['number'] as String?) ?? '';
    final description = (row['description'] as String?) ?? '';
    final is24h = row['is_24h'] == true;
    final isFree = row['is_free'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (number.isEmpty) return;
          HapticFeedback.heavyImpact();
          try {
            await launchUrl(Uri.parse('tel:$number'));
          } catch (_) {/* dialer missing */}
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 64,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.herzrot.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  number,
                  style: AppTypography.display(
                      size: 18, color: AppColors.herzrot),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(description,
                          style: AppTypography.body(
                              size: 11, color: AppColors.inkSoft),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (is24h) _Badge(label: 'sos.is24h'.tr()),
                        if (isFree) ...[
                          if (is24h) const SizedBox(width: 6),
                          _Badge(label: 'sos.isFree'.tr()),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.phone,
                  size: 18, color: AppColors.herzrot),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.leben.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.label(size: 8, color: AppColors.lebenSoft),
      ),
    );
  }
}
