import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/organization_categories.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/organization.dart';
import '../../../models/organization_review.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/effects/tilt_card.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// Phase O3 — Organisation-Detail-Screen.
///
/// Komposition:
///   - Header-Card mit optionalem Cover (TiltCard-Parallax), Logo,
///     Name, Verified/Emergency/Category/Country/OpenStatus-Badges
///     und Rating-Sternen.
///   - Quick-Contact-Bar (Phone, Web, Mail, Maps).
///   - 8 Sections: About, Offers (Mehr anzeigen), TargetGroups,
///     Languages, Accessibility-Grid, Contact-Liste, OpeningHours-Tabelle
///     (heutiger Tag highlighted), Tags.
///   - Reviews-Section: 5-Sterne-Form (eingeloggt) + Liste mit
///     Avatar, Sterne, AdminResponse, Hilfreich-Toggle, Loeschen/Melden.
class OrganizationDetailScreen extends ConsumerStatefulWidget {
  const OrganizationDetailScreen({required this.orgId, super.key});
  final String orgId;

  @override
  ConsumerState<OrganizationDetailScreen> createState() =>
      _OrganizationDetailScreenState();
}

class _OrganizationDetailScreenState
    extends ConsumerState<OrganizationDetailScreen> {
  late Future<Organization?> _orgFuture;
  bool _showAllServices = false;

  // Review-Form
  int _rating = 0;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _orgFuture = OrganizationsRepository.getById(widget.orgId);
  }

  // Pull-to-Refresh: Organisation + Bewertungen neu laden.
  Future<void> _reload() async {
    final f = OrganizationsRepository.getById(widget.orgId);
    setState(() => _orgFuture = f);
    ref.invalidate(orgReviewsProvider(widget.orgId));
    await f;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'modules.organization'.tr(),
      currentRoute: '/dashboard/organizations',
      onRefresh: _reload,
      body: SafeArea(
        child: FutureBuilder<Organization?>(
          future: _orgFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return _buildSkeleton();
            }
            final org = snap.data;
            if (org == null) {
              return _buildEmptyState(context);
            }
            return _buildContent(context, org);
          },
        ),
      ),
    );
  }

  // ── Loading / Empty ────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: 32, width: 120),
          SizedBox(height: 16),
          ShimmerBox(height: 192, borderRadius: 16),
          SizedBox(height: 16),
          ShimmerBox(height: 80, borderRadius: 12),
          SizedBox(height: 12),
          ShimmerBox(height: 120, borderRadius: 12),
          SizedBox(height: 12),
          ShimmerBox(height: 120, borderRadius: 12),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.searchX, size: 56, color: AppColors.mute),
            const SizedBox(height: 16),
            Text(
              'organizations.notFound'.tr(),
              style: AppTypography.display(size: 18, color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/dashboard/organizations'),
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: Text('organizations.backToList'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.deep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main Content ───────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, Organization org) {
    final cat = getCategoryConfig(org.category);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(context),
          const SizedBox(height: 8),
          _buildHeaderCard(context, org, cat),
          const SizedBox(height: 12),
          _buildQuickContactBar(context, org),
          const SizedBox(height: 12),
          ..._buildSections(context, org),
          const SizedBox(height: 12),
          _buildReviewsSection(context, org),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go('/dashboard/organizations'),
        icon: const Icon(LucideIcons.arrowLeft, size: 16, color: AppColors.amber),
        label: Text(
          'organizations.backToList'.tr(),
          style: AppTypography.body(
            size: 13,
            color: AppColors.amber,
            weight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  // ── Header-Card ────────────────────────────────────────────────────

  Widget _buildHeaderCard(
      BuildContext context, Organization org, OrgCategoryConfig cat) {
    final hasCover =
        org.coverImageUrl != null && org.coverImageUrl!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasCover)
            TiltCard(
              intensity: 0.6,
              borderRadius: 0,
              child: SizedBox(
                height: 192,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: org.coverImageUrl!,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (_, __) => Container(color: AppColors.elevated),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.elevated),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogoBox(org, cat),
                const SizedBox(width: 14),
                Expanded(child: _buildHeaderTitleColumn(org, cat)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoBox(Organization org, OrgCategoryConfig cat) {
    final hasLogo = org.logoUrl != null && org.logoUrl!.isNotEmpty;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: cat.bgColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: hasLogo
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: org.logoUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                errorWidget: (_, __, ___) =>
                    Icon(cat.icon, color: cat.color, size: 28),
              ),
            )
          : Icon(cat.icon, color: cat.color, size: 28),
    );
  }

  Widget _buildHeaderTitleColumn(Organization org, OrgCategoryConfig cat) {
    final openStatus = isCurrentlyOpen(org.openingHoursJson);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          org.name,
          style: AppTypography.display(
            size: 22,
            color: AppColors.ink,
            weight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (org.isVerified)
              _MicroBadge(
                icon: LucideIcons.shieldCheck,
                label: 'organizations.verified'.tr(),
                color: AppColors.leben,
              ),
            if (org.isEmergency)
              _MicroBadge(
                icon: LucideIcons.alertTriangle,
                label: 'organizations.emergency'.tr(),
                color: AppColors.herzrot,
              ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cat.bgColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                cat.label,
                style: AppTypography.body(
                  size: 11,
                  color: cat.color,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            if (kCountryLabels.containsKey(org.country))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kCountryFlags[org.country] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      kCountryLabels[org.country] ?? '',
                      style: AppTypography.body(
                        size: 11,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            if (openStatus == 'open')
              _MicroBadge(
                icon: LucideIcons.clock,
                label: 'organizations.nowOpen'.tr(),
                color: AppColors.leben,
              )
            else if (openStatus == 'closed')
              _MicroBadge(
                icon: LucideIcons.clock,
                label: 'organizations.nowClosed'.tr(),
                color: AppColors.mute,
              ),
          ],
        ),
        if (org.ratingCount > 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < 5; i++)
                Icon(
                  i < org.ratingAvg.round() ? LucideIcons.star : LucideIcons.star,
                  size: 14,
                  color: i < org.ratingAvg.round()
                      ? AppColors.amber
                      : AppColors.line,
                ),
              const SizedBox(width: 6),
              Text(
                '${org.ratingAvg.toStringAsFixed(1)} (${org.ratingCount})',
                style: AppTypography.body(
                  size: 12,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Quick Contact Bar ──────────────────────────────────────────────

  Widget _buildQuickContactBar(BuildContext context, Organization org) {
    final hasPhone = org.phone != null && org.phone!.isNotEmpty;
    final hasWeb = org.website != null && org.website!.isNotEmpty;
    final hasMail = org.email != null && org.email!.isNotEmpty;
    final hasLocation = (org.latitude != null && org.longitude != null) ||
        (org.address != null && org.address!.isNotEmpty);
    if (!hasPhone && !hasWeb && !hasMail && !hasLocation) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          if (hasPhone)
            Expanded(
              child: _QuickAction(
                icon: LucideIcons.phone,
                label: 'organizations.actions.call'.tr(),
                onTap: () => _safeLaunch('tel:${org.phone}'),
              ),
            ),
          if (hasWeb)
            Expanded(
              child: _QuickAction(
                icon: LucideIcons.globe,
                label: 'organizations.actions.web'.tr(),
                onTap: () => _safeLaunch(org.website!,
                    mode: LaunchMode.externalApplication),
              ),
            ),
          if (hasMail)
            Expanded(
              child: _QuickAction(
                icon: LucideIcons.mail,
                label: 'organizations.actions.mail'.tr(),
                onTap: () => _safeLaunch('mailto:${org.email}'),
              ),
            ),
          if (hasLocation)
            Expanded(
              child: _QuickAction(
                icon: LucideIcons.mapPin,
                label: 'organizations.actions.map'.tr(),
                onTap: () => _openMaps(org),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openMaps(Organization org) async {
    if (org.latitude != null && org.longitude != null) {
      await _safeLaunch(
        'https://maps.google.com/?q=${org.latitude},${org.longitude}',
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    final addr = [org.address, org.zipCode, org.city, org.country]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(', ');
    if (addr.isEmpty) return;
    await _safeLaunch(
      'https://maps.google.com/?q=${Uri.encodeComponent(addr)}',
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _safeLaunch(String url, {LaunchMode? mode}) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: mode ?? LaunchMode.platformDefault);
    } catch (_) {
      // best-effort
    }
  }

  // ── Sections ───────────────────────────────────────────────────────

  List<Widget> _buildSections(BuildContext context, Organization org) {
    final out = <Widget>[];

    // a) About
    final about = (org.description != null && org.description!.isNotEmpty)
        ? org.description!
        : (org.shortDescription ?? '');
    if (about.isNotEmpty) {
      out.add(_Section(
        title: 'organizations.about'.tr(),
        icon: LucideIcons.info,
        iconColor: AppColors.teal,
        child: Text(
          about,
          style: AppTypography.body(
            size: 14,
            color: AppColors.inkSoft,
            height: 1.55,
          ),
        ),
      ));
    }

    // b) Offers
    if (org.services.isNotEmpty) {
      final services = org.services;
      final visible =
          _showAllServices ? services : services.take(8).toList();
      out.add(_Section(
        title: 'organizations.offers'.tr(),
        icon: LucideIcons.tag,
        iconColor: AppColors.amber,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final s in visible) _Pill(label: s)],
            ),
            if (services.length > 8) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    setState(() => _showAllServices = !_showAllServices),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showAllServices
                      ? 'organizations.showLess'.tr()
                      : 'organizations.showAll'.tr(),
                  style: AppTypography.body(
                    size: 12,
                    color: AppColors.amber,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ));
    }

    // c) Target Groups
    if (org.targetGroups.isNotEmpty) {
      out.add(_Section(
        title: 'organizations.targetGroups'.tr(),
        icon: LucideIcons.users,
        iconColor: AppColors.amber,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final g in org.targetGroups) _Pill(label: g)],
        ),
      ));
    }

    // d) Languages
    if (org.languages.isNotEmpty) {
      out.add(_Section(
        title: 'organizations.languagesLabel'.tr(),
        icon: LucideIcons.languages,
        iconColor: AppColors.teal,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final l in org.languages) _Pill(label: l)],
        ),
      ));
    }

    // e) Accessibility
    if (org.accessibility.isNotEmpty) {
      out.add(_Section(
        title: 'organizations.accessibility'.tr(),
        icon: LucideIcons.accessibility,
        iconColor: AppColors.leben,
        child: _buildAccessibilityGrid(org.accessibility),
      ));
    }

    // f) Contact
    out.add(_Section(
      title: 'organizations.contact'.tr(),
      icon: LucideIcons.phoneCall,
      iconColor: AppColors.amber,
      child: _buildContactList(context, org),
    ));

    // g) Opening Hours
    final hasHoursJson =
        org.openingHoursJson != null && org.openingHoursJson!.isNotEmpty;
    final hasHoursText =
        (org.openingHoursText != null && org.openingHoursText!.isNotEmpty) ||
            (org.openingHours != null && org.openingHours!.isNotEmpty);
    if (hasHoursJson || hasHoursText) {
      out.add(_Section(
        title: 'organizations.openingHours'.tr(),
        icon: LucideIcons.clock,
        iconColor: AppColors.amber,
        child: hasHoursJson
            ? _buildHoursTable(org.openingHoursJson!)
            : Text(
                org.openingHoursText ?? org.openingHours ?? '',
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.inkSoft,
                  height: 1.5,
                ),
              ),
      ));
    }

    // h) Tags
    if (org.tags.isNotEmpty) {
      out.add(_Section(
        title: 'organizations.keywords'.tr(),
        icon: LucideIcons.hash,
        iconColor: AppColors.mute,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final t in org.tags) _Pill(label: t)],
        ),
      ));
    }

    // Spacing between sections
    final spaced = <Widget>[];
    for (var i = 0; i < out.length; i++) {
      spaced.add(out[i]);
      if (i < out.length - 1) spaced.add(const SizedBox(height: 12));
    }
    return spaced;
  }

  Widget _buildAccessibilityGrid(Map<String, dynamic> acc) {
    const emojis = <String, String>{
      'wheelchair': '♿',
      'wheelchair_accessible': '♿',
      'blind': '👁',
      'visual_impairment': '👁',
      'deaf': '🦻',
      'hearing_impairment': '🦻',
      'parking': '🅿️',
      'elevator': '🛗',
      'toilet': '🚻',
      'restroom': '🚻',
      'sign_language': '🤟',
      'easy_language': '💬',
    };
    final entries = acc.entries.toList();
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 8.0;
        final itemW = (c.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final e in entries)
              SizedBox(
                width: itemW,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Text(
                        emojis[e.key] ?? '✓',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _humanizeKey(e.key),
                          style: AppTypography.body(
                            size: 12,
                            color: AppColors.inkSoft,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (e.value is bool)
                        Text(
                          (e.value as bool) ? '✓' : '✗',
                          style: AppTypography.body(
                            size: 13,
                            color: (e.value as bool)
                                ? AppColors.leben
                                : AppColors.mute,
                            weight: FontWeight.w700,
                          ),
                        )
                      else
                        Text(
                          e.value.toString(),
                          style: AppTypography.body(
                            size: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _humanizeKey(String k) {
    final parts = k.replaceAll('_', ' ').split(' ');
    return parts.map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  Widget _buildContactList(BuildContext context, Organization org) {
    final rows = <Widget>[];
    final addr = [org.address, org.zipCode, org.city, org.country]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(', ');
    if (addr.isNotEmpty) {
      rows.add(_ContactRow(
        icon: LucideIcons.mapPin,
        label: addr,
        trailing: TextButton(
          onPressed: () => _openMaps(org),
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'organizations.openMaps'.tr(),
            style: AppTypography.body(
              size: 12,
              color: AppColors.amber,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ));
    }
    if (org.phone != null && org.phone!.isNotEmpty) {
      rows.add(_ContactRow(
        icon: LucideIcons.phone,
        label: org.phone!,
        onTap: () => _safeLaunch('tel:${org.phone}'),
      ));
    }
    if (org.fax != null && org.fax!.isNotEmpty) {
      rows.add(_ContactRow(
        icon: LucideIcons.printer,
        label: org.fax!,
      ));
    }
    if (org.email != null && org.email!.isNotEmpty) {
      rows.add(_ContactRow(
        icon: LucideIcons.mail,
        label: org.email!,
        onTap: () => _safeLaunch('mailto:${org.email}'),
      ));
    }
    if (org.website != null && org.website!.isNotEmpty) {
      rows.add(_ContactRow(
        icon: LucideIcons.globe,
        label: org.website!,
        onTap: () => _safeLaunch(org.website!,
            mode: LaunchMode.externalApplication),
        trailingIcon: LucideIcons.externalLink,
      ));
    }
    if (rows.isEmpty) {
      return Text(
        '—',
        style: AppTypography.body(size: 13, color: AppColors.mute),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }

  // ── Opening-Hours-Table ────────────────────────────────────────────

  Widget _buildHoursTable(Map<String, dynamic> json) {
    final todayKey = const [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ][(DateTime.now().weekday - 1).clamp(0, 6)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in kDaysMap.entries)
          _buildHoursRow(
            dayKey: entry.key,
            dayLabel: entry.value,
            raw: json[entry.key],
            isToday: entry.key == todayKey,
          ),
      ],
    );
  }

  Widget _buildHoursRow({
    required String dayKey,
    required String dayLabel,
    required dynamic raw,
    required bool isToday,
  }) {
    final hoursStr = _formatHours(raw);
    final isClosed = hoursStr == null;
    final bgColor =
        isToday ? AppColors.amber.withValues(alpha: 0.10) : Colors.transparent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              dayLabel,
              style: AppTypography.body(
                size: 13,
                color: isToday ? AppColors.amber : AppColors.inkSoft,
                weight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              isClosed ? 'organizations.closed'.tr() : hoursStr,
              style: AppTypography.body(
                size: 13,
                color: isClosed
                    ? AppColors.mute
                    : (isToday ? AppColors.ink : AppColors.inkSoft),
                weight: isToday ? FontWeight.w700 : FontWeight.w400,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String? _formatHours(dynamic raw) {
    if (raw == null) return null;
    final slots = <Map<dynamic, dynamic>>[];
    if (raw is List) {
      for (final s in raw) {
        if (s is Map) slots.add(s);
      }
    } else if (raw is Map) {
      slots.add(raw);
    } else {
      return null;
    }
    if (slots.isEmpty) return null;
    final parts = <String>[];
    for (final slot in slots) {
      if (slot['closed'] == true) continue;
      final open = slot['open']?.toString();
      final close = slot['close']?.toString();
      if (open != null && close != null) {
        parts.add('$open–$close');
      }
    }
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  // ── Reviews Section ────────────────────────────────────────────────

  Widget _buildReviewsSection(BuildContext context, Organization org) {
    final reviewsAsync = ref.watch(orgReviewsProvider(org.id));
    final user = SupabaseService.currentUser;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.messageSquare,
                  size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                'organizations.reviews'.tr(),
                style: AppTypography.display(
                  size: 18,
                  color: AppColors.ink,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              reviewsAsync.maybeWhen(
                data: (list) => Text(
                  '(${list.length})',
                  style: AppTypography.caption(),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const Spacer(),
              if (org.ratingCount > 0) ...[
                for (int i = 0; i < 5; i++)
                  Icon(
                    LucideIcons.star,
                    size: 13,
                    color: i < org.ratingAvg.round()
                        ? AppColors.amber
                        : AppColors.line,
                  ),
                const SizedBox(width: 4),
                Text(
                  org.ratingAvg.toStringAsFixed(1),
                  style: AppTypography.mono(
                      size: 12, color: AppColors.amber),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (user != null) _buildReviewForm(org.id) else _buildLoginCta(),
          const SizedBox(height: 14),
          reviewsAsync.when(
            loading: () => const Column(
              children: [
                _ReviewSkeleton(),
                SizedBox(height: 10),
                _ReviewSkeleton(),
                SizedBox(height: 10),
                _ReviewSkeleton(),
              ],
            ),
            error: (e, _) => Text(
              '$e',
              style: AppTypography.caption(color: AppColors.herzrot),
            ),
            data: (list) {
              if (list.isEmpty) return _buildNoReviews();
              return Column(
                children: [
                  for (final r in list)
                    _ReviewCard(
                      review: r,
                      currentUserId: user?.id,
                      onHelpful: () => _toggleHelpful(r.id, org.id),
                      onDelete: () => _confirmDelete(r.id, org.id),
                      onReport: () => _openReportSheet(r.id),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCta() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.logIn, size: 16, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'organizations.loginToReview'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoReviews() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.messageSquare,
              size: 32, color: AppColors.mute),
          const SizedBox(height: 8),
          Text(
            'organizations.noReviews'.tr(),
            style: AppTypography.body(
                size: 14,
                color: AppColors.ink,
                weight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'organizations.beFirst'.tr(),
            style: AppTypography.caption(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewForm(String orgId) {
    final canSubmit =
        _rating > 0 && _contentCtrl.text.trim().length >= 10 && !_submitting;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'organizations.writeReview'.tr(),
            style: AppTypography.display(
              size: 14,
              color: AppColors.ink,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => setState(() => _rating = i),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      LucideIcons.star,
                      size: 28,
                      color: i <= _rating ? AppColors.amber : AppColors.mute,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleCtrl,
            style: AppTypography.body(size: 13, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'organizations.reviewTitleHint'.tr(),
              hintStyle: AppTypography.body(size: 13, color: AppColors.mute),
              isDense: true,
              filled: true,
              fillColor: AppColors.elevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.amber),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contentCtrl,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            style: AppTypography.body(size: 13, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'organizations.reviewContentHint'.tr(),
              hintStyle: AppTypography.body(size: 13, color: AppColors.mute),
              filled: true,
              fillColor: AppColors.elevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.amber),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: canSubmit ? () => _submitReview(orgId) : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.deep,
                      ),
                    )
                  : const Icon(LucideIcons.send, size: 14),
              label: Text('organizations.submitReview'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.deep,
                disabledBackgroundColor:
                    AppColors.amber.withValues(alpha: 0.30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview(String orgId) async {
    setState(() => _submitting = true);
    final ok = await OrganizationsRepository.createReview(
      orgId: orgId,
      rating: _rating,
      title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) {
        _rating = 0;
        _titleCtrl.clear();
        _contentCtrl.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'organizations.reviewSent'.tr()
              : 'organizations.reviewError'.tr(),
        ),
      ),
    );
    if (ok) ref.invalidate(orgReviewsProvider(orgId));
  }

  Future<void> _toggleHelpful(String reviewId, String orgId) async {
    await OrganizationsRepository.toggleHelpful(reviewId);
    if (!mounted) return;
    ref.invalidate(orgReviewsProvider(orgId));
  }

  Future<void> _confirmDelete(String reviewId, String orgId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'organizations.confirmDelete'.tr(),
          style: AppTypography.body(
              size: 15,
              color: AppColors.ink,
              weight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.herzrot,
              foregroundColor: AppColors.ink,
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await OrganizationsRepository.deleteReview(reviewId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'organizations.reviewDeleted'.tr()
              : 'organizations.reviewError'.tr(),
        ),
      ),
    );
    if (ok) ref.invalidate(orgReviewsProvider(orgId));
  }

  Future<void> _openReportSheet(String reviewId) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final reasons = <String, String>{
          'spam': 'organizations.reasonSpam'.tr(),
          'abuse': 'organizations.reasonAbuse'.tr(),
          'fake': 'organizations.reasonFake'.tr(),
          'other': 'organizations.reasonOther'.tr(),
        };
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'organizations.reportReasonTitle'.tr(),
                  style: AppTypography.display(
                    size: 16,
                    color: AppColors.ink,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (final e in reasons.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.flag,
                        size: 18, color: AppColors.herzrot),
                    title: Text(
                      e.value,
                      style: AppTypography.body(
                          size: 14, color: AppColors.ink),
                    ),
                    onTap: () => Navigator.of(ctx).pop(e.key),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (reason == null) return;
    final ok =
        await OrganizationsRepository.reportReview(reviewId, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'organizations.reportSent'.tr()
              : 'organizations.reviewError'.tr(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Private Sub-Widgets
// ════════════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.icon,
    this.iconColor,
  });
  final String title;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor ?? AppColors.amber),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: AppTypography.display(
                  size: 15,
                  color: AppColors.ink,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        style: AppTypography.body(size: 11, color: AppColors.inkSoft),
      ),
    );
  }
}

class _MicroBadge extends StatelessWidget {
  const _MicroBadge({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.body(
              size: 11,
              color: color,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.amber),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.body(
                size: 11,
                color: AppColors.inkSoft,
                weight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.trailingIcon,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(icon, size: 14, color: AppColors.amber),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.body(
              size: 13,
              color: onTap != null ? AppColors.amber : AppColors.ink,
              weight: FontWeight.w500,
            ),
          ),
        ),
        if (trailingIcon != null)
          Icon(trailingIcon, size: 13, color: AppColors.mute),
        if (trailing != null) trailing!,
      ],
    );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: row,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: row,
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.currentUserId,
    required this.onHelpful,
    required this.onDelete,
    required this.onReport,
  });
  final OrganizationReview review;
  final String? currentUserId;
  final VoidCallback onHelpful;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final isOwn = currentUserId != null && review.userId == currentUserId;
    final name = review.userDisplayName ?? review.userName ?? 'Anonym';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hasAvatar =
        review.userAvatarUrl != null && review.userAvatarUrl!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surface,
                child: hasAvatar
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: review.userAvatarUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          fadeInDuration:
                              const Duration(milliseconds: 200),
                          errorWidget: (_, __, ___) => Text(
                            initial,
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.amber,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        initial,
                        style: AppTypography.body(
                          size: 14,
                          color: AppColors.amber,
                          weight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.ink,
                              weight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _relativeTime(review.createdAt),
                          style: AppTypography.caption(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (int i = 0; i < 5; i++)
                          Icon(
                            LucideIcons.star,
                            size: 14,
                            color: i < review.rating
                                ? AppColors.amber
                                : AppColors.line,
                          ),
                      ],
                    ),
                    if (review.title != null && review.title!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        review.title!,
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      review.content,
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.inkSoft,
                        height: 1.45,
                      ),
                    ),
                    if (review.adminResponse != null &&
                        review.adminResponse!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bronze.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppColors.bronze.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.shieldCheck,
                                    size: 14, color: AppColors.bronze),
                                const SizedBox(width: 6),
                                Text(
                                  'organizations.adminResponse'.tr(),
                                  style: AppTypography.body(
                                    size: 12,
                                    color: AppColors.bronze,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              review.adminResponse!,
                              style: AppTypography.body(
                                size: 12,
                                color: AppColors.inkSoft,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        InkWell(
                          onTap: onHelpful,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.thumbsUp,
                                  size: 14,
                                  color: review.userFoundHelpful
                                      ? AppColors.amber
                                      : AppColors.mute,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${review.helpfulCount}',
                                  style: AppTypography.body(
                                    size: 12,
                                    color: AppColors.inkSoft,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isOwn)
                          TextButton(
                            onPressed: onDelete,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppColors.herzrot,
                            ),
                            child: Text(
                              'common.delete'.tr(),
                              style: AppTypography.body(
                                size: 12,
                                color: AppColors.herzrot,
                                weight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          TextButton(
                            onPressed: onReport,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'organizations.report'.tr(),
                              style: AppTypography.body(
                                size: 12,
                                color: AppColors.mute,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) {
      return 'organizations.timeJustNow'.tr();
    }
    if (diff.inMinutes < 60) {
      return 'organizations.timeMinAgo'
          .tr(namedArgs: {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'organizations.timeHourAgo'
          .tr(namedArgs: {'n': '${diff.inHours}'});
    }
    if (diff.inDays < 7) {
      return 'organizations.timeDayAgo'
          .tr(namedArgs: {'n': '${diff.inDays}'});
    }
    if (diff.inDays < 30) {
      final w = (diff.inDays / 7).floor();
      return 'organizations.timeWeekAgo'.tr(namedArgs: {'n': '$w'});
    }
    if (diff.inDays < 365) {
      final m = (diff.inDays / 30).floor();
      return 'organizations.timeMonthAgo'.tr(namedArgs: {'n': '$m'});
    }
    final y = (diff.inDays / 365).floor();
    return 'organizations.timeYearAgo'.tr(namedArgs: {'n': '$y'});
  }
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 36, height: 36, borderRadius: 18),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 12, width: 140),
                SizedBox(height: 8),
                ShimmerBox(height: 10, width: 80),
                SizedBox(height: 10),
                ShimmerBox(height: 10),
                SizedBox(height: 6),
                ShimmerBox(height: 10, width: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
