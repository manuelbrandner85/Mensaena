import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/profile.dart';

/// SKILL: mensaena-design + mensaena-features
/// 1:1-Spiegel von `src/app/dashboard/components/DashboardHeroCard.tsx`.
/// Time-of-Day-Gradient + Radial-Spotlight + Avatar-mit-Online-Dot +
/// Daily-Whisper (deterministisch per Tag im Jahr) + Dabei-seit-Counter.
class DashboardHeroCard extends StatelessWidget {
  const DashboardHeroCard({
    required this.profile,
    required this.memberSinceDays,
    super.key,
  });

  final Profile? profile;
  final int memberSinceDays;

  static const _months = [
    'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni',
    'Juli', 'Aug.', 'Sep.', 'Okt.', 'Nov.', 'Dez.',
  ];

  static const _dailyWhispers = [
    'Eine kleine Geste genügt, um jemandem den Tag zu retten.',
    'Nachbarschaft beginnt mit einem einzigen „Hallo".',
    'Wer teilt, verliert nichts — er gewinnt eine Verbindung.',
    'Heute ist ein guter Tag, um jemandem zuzuhören.',
    'Hilfe bekommt man am leichtesten, wenn man sie zuerst gibt.',
    'Du musst nicht die Welt retten. Nur einen Nachbarn.',
    'Freundlichkeit kostet nichts, zählt aber doppelt.',
    'Jede kleine Tat ist Teil eines größeren Mosaiks.',
  ];

  String _memberSinceLabel(DateTime createdAt) {
    return '${_months[createdAt.month - 1]} ${createdAt.year}';
  }

  String _dailyWhisper() {
    final now = DateTime.now();
    final start = DateTime(now.year);
    final dayOfYear = now.difference(start).inDays;
    return _dailyWhispers[dayOfYear % _dailyWhispers.length];
  }

