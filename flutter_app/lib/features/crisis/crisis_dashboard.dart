import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import 'models.dart';

/// Header über der Crisis-Liste — Pendant zu CrisisDashboard.tsx.
/// Zeigt 3 Stat-Tiles + 4 Notruf-Quick-Buttons.
class CrisisDashboard extends StatelessWidget {
  const CrisisDashboard({super.key, required this.items});
  final List<Crisis> items;

  int get _activeCount => items.where((c) => c.status == 'active').length;
  int get _criticalCount => items
      .where((c) =>
          c.status == 'active' &&
          (c.urgency == 'critical' || c.urgency == 'high'))
      .length;
  int get _helpersNeeded {
    var sum = 0;
    for (final c in items) {
      if (c.status != 'active') continue;
      sum += (c.neededHelpers - c.helperCount).clamp(0, 999);
    }
    return sum;
  }

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat tiles
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  emoji: '🚨',
                  count: '$_activeCount',
                  label: 'Aktive Krisen',
                  accent: AppColors.emergency500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  emoji: '⚠️',
                  count: '$_criticalCount',
                  label: 'Dringend',
                  accent: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  emoji: '🤝',
                  count: '$_helpersNeeded',
                  label: 'Helfer gesucht',
                  accent: AppColors.primary500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Quick-Help Numbers (inline, kein Modal nötig)
          const Text(
            '🆘 Notruf direkt anrufen',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _QuickCallButton(
                  number: '112',
                  label: 'Notruf',
                  emoji: '🚑',
                  onTap: () => _call('112'),
                ),
                const SizedBox(width: 6),
                _QuickCallButton(
                  number: '110',
                  label: 'Polizei',
                  emoji: '👮',
                  onTap: () => _call('110'),
                ),
                const SizedBox(width: 6),
                _QuickCallButton(
                  number: '0800-1110111',
                  label: 'TelefonSeelsorge',
                  emoji: '🤝',
                  onTap: () => _call('08001110111'),
                ),
                const SizedBox(width: 6),
                _QuickCallButton(
                  number: '116117',
                  label: 'Ärztl. Bereitschaft',
                  emoji: '🩺',
                  onTap: () => _call('116117'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.count,
    required this.label,
    required this.accent,
  });
  final String emoji;
  final String count;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            count,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink400,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCallButton extends StatelessWidget {
  const _QuickCallButton({
    required this.number,
    required this.label,
    required this.emoji,
    required this.onTap,
  });
  final String number;
  final String label;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 110,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.emergency500.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: const TextStyle(
                        color: AppColors.emergency500,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink400,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
