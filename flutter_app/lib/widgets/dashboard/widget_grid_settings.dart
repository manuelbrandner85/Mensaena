import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/glass_card.dart';
import '../effects/tilt_card.dart';

/// SKILL: mensaena-features
/// Pendant zu Web `dashboardWidgetStore`. Erlaubt Sichtbarkeit + Reihenfolge
/// der Dashboard-Widgets pro User zu konfigurieren. Persistiert in
/// flutter_secure_storage.
class DashboardWidgetConfig {
  const DashboardWidgetConfig({
    required this.order,
    required this.visible,
  });

  final List<String> order;
  final Set<String> visible;

  static const _key = 'mensaena_widget_grid_v1';
  static const _storage = FlutterSecureStorage();

  /// Default-Reihenfolge — 1:1 zum Web src/app/dashboard/page.tsx.
  static const List<DashboardWidgetMeta> all = [
    DashboardWidgetMeta(
      id: 'hero',
      title: 'widgets.titles.greeting',
      description: 'widgets.descriptions.greeting',
      icon: LucideIcons.sparkles,
      removable: false,
    ),
    DashboardWidgetMeta(
      id: 'safety',
      title: 'widgets.titles.safetyAlerts',
      description: 'widgets.descriptions.safetyAlerts',
      icon: LucideIcons.shield,
      removable: false,
    ),
    DashboardWidgetMeta(
      id: 'onboarding',
      title: 'widgets.titles.startup',
      description: 'widgets.descriptions.startup',
      icon: LucideIcons.checkCircle,
    ),
    DashboardWidgetMeta(
      id: 'quick_actions',
      title: 'widgets.titles.quickActions',
      description: 'widgets.descriptions.quickActions',
      icon: LucideIcons.zap,
    ),
    DashboardWidgetMeta(
      id: 'stats',
      title: 'widgets.titles.stats',
      description: 'widgets.descriptions.stats',
      icon: LucideIcons.barChart3,
    ),
    DashboardWidgetMeta(
      id: 'smart_match',
      title: 'widgets.titles.smartMatch',
      description: 'widgets.descriptions.smartMatch',
      icon: LucideIcons.sparkles,
    ),
    DashboardWidgetMeta(
      id: 'trust_score',
      title: 'widgets.titles.trust',
      description: 'widgets.descriptions.trust',
      icon: LucideIcons.shieldCheck,
    ),
    DashboardWidgetMeta(
      id: 'thanks',
      title: 'widgets.titles.thanksReceived',
      description: 'widgets.descriptions.thanksReceived',
      icon: LucideIcons.heart,
    ),
    DashboardWidgetMeta(
      id: 'community_pulse',
      title: 'widgets.titles.communityPulse',
      description: 'widgets.descriptions.communityPulse',
      icon: LucideIcons.activity,
    ),
    DashboardWidgetMeta(
      id: 'activity_feed',
      title: 'widgets.titles.activity',
      description: 'widgets.descriptions.activity',
      icon: LucideIcons.zap,
    ),
    DashboardWidgetMeta(
      id: 'mini_map',
      title: 'widgets.titles.map',
      description: 'widgets.descriptions.map',
      icon: LucideIcons.mapPin,
    ),
    DashboardWidgetMeta(
      id: 'weekly_digest',
      title: 'widgets.titles.weekOverview',
      description: 'widgets.descriptions.weekOverview',
      icon: LucideIcons.calendar,
    ),
    DashboardWidgetMeta(
      id: 'unread_messages',
      title: 'widgets.titles.unreadMessages',
      description: 'widgets.descriptions.unreadMessages',
      icon: LucideIcons.messageCircle,
    ),
    DashboardWidgetMeta(
      id: 'weekly_challenge',
      title: 'widgets.titles.weekChallenge',
      description: 'widgets.descriptions.weekChallenge',
      icon: LucideIcons.trophy,
    ),
    DashboardWidgetMeta(
      id: 'rating_prompt',
      title: 'widgets.titles.ratingReminder',
      description: 'widgets.descriptions.ratingReminder',
      icon: LucideIcons.star,
    ),
    DashboardWidgetMeta(
      id: 'weather',
      title: 'widgets.titles.weather',
      description: 'widgets.descriptions.weather',
      icon: LucideIcons.cloud,
    ),
    DashboardWidgetMeta(
      id: 'holiday_badge',
      title: 'widgets.titles.holiday',
      description: 'widgets.descriptions.holiday',
      icon: LucideIcons.partyPopper,
    ),
    DashboardWidgetMeta(
      id: 'success_story',
      title: 'widgets.titles.successStory',
      description: 'widgets.descriptions.successStory',
      icon: LucideIcons.bookOpen,
    ),
    DashboardWidgetMeta(
      id: 'bot_tip',
      title: 'widgets.titles.botTip',
      description: 'widgets.descriptions.botTip',
      icon: LucideIcons.sparkles,
    ),
    DashboardWidgetMeta(
      id: 'nearby_posts',
      title: 'widgets.titles.nearYou',
      description: 'widgets.descriptions.nearYou',
      icon: LucideIcons.list,
      removable: false,
    ),
    // Phase 4 (Wave 4 Web-Paritaet): externe Widgets — standardmaessig
    // ausgeschaltet, damit kein API-Call beim First-Open passiert.
    DashboardWidgetMeta(
      id: 'traffic',
      title: 'widgets.titles.traffic',
      description: 'widgets.descriptions.traffic',
      icon: LucideIcons.alertOctagon,
    ),
    DashboardWidgetMeta(
      id: 'books',
      title: 'widgets.titles.books',
      description: 'widgets.descriptions.books',
      icon: LucideIcons.bookOpen,
    ),
    DashboardWidgetMeta(
      id: 'health',
      title: 'widgets.titles.health',
      description: 'widgets.descriptions.health',
      icon: LucideIcons.heart,
    ),
    DashboardWidgetMeta(
      id: 'nasa_apod',
      title: 'widgets.titles.nasaApod',
      description: 'widgets.descriptions.nasaApod',
      icon: LucideIcons.image,
    ),
    DashboardWidgetMeta(
      id: 'on_this_day',
      title: 'widgets.titles.onThisDay',
      description: 'widgets.descriptions.onThisDay',
      icon: LucideIcons.scroll,
    ),
  ];

