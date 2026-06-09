/// SKILL: mensaena-features
/// HolidayBadge — Naechster deutscher Feiertag via Nager.Date API.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class HolidayBadge extends StatefulWidget {
  const HolidayBadge({super.key, required this.lat, required this.lng});
  final double lat;
  final double lng;

  @override
  State<HolidayBadge> createState() => _HolidayBadgeState();
}

class _HolidayBadgeState extends State<HolidayBadge> {
  Future<_HolidayStatus?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HolidayStatus?> _load() async {
    try {
      final year = DateTime.now().year;
      final uri = Uri.https(
          'date.nager.at', '/api/v3/PublicHolidays/$year/DE');
      final res =
          await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      _HolidayStatus? best;
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final dateStr = raw['date'] as String?;
        if (dateStr == null) continue;
        final d = DateTime.tryParse(dateStr)?.toUtc();
        if (d == null) continue;
        final daysDiff = d.difference(todayStart).inDays;
        if (daysDiff < 0) continue;
        if (daysDiff > 60) continue;
        final name = (raw['localName'] as String?) ??
            (raw['name'] as String?) ??
            'Feiertag';
        if (best == null || daysDiff < best.days) {
          best = _HolidayStatus(name: name, date: d, days: daysDiff);
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  String _emoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('weihnachten') || n.contains('christ')) return '🎄';
    if (n.contains('silvester') || n.contains('neujahr')) return '🎆';
    if (n.contains('ostern') || n.contains('karfreitag')) return '🐰';
    if (n.contains('pfingst')) return '🕊️';
    if (n.contains('himmelfahrt')) return '☁️';
    if (n.contains('mai')) return '🌷';
    if (n.contains('einheit') || n.contains('national')) return '🇩🇪';
    if (n.contains('reformation')) return '✝️';
    if (n.contains('allerheilig')) return '🕯️';
    return '🎉';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HolidayStatus?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final s = snap.data;
        if (s == null) return const SizedBox.shrink();
        final emoji = _emoji(s.name);
        final headline = s.days == 0
            ? 'Heute ist ${s.name}'
            : s.days == 1
                ? 'Morgen ist ${s.name}'
                : 'Nächster Feiertag: ${s.name}';
        final subtitle = s.days == 0
            ? 'Schönen Feiertag! 🎉'
            : s.days == 1
                ? 'Morgen frei – plane jetzt etwas mit deinen Nachbar:innen.'
                : '${s.date.day.toString().padLeft(2, '0')}.${s.date.month.toString().padLeft(2, '0')}.${s.date.year} · in ${s.days} Tag${s.days == 1 ? '' : 'en'}';
        return InkWell(
          onTap: () => context.go('/dashboard/events'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.bronze.withValues(alpha: 0.16),
                  AppColors.herzrotWarm.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border:
                  Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bronze.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    s.days == 0
                        ? LucideIcons.partyPopper
                        : LucideIcons.calendar,
                    color: AppColors.bronze,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(emoji,
                              style: const TextStyle(
                                  fontSize: 18, height: 1)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                size: 13,
                                color: AppColors.ink,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.body(
                            size: 12, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HolidayStatus {
  const _HolidayStatus({
    required this.name,
    required this.date,
    required this.days,
  });
  final String name;
  final DateTime date;
  final int days;
}
