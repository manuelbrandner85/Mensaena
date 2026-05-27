/// SKILL: mensaena-features (Phase 10 A/B/C/D)
/// Dashboard-Sektionen-Definition + CollapsibleSection-Widget.
///
/// 6 Sektionen mit Tageszeit-Sortierung:
///   A1 "Mein Tag"         — TealSoft #5BA4A4
///   A2 "Community"        — Herzrot  #C0392B
///   A3 "Gamification"     — Bronze   #C9A96E
///   A4 "Umgebung"         — Leben    #27AE60
///   A5 "Wissen"           — Lila     #8E44AD
///   A6 "Events & Zeit"    — Blau     #2980B9
///
/// C1 — Tageszeit-Sortierung:
///   06–12 Vormittag : MeinTag → Events → Community → Umgebung → Gamification → Wissen
///   12–18 Nachmittag: Community → Events → MeinTag → Gamification → Umgebung → Wissen
///   18–22 Abend     : MeinTag → Wissen → Gamification → Community → Events → Umgebung
///   22–06 Nacht     : Wissen → MeinTag → Gamification → Community → Umgebung → Events
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// Sektion-ID (stable für Secure-Storage-Keys).
enum DashboardSectionId { myDay, community, gamification, environment, knowledge, events }

class DashboardSection {
  const DashboardSection({
    required this.id,
    required this.titleKey,
    required this.icon,
    required this.color,
    required this.widgetIds,
  });
  final DashboardSectionId id;
  final String titleKey;
  final IconData icon;
  final Color color;
  final List<String> widgetIds;
}

/// Widget-IDs je Sektion (matched die Strings im dashboard_widget_config).
const _sections = <DashboardSection>[
  DashboardSection(
    id: DashboardSectionId.myDay,
    titleKey: 'dashboard.sections.myDay',
    icon: LucideIcons.sunrise,
    color: Color(0xFF5BA4A4),
    widgetIds: [
      'hero',
      'sky',
      'mood_chart',
      'affirmation',
      'daily_quote',
      'health',
    ],
  ),
  DashboardSection(
    id: DashboardSectionId.community,
    titleKey: 'dashboard.sections.community',
    icon: LucideIcons.users,
    color: Color(0xFFC0392B),
    widgetIds: [
      'activity_feed',
      'community_pulse',
      'nearby_neighbors',
      'smart_match',
      'thanks_received',
      'unread_messages',
      'success_story',
      'friend_suggestions',
    ],
  ),
  DashboardSection(
    id: DashboardSectionId.gamification,
    titleKey: 'dashboard.sections.gamification',
    icon: LucideIcons.trophy,
    color: Color(0xFFC9A96E),
    widgetIds: [
      'progress_trio',
      'karma',
      'streak',
      'help_streak',
      'personal_best',
      'daily_challenges',
      'weekly_challenge_highlight',
      'holiday_badge',
    ],
  ),
  DashboardSection(
    id: DashboardSectionId.environment,
    titleKey: 'dashboard.sections.environment',
    icon: LucideIcons.compass,
    color: Color(0xFF27AE60),
    widgetIds: [
      'mini_map',
      'nasa_apod',
      'alerts_badge',
      'recent_routes',
      'activity_heatmap',
      'water_level',
      'weather',
      'traffic_info',
      'safety_banners',
      'moon',
      'sun',
    ],
  ),
  DashboardSection(
    id: DashboardSectionId.knowledge,
    titleKey: 'dashboard.sections.knowledge',
    icon: LucideIcons.bookOpen,
    color: Color(0xFF8E44AD),
    widgetIds: [
      'on_this_day',
      'gratitude',
      'quick_note',
      'weekly_recap',
      'weekly_digest',
      'bot_tip',
    ],
  ),
  DashboardSection(
    id: DashboardSectionId.events,
    titleKey: 'dashboard.sections.events',
    icon: LucideIcons.calendar,
    color: Color(0xFF2980B9),
    widgetIds: [
      'today_events',
      'become_mentor_cta',
    ],
  ),
];

/// C1: Tageszeit-Reihenfolge.
List<DashboardSection> orderedSections(DateTime now) {
  final h = now.hour;
  List<DashboardSectionId> order;
  if (h >= 6 && h < 12) {
    order = const [
      DashboardSectionId.myDay,
      DashboardSectionId.events,
      DashboardSectionId.community,
      DashboardSectionId.environment,
      DashboardSectionId.gamification,
      DashboardSectionId.knowledge,
    ];
  } else if (h >= 12 && h < 18) {
    order = const [
      DashboardSectionId.community,
      DashboardSectionId.events,
      DashboardSectionId.myDay,
      DashboardSectionId.gamification,
      DashboardSectionId.environment,
      DashboardSectionId.knowledge,
    ];
  } else if (h >= 18 && h < 22) {
    order = const [
      DashboardSectionId.myDay,
      DashboardSectionId.knowledge,
      DashboardSectionId.gamification,
      DashboardSectionId.community,
      DashboardSectionId.events,
      DashboardSectionId.environment,
    ];
  } else {
    order = const [
      DashboardSectionId.knowledge,
      DashboardSectionId.myDay,
      DashboardSectionId.gamification,
      DashboardSectionId.community,
      DashboardSectionId.environment,
      DashboardSectionId.events,
    ];
  }
  return [for (final id in order) _sections.firstWhere((s) => s.id == id)];
}