  /// Widgets die im Default-Setup AUS sind. Sichtbar wird ueber das
  /// Widget-Grid-Settings-Sheet vom User selbst aktiviert.
  ///
  /// Books + Health werden jetzt standardmaessig angezeigt — User-Feedback:
  /// "lieferten keine Daten" weil sie versteckt waren. Traffic bleibt aus,
  /// weil 9 Autobahn-API-Calls bei jedem Open kostspielig sind.
  /// NASA APOD + OnThisDay sind neu, default-an fuer Discovery-Effekt.
  static const Set<String> _defaultHidden = {'traffic'};

  static DashboardWidgetConfig get defaultConfig => DashboardWidgetConfig(
        order: all.map((w) => w.id).toList(),
        visible: all
            .where((w) => !_defaultHidden.contains(w.id))
            .map((w) => w.id)
            .toSet(),
      );

  static Future<DashboardWidgetConfig> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return defaultConfig;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final order = (j['order'] as List?)?.cast<String>() ??
          defaultConfig.order;
      final visible =
          ((j['visible'] as List?)?.cast<String>() ?? defaultConfig.visible)
              .toSet();
      return DashboardWidgetConfig(order: order, visible: visible);
    } catch (_) {
      return defaultConfig;
    }
  }

  Future<void> save() async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'order': order,
          'visible': visible.toList(),
        }),
      );
    } catch (_) {}
  }

  DashboardWidgetConfig copyWith({
    List<String>? order,
    Set<String>? visible,
  }) {
    return DashboardWidgetConfig(
      order: order ?? this.order,
      visible: visible ?? this.visible,
    );
  }
}