  ({String greeting, String accent, _TimeOfDay tod}) _greetingFor(int hour) {
    if (hour < 6) {
      return (greeting: 'Guten', accent: 'Morgen', tod: _TimeOfDay.night);
    }
    if (hour < 12) {
      return (greeting: 'Guten', accent: 'Morgen', tod: _TimeOfDay.morning);
    }
    if (hour < 18) {
      return (greeting: 'Guten', accent: 'Tag', tod: _TimeOfDay.day);
    }
    if (hour < 22) {
      return (greeting: 'Guten', accent: 'Abend', tod: _TimeOfDay.evening);
    }
    return (greeting: 'Guten', accent: 'Abend', tod: _TimeOfDay.night);
  }

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final g = _greetingFor(h);
    final p = profile;
    final name = p?.displayName?.trim() ??
        p?.name?.trim() ??
        'Nutzer';
    final initials = name
        .split(' ')
        .map((s) => s.isEmpty ? '' : s[0])
        .where((s) => s.isNotEmpty)
        .join('')
        .toUpperCase();
    final initialsShort =
        initials.length > 2 ? initials.substring(0, 2) : initials;
    final dateFmt = DateFormat('EEEE · d. MMMM y', 'de_DE');
    final dateStr = dateFmt.format(DateTime.now());
    final whisper = _dailyWhisper();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientFor(g.tod),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: AppColors.bronze.withValues(alpha: 0.18)),
        // Premium-Tiefe: weicher, breiter Schatten hebt die Karte ab —
        // wirkt edler als die flache Variante zuvor.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.bronze.withValues(alpha: 0.10),
            blurRadius: 40,
            spreadRadius: -18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Feiner innerer Glanz oben (Glasmorphismus-Kante).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Radial-Spotlight top-left
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _spotlightColor(g.tod).withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Top amber light line
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.bronze.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date label
              _MetaSubtle(text: dateStr),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with online dot
                  Stack(
                    children: [
                      // Feiner Bronze-Verlaufsring um den Avatar (Premium).
                      Container(
                        width: 68,
                        height: 68,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.bronze.withValues(alpha: 0.9),
                              AppColors.bronze.withValues(alpha: 0.25),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.bronze
                                  .withValues(alpha: 0.30),
                              blurRadius: 26,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.deep,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: p?.avatarUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: CachedNetworkImage(
                                  imageUrl: p!.avatarUrl!,
                                  fadeInDuration:
                                      const Duration(milliseconds: 200),
                                  fit: BoxFit.cover,
                                  width: 64,
                                  height: 64,
                                  memCacheWidth: 128,
                                  memCacheHeight: 128,
                                  placeholder: (_, __) => Container(
                                    width: 64,
                                    height: 64,
                                    color: AppColors.elevated,
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 64,
                                    height: 64,
                                    color: AppColors.elevated,
                                    alignment: Alignment.center,
                                    child: Text(
                                      initialsShort.isEmpty
                                          ? 'N'
                                          : initialsShort,
                                      style: AppTypography.display(
                                        size: 22,
                                        color: AppColors.bronze,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                initialsShort.isEmpty
                                    ? 'N'
                                    : initialsShort,
                                style: AppTypography.display(
                                  size: 22,
                                  color: AppColors.bronze,
                                ),
                              ),
                      ),
                      ),
                      // Online dot
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.leben,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.deep, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.leben
                                    .withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Heading mit Accent-Wort
                        RichText(
                          text: TextSpan(
                            style: AppTypography.display(
                              size: 27,
                              color: AppColors.ink,
                              height: 1.12,
                            ),
                            children: [
                              TextSpan(text: '${g.greeting} '),
                              TextSpan(
                                text: g.accent,
                                style: const TextStyle(
                                  color: AppColors.bronze,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              TextSpan(
                                text: ',\n$name.',
                                style: TextStyle(
                                  color: AppColors.ink
                                      .withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Meta-Row
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (p?.nickname != null &&
                                p!.nickname!.isNotEmpty)
                              Text('@${p.nickname}',
                                  style: AppTypography.mono(
                                      size: 10,
                                      color: AppColors.mute)),
                            if (p?.location != null &&
                                p!.location!.isNotEmpty)
                              _MetaIcon(
                                  icon: LucideIcons.mapPin,
                                  text: p.location!),
                            if (p != null)
                              _MetaIcon(
                                icon: LucideIcons.calendar,
                                text:
                                    'Dabei seit ${_memberSinceLabel(p.createdAt)}'
                                    '${memberSinceDays >= 7 ? " · Tag $memberSinceDays" : ""}',
                              ),
                          ],
                        ),
                        // Bio
                        if (p?.bio != null && p!.bio!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            p.bio!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.inkSoft,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Action Chips
              Row(
                children: [
                  _ActionChip(
                    icon: LucideIcons.edit3,
                    label: 'Bearbeiten',
                    onTap: () =>
                        context.push('/dashboard/profile/edit'),
                  ),
                  const SizedBox(width: 8),
                  _ActionChip(
                    icon: LucideIcons.arrowRight,
                    iconAfter: true,
                    label: 'Vollprofil',
                    onTap: () => context.go('/dashboard/profile'),
                  ),
                ],
              ),
              // Daily whisper
              const SizedBox(height: 14),
              Text(
                '„$whisper"',
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.mute,
                  height: 1.5,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 14),
              // Divider gradient
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.bronze.withValues(alpha: 0.25),
                      AppColors.bronze.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.25, 0.75, 1],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _gradientFor(_TimeOfDay tod) {
    switch (tod) {
      case _TimeOfDay.morning:
        return [
          AppColors.bronze.withValues(alpha: 0.20),
          AppColors.bronzeSoft.withValues(alpha: 0.10),
          AppColors.deep,
        ];
      case _TimeOfDay.day:
        return [
          AppColors.bronze.withValues(alpha: 0.15),
          AppColors.tealSoft.withValues(alpha: 0.08),
          AppColors.deep,
        ];
      case _TimeOfDay.evening:
        return [
          AppColors.bronzeSoft.withValues(alpha: 0.22),
          AppColors.herzrot.withValues(alpha: 0.08),
          AppColors.deep,
        ];
      case _TimeOfDay.night:
        return [
          const Color(0xFF818CF8).withValues(alpha: 0.20),
          AppColors.bronze.withValues(alpha: 0.08),
          AppColors.deep,
        ];
    }
  }

  Color _spotlightColor(_TimeOfDay tod) {
    switch (tod) {
      case _TimeOfDay.morning:
        return const Color(0xFFFBBF24);
      case _TimeOfDay.day:
        return const Color(0xFF1EAAA6);
      case _TimeOfDay.evening:
        return const Color(0xFFF59E0B);
      case _TimeOfDay.night:
        return const Color(0xFF7DD3FC);
    }
  }
}

enum _TimeOfDay { morning, day, evening, night }

class _MetaSubtle extends StatelessWidget {
  const _MetaSubtle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 1,
          color: AppColors.bronze.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 6),
        Text(
          text.toLowerCase(),
          style: AppTypography.label(
            size: 9,
            color: AppColors.mute,
            letterSpacing: 0.15,
          ),
        ),
      ],
    );
  }
}

class _MetaIcon extends StatelessWidget {
  const _MetaIcon({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.mute),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.body(
            size: 11,
            color: AppColors.mute,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconAfter = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool iconAfter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.voidColor,
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!iconAfter) ...[
                Icon(icon, size: 13, color: AppColors.inkSoft),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: AppTypography.body(
                      size: 11,
                      color: AppColors.inkSoft,
                      weight: FontWeight.w500)),
              if (iconAfter) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 13, color: AppColors.inkSoft),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
