/// SKILL: mensaena-features
/// Ratings-Hub — Bewertungs-Übersicht (Gegeben + Erhalten).
/// 1:1 zu Web /ratings (lebt dort als Tab in Profile, hier als eigener Screen).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/trust_ratings_repository.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/skeleton_card.dart';

class RatingsHubScreen extends ConsumerStatefulWidget {
  const RatingsHubScreen({super.key});

  @override
  ConsumerState<RatingsHubScreen> createState() => _RatingsHubScreenState();
}

class _RatingsHubScreenState extends ConsumerState<RatingsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  Future<List<Map<String, dynamic>>>? _received;
  Future<List<Map<String, dynamic>>>? _given;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  void _load() {
    _received = TrustRatingsRepository.getReceived();
    _given = TrustRatingsRepository.getGiven();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_received!, _given!]);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'ratings.screenTitle'.tr(),
      currentRoute: '/ratings',
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: AppColors.bronze.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.bronze.withValues(alpha: 0.5)),
                ),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.bronze,
                unselectedLabelColor: AppColors.inkSoft,
                labelStyle:
                    AppTypography.body(size: 12, weight: FontWeight.w700),
                unselectedLabelStyle: AppTypography.body(size: 12),
                tabs: [
                  Tab(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.inbox, size: 14),
                        const SizedBox(width: 6),
                        Text('ratings.received'.tr()),
                      ],
                    ),
                  ),
                  Tab(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.send, size: 14),
                        const SizedBox(width: 6),
                        Text('ratings.given'.tr()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  RefreshIndicator(
                    color: AppColors.amber,
                    backgroundColor: AppColors.surface,
                    onRefresh: _refresh,
                    child: _RatingList(
                      future: _received,
                      mode: _Mode.received,
                    ),
                  ),
                  RefreshIndicator(
                    color: AppColors.amber,
                    backgroundColor: AppColors.surface,
                    onRefresh: _refresh,
                    child: _RatingList(
                      future: _given,
                      mode: _Mode.given,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Mode { received, given }

class _RatingList extends StatelessWidget {
  const _RatingList({required this.future, required this.mode});
  final Future<List<Map<String, dynamic>>>? future;
  final _Mode mode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SkeletonList(count: 5, itemHeight: 96);
        }
        final list = snap.data ?? const <Map<String, dynamic>>[];
        if (list.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 100),
              Center(
                child: Column(
                  children: [
                    const Icon(LucideIcons.star,
                        size: 36, color: AppColors.mute),
                    const SizedBox(height: 10),
                    Text(
                      mode == _Mode.received
                          ? 'Noch keine Bewertungen erhalten.'
                          : 'Du hast noch niemanden bewertet.',
                      style: AppTypography.body(
                          size: 14, color: AppColors.mute),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
          itemCount: list.length,
          itemBuilder: (_, i) => _RatingTile(row: list[i], mode: mode),
        );
      },
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({required this.row, required this.mode});
  final Map<String, dynamic> row;
  final _Mode mode;

  @override
  Widget build(BuildContext context) {
    final score = (row['score'] as num?)?.toInt() ?? 0;
    final comment = (row['comment'] as String?)?.trim();
    final createdAt = DateTime.tryParse(
            (row['created_at'] as String?) ?? '') ??
        DateTime.now();
    final profile = row['profiles'] as Map<String, dynamic>?;
    final name = (profile?['display_name'] as String?) ??
        (profile?['name'] as String?) ??
        'Nachbar:in';
    final avatarUrl = profile?['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (avatarUrl != null)
                CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fadeInDuration: const Duration(milliseconds: 200),
                  imageBuilder: (_, img) => CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.elevated,
                    backgroundImage: img,
                  ),
                  placeholder: (_, __) => const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.elevated,
                  ),
                  errorWidget: (_, __, ___) => const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.elevated,
                    child: Icon(LucideIcons.user,
                        size: 16, color: AppColors.bronze),
                  ),
                )
              else
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.elevated,
                  child: Icon(LucideIcons.user,
                      size: 16, color: AppColors.bronze),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode == _Mode.received ? name : 'An $name',
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('dd.MM.yyyy').format(createdAt),
                      style: AppTypography.caption(),
                    ),
                  ],
                ),
              ),
              _Stars(score: score),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: AppTypography.body(
                  size: 13, color: AppColors.inkSoft, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < score;
        return Icon(
          filled ? LucideIcons.star : LucideIcons.star,
          size: 14,
          color: filled ? AppColors.amber : AppColors.line,
        );
      }),
    );
  }
}