DashboardSection? sectionForWidget(String widgetId) {
  for (final s in _sections) {
    if (s.widgetIds.contains(widgetId)) return s;
  }
  return null;
}

/// Persisted collapsed-State pro Sektion (flutter_secure_storage).
class CollapsedSectionsNotifier extends StateNotifier<Set<DashboardSectionId>> {
  CollapsedSectionsNotifier() : super(<DashboardSectionId>{}) {
    _load();
  }
  static const _storage = FlutterSecureStorage();
  static const _key = 'mensaena_dashboard_collapsed_v1';

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return;
      final ids = raw
          .split(',')
          .map((s) => DashboardSectionId.values
              .firstWhere((e) => e.name == s,
                  orElse: () => DashboardSectionId.myDay))
          .toSet();
      state = ids;
    } catch (_) {}
  }

  Future<void> toggle(DashboardSectionId id) async {
    final next = {...state};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
    HapticFeedback.selectionClick();
    try {
      await _storage.write(
        key: _key,
        value: next.map((e) => e.name).join(','),
      );
    } catch (_) {}
  }

  Future<void> collapseAll() async {
    state = DashboardSectionId.values.toSet();
    try {
      await _storage.write(
        key: _key,
        value: state.map((e) => e.name).join(','),
      );
    } catch (_) {}
  }

  Future<void> expandAll() async {
    state = <DashboardSectionId>{};
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

final collapsedSectionsProvider =
    StateNotifierProvider<CollapsedSectionsNotifier, Set<DashboardSectionId>>(
        (ref) => CollapsedSectionsNotifier());

/// D1+D2+D4: Glassmorphism-Sektion mit Bronze-Border-Glow,
/// 3px-Left-Border in Sektions-Farbe, Header mit Icon + Titel +
/// optional Badge + Chevron-Toggle.
class CollapsibleSection extends ConsumerWidget {
  const CollapsibleSection({
    required this.section,
    required this.child,
    this.badgeCount,
    super.key,
  });

  final DashboardSection section;
  final Widget child;
  final int? badgeCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed =
        ref.watch(collapsedSectionsProvider).contains(section.id);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border(
          left: BorderSide(color: section.color, width: 3),
          top: BorderSide(
              color: AppColors.bronze.withValues(alpha: 0.15), width: 1),
          right: BorderSide(
              color: AppColors.bronze.withValues(alpha: 0.15), width: 1),
          bottom: BorderSide(
              color: AppColors.bronze.withValues(alpha: 0.15), width: 1),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => ref
                .read(collapsedSectionsProvider.notifier)
                .toggle(section.id),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              topLeft: Radius.circular(4),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    section.color.withValues(alpha: 0.18),
                    section.color.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Icon(section.icon, color: section.color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.titleKey.tr(),
                      style: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          weight: FontWeight.w700),
                    ),
                  ),
                  if (badgeCount != null && badgeCount! > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: section.color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: AppTypography.body(
                            size: 10,
                            color: AppColors.voidColor,
                            weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: collapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      LucideIcons.chevronDown,
                      color: section.color,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Body (animated collapse)
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: collapsed
                ? const SizedBox(height: 0, width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                    child: child,
                  ),
          ),
        ],
      ),
    );
  }
}

/// F4 — Alles-Zuklappen-Toggle (Header-Button).
class CollapseAllToggle extends ConsumerWidget {
  const CollapseAllToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCollapsed =
        ref.watch(collapsedSectionsProvider).length ==
            DashboardSectionId.values.length;
    return IconButton(
      tooltip: allCollapsed
          ? 'dashboard.expandAll'.tr()
          : 'dashboard.collapseAll'.tr(),
      icon: Icon(
        allCollapsed ? LucideIcons.chevronsDown : LucideIcons.chevronsUp,
        size: 18,
        color: AppColors.bronze,
      ),
      onPressed: () {
        final notifier = ref.read(collapsedSectionsProvider.notifier);
        if (allCollapsed) {
          notifier.expandAll();
        } else {
          notifier.collapseAll();
        }
      },
    );
  }
}
