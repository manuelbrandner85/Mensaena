import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-features
/// 1:1-Pendant zu Web `NinaWarningBanner` + `FoodWarningBanner`.
/// Holt aktive Krisen-/Wetterwarnungen vom Web-API-Endpunkt
/// (https://www.mensaena.de/api/nina/warnings).

class SafetyBanners extends ConsumerWidget {
  const SafetyBanners({this.lat, this.lng, super.key});

  final double? lat;
  final double? lng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ninaAsync = ref.watch(ninaWarningsProvider((lat: lat, lng: lng)));
    final foodAsync = ref.watch(foodWarningsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ninaAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return _NinaCard(warnings: list);
          },
        ),
        foodAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _FoodCard(warnings: list),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Nina-Warnings
// ─────────────────────────────────────────────────────────────
class NinaWarning {
  const NinaWarning({
    required this.id,
    required this.title,
    required this.severity,
    this.event,
    this.areaDesc,
    this.onset,
    this.expires,
  });

  final String id;
  final String title;
  final String severity; // Extreme / Severe / Moderate / Minor
  final String? event;
  final String? areaDesc;
  final DateTime? onset;
  final DateTime? expires;

  factory NinaWarning.fromJson(Map<String, dynamic> j) => NinaWarning(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        severity: j['severity'] as String? ?? 'Minor',
        event: j['event'] as String?,
        areaDesc: j['area_desc'] as String?,
        onset: j['onset'] != null
            ? DateTime.tryParse(j['onset'] as String)
            : null,
        expires: j['expires'] != null
            ? DateTime.tryParse(j['expires'] as String)
            : null,
      );

  String pickEmoji() {
    final h = '${event ?? ''} $title'.toLowerCase();
    if (RegExp(r'sturm|orkan|böen|wind').hasMatch(h)) return '🌪️';
    if (RegExp(r'gewitter|blitz').hasMatch(h)) return '⛈️';
    if (RegExp(r'hitze|tropennacht').hasMatch(h)) return '🔥';
    if (RegExp(r'frost|kälte').hasMatch(h)) return '❄️';
    if (RegExp(r'glätte|glatteis').hasMatch(h)) return '🧊';
    if (RegExp(r'nebel').hasMatch(h)) return '🌫️';
    if (RegExp(r'schnee').hasMatch(h)) return '🌨️';
    if (RegExp(r'regen|niederschlag').hasMatch(h)) return '🌧️';
    if (RegExp(r'hagel').hasMatch(h)) return '🌨️';
    return '⚠️';
  }
}

final ninaWarningsProvider = FutureProvider.family<
    List<NinaWarning>,
    ({double? lat, double? lng})>((ref, geo) async {
  try {
    final uri =
        Uri.parse('https://www.mensaena.de/api/nina/warnings').replace(
      queryParameters: {
        if (geo.lat != null) 'lat': geo.lat.toString(),
        if (geo.lng != null) 'lng': geo.lng.toString(),
      },
    );
    final res =
        await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return const [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['warnings'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(NinaWarning.fromJson)
        .toList();
  } catch (_) {
    return const [];
  }
});

class _NinaCard extends StatefulWidget {
  const _NinaCard({required this.warnings});
  final List<NinaWarning> warnings;

  @override
  State<_NinaCard> createState() => _NinaCardState();
}

class _NinaCardState extends State<_NinaCard> {
  bool _expanded = false;

  Color _severityColor(String s) {
    switch (s) {
      case 'Extreme':
        return const Color(0xFFDC2626);
      case 'Severe':
        return const Color(0xFFEA580C);
      case 'Moderate':
        return const Color(0xFFEAB308);
      default:
        return AppColors.tealSoft;
    }
  }

  String _severityLabel(String s) {
    switch (s) {
      case 'Extreme':
        return 'EXTREM';
      case 'Severe':
        return 'SCHWER';
      case 'Moderate':
        return 'MITTEL';
      default:
        return 'GERING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = widget.warnings.first;
    final color = _severityColor(top.severity);
    final more = widget.warnings.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(top.pickEmoji(),
                        style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(_severityLabel(top.severity),
                                  style: AppTypography.label(
                                      size: 8, color: color)),
                            ),
                            const SizedBox(width: 6),
                            if (more > 0)
                              Text('+$more weitere',
                                  style: AppTypography.label(
                                      size: 9, color: AppColors.mute)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          top.title,
                          maxLines: _expanded ? 8 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        if (top.areaDesc != null) ...[
                          const SizedBox(height: 2),
                          Text(top.areaDesc!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption()),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.mute,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.warnings.length > 1) ...[
            Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.05)),
            for (final w in widget.warnings.skip(1).take(3))
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Text(w.pickEmoji(),
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        w.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          size: 12,
                          color: AppColors.inkSoft,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Food-Warnings (Lebensmittel-Rückrufe)
// ─────────────────────────────────────────────────────────────
class FoodWarning {
  const FoodWarning({
    required this.id,
    required this.title,
    required this.publishedAt,
    this.brand,
    this.product,
  });

  final String id;
  final String title;
  final DateTime publishedAt;
  final String? brand;
  final String? product;

  factory FoodWarning.fromJson(Map<String, dynamic> j) => FoodWarning(
        id: j['id']?.toString() ?? '',
        title: j['title'] as String? ?? j['product_name'] as String? ?? '',
        publishedAt:
            DateTime.tryParse(j['published_at'] as String? ?? '') ??
                DateTime.now(),
        brand: j['brand'] as String?,
        product: j['product_name'] as String?,
      );
}

final foodWarningsProvider =
    FutureProvider<List<FoodWarning>>((ref) async {
  try {
    final uri = Uri.parse('https://www.mensaena.de/api/food-warnings');
    final res =
        await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return const [];
    final data = jsonDecode(res.body);
    final list = data is List ? data : ((data['warnings'] as List?) ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(FoodWarning.fromJson)
        .take(5)
        .toList();
  } catch (_) {
    return const [];
  }
});

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.warnings});
  final List<FoodWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final top = warnings.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🥫', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('LEBENSMITTEL-RÜCKRUF',
                          style: AppTypography.label(
                              size: 8, color: AppColors.amber)),
                    ),
                    const SizedBox(width: 6),
                    if (warnings.length > 1)
                      Text('+${warnings.length - 1} weitere',
                          style: AppTypography.label(
                              size: 9, color: AppColors.mute)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  top.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.ink,
                    weight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