class DashboardWidgetMeta {
  const DashboardWidgetMeta({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.removable = true,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool removable;
}

final dashboardWidgetConfigProvider =
    AsyncNotifierProvider<DashboardWidgetConfigNotifier,
        DashboardWidgetConfig>(DashboardWidgetConfigNotifier.new);

class DashboardWidgetConfigNotifier
    extends AsyncNotifier<DashboardWidgetConfig> {
  @override
  Future<DashboardWidgetConfig> build() async {
    return DashboardWidgetConfig.load();
  }

  Future<void> toggleVisible(String id) async {
    final current = state.value ?? DashboardWidgetConfig.defaultConfig;
    final newVisible = Set<String>.from(current.visible);
    if (newVisible.contains(id)) {
      newVisible.remove(id);
    } else {
      newVisible.add(id);
    }
    final next = current.copyWith(visible: newVisible);
    await next.save();
    state = AsyncValue.data(next);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.value ?? DashboardWidgetConfig.defaultConfig;
    final list = List<String>.from(current.order);
    if (oldIndex < newIndex) newIndex -= 1;
    final id = list.removeAt(oldIndex);
    list.insert(newIndex, id);
    final next = current.copyWith(order: list);
    await next.save();
    state = AsyncValue.data(next);
  }

  Future<void> reset() async {
    final next = DashboardWidgetConfig.defaultConfig;
    await next.save();
    state = AsyncValue.data(next);
  }
}

// ─────────────────────────────────────────────────────────────
// Settings-Sheet (Modal)
// ─────────────────────────────────────────────────────────────
class WidgetSettingsSheet extends ConsumerWidget {
  const WidgetSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WidgetSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfgAsync = ref.watch(dashboardWidgetConfigProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                                width: 14,
                                height: 1,
                                color: AppColors.bronze
                                    .withValues(alpha: 0.5)),
                            const SizedBox(width: 6),
                            Text(
                              '§ Dashboard / Einstellungen',
                              style: AppTypography.label(
                                size: 9,
                                color: AppColors.bronze,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('widgets.config'.tr(),
                            style: AppTypography.display(
                                size: 18, color: AppColors.ink)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => ref
                        .read(dashboardWidgetConfigProvider.notifier)
                        .reset(),
                    icon: const Icon(LucideIcons.rotateCcw,
                        size: 12, color: AppColors.mute),
                    label: Text('widgets.resetDefault'.tr(),
                        style: AppTypography.label(
                            size: 9, color: AppColors.mute)),
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'widgets.dragHint'.tr(),
                style: AppTypography.body(
                    size: 12, color: AppColors.mute, height: 1.5),
              ),
            ),
            Expanded(
              child: cfgAsync.when(
                loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.bronze),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (cfg) {
                  final byId = {
                    for (final w in DashboardWidgetConfig.all) w.id: w
                  };
                  final widgets = cfg.order
                      .map((id) => byId[id])
                      .whereType<DashboardWidgetMeta>()
                      .toList();
                  return ReorderableListView.builder(
                    scrollController: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    onReorder: (oldI, newI) => ref
                        .read(dashboardWidgetConfigProvider.notifier)
                        .reorder(oldI, newI),
                    itemCount: widgets.length,
                    proxyDecorator: (child, _, __) => Material(
                      color: Colors.transparent,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      shadowColor:
                          AppColors.bronze.withValues(alpha: 0.6),
                      // Tilt-Card sorgt fuer subtilen 3D-Effekt beim Drag.
                      child: TiltCard(intensity: 0.6, child: child),
                    ),
                    itemBuilder: (_, i) {
                      final w = widgets[i];
                      return _WidgetRow(
                        key: ValueKey(w.id),
                        meta: w,
                        visible: cfg.visible.contains(w.id),
                        onToggle: w.removable
                            ? () => ref
                                .read(dashboardWidgetConfigProvider.notifier)
                                .toggleVisible(w.id)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetRow extends StatelessWidget {
  const _WidgetRow({
    required this.meta,
    required this.visible,
    this.onToggle,
    super.key,
  });

  final DashboardWidgetMeta meta;
  final bool visible;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard.subtle(
        padding: const EdgeInsets.all(12),
        borderRadius: 12,
        phaseTinted: false,
        tint: visible
            ? AppColors.elevated.withValues(alpha: 0.55)
            : AppColors.surface.withValues(alpha: 0.35),
        borderColor: visible
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.03),
        child: Row(
          children: [
            const Icon(
              LucideIcons.gripVertical,
              size: 16,
              color: AppColors.mute,
            ),
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visible
                    ? AppColors.bronze.withValues(alpha: 0.18)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                meta.icon,
                size: 14,
                color: visible ? AppColors.bronze : AppColors.mute,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.title.tr(),
                      style: AppTypography.body(
                        size: 13,
                        color: visible ? AppColors.ink : AppColors.mute,
                        weight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(meta.description.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption()),
                ],
              ),
            ),
            if (onToggle != null)
              Tooltip(
                message: visible
                    ? 'widgets.hide'.tr()
                    : 'widgets.show'.tr(),
                child: Switch(
                  value: visible,
                  onChanged: (_) => onToggle!(),
                  activeColor: AppColors.bronze,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(LucideIcons.lock,
                    size: 12, color: AppColors.mute),
              ),
          ],
        ),
      ),
    );
  }
}

/// Service-Klasse fuer den Read-Pfad — andere Module (z.B. DashboardHome)
/// koennen die persistierte Config laden ohne Riverpod-Abhaengigkeit.
class WidgetGridConfigService {
  const WidgetGridConfigService._();

  /// Persistierten Storage-Key (`mensaena_widget_grid_v1`) lesen und in
  /// `DashboardWidgetConfig` deserialisieren. Liefert `defaultConfig`, wenn
  /// keine Config gespeichert ist oder das JSON beschaedigt ist.
  static Future<DashboardWidgetConfig> load() => DashboardWidgetConfig.load();

  /// Convenience: nur die Reihenfolge zurueckgeben.
  static Future<List<String>> loadOrder() async {
    final cfg = await DashboardWidgetConfig.load();
    return cfg.order;
  }

  /// Convenience: nur die sichtbaren IDs zurueckgeben.
  static Future<Set<String>> loadVisible() async {
    final cfg = await DashboardWidgetConfig.load();
    return cfg.visible;
  }

  /// True, wenn `id` aktuell als sichtbar konfiguriert ist.
  static Future<bool> isVisible(String id) async {
    final cfg = await DashboardWidgetConfig.load();
    return cfg.visible.contains(id);
  }
}
