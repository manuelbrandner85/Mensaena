/// SKILL: mensaena-features
/// Zeigt Teilnehmer eines Events gruppiert nach Status mit expand/collapse.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme/app_colors.dart';
import '../config/theme/app_typography.dart';
import '../repositories/events_repository.dart';

class EventAttendeesSection extends ConsumerStatefulWidget {
  const EventAttendeesSection({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventAttendeesSection> createState() =>
      _EventAttendeesSectionState();
}

class _EventAttendeesSectionState extends ConsumerState<EventAttendeesSection> {
  /// Tracks which status groups are currently fully expanded.
  final Set<String> _expandedStatuses = {};

  static const List<String> _statusOrder = ['going', 'interested', 'declined'];

  @override
  Widget build(BuildContext context) {
    final asyncAttendees = ref.watch(eventAttendeesProvider(widget.eventId));

    return asyncAttendees.when(
      loading: _buildSkeleton,
      error: (_, __) => _buildEmpty(),
      data: (rows) {
        if (rows.isEmpty) return _buildEmpty();

        // Group rows by their attendance status.
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final row in rows) {
          final status = (row['status'] as String?) ?? 'going';
          grouped.putIfAbsent(status, () => []).add(row);
        }

        final children = <Widget>[];
        for (final status in _statusOrder) {
          final list = grouped[status];
          if (list == null || list.isEmpty) continue;
          if (children.isNotEmpty) children.add(const SizedBox(height: 16));
          children.add(_buildGroup(status, list));
        }

        if (children.isEmpty) return _buildEmpty();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Row(
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.elevated,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Text(
      'events.attendeesEmpty'.tr(),
      style: AppTypography.caption(color: AppColors.mute),
    );
  }

  Widget _buildGroup(String status, List<Map<String, dynamic>> rows) {
    final isExpanded = _expandedStatuses.contains(status);
    final showAll = rows.length <= 5 || isExpanded;
    final visible = showAll ? rows : rows.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_iconFor(status), size: 14, color: _colorFor(status)),
            const SizedBox(width: 6),
            Text(
              'events.attendStatus.$status'.tr(),
              style: AppTypography.body(
                size: 13,
                color: AppColors.ink,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${rows.length})',
              style: AppTypography.caption(color: AppColors.mute),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...visible.map(_buildAttendeeRow),
        if (rows.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                setState(() {
                  if (isExpanded) {
                    _expandedStatuses.remove(status);
                  } else {
                    _expandedStatuses.add(status);
                  }
                });
              },
              child: Text(
                isExpanded
                    ? 'events.showLess'.tr()
                    : 'events.showAll'.tr(
                        namedArgs: {'n': rows.length.toString()},
                      ),
                style: AppTypography.body(
                  size: 12,
                  color: AppColors.amber,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAttendeeRow(Map<String, dynamic> row) {
    final profile = (row['profiles'] as Map?)?.cast<String, dynamic>() ?? const {};
    final userId = (profile['id'] as String?) ?? (row['user_id'] as String?) ?? '';
    final displayName = (profile['display_name'] as String?)?.trim();
    final name = (profile['name'] as String?)?.trim();
    final label = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (name != null && name.isNotEmpty ? name : 'Anon');
    final avatarUrl = profile['avatar_url'] as String?;
    final trustScore = (profile['trust_score'] as num?)?.toInt() ?? 0;

    return InkWell(
      onTap: userId.isEmpty ? null : () => context.push('/dashboard/profile/$userId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _buildAvatar(avatarUrl, label),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.body(size: 13, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (trustScore >= 70)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.shieldCheck,
                          size: 10,
                          color: AppColors.trustSoft,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Trust',
                          style: AppTypography.caption(color: AppColors.trustSoft),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, String label) {
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          placeholder: (_, __) => _initialAvatar(label),
          errorWidget: (_, __, ___) => _initialAvatar(label),
        ),
      );
    }
    return _initialAvatar(label);
  }

  Widget _initialAvatar(String label) {
    final initial = label.isNotEmpty ? label.characters.first.toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.elevated,
      child: Text(
        initial,
        style: AppTypography.body(
          size: 13,
          color: AppColors.ink,
          weight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _iconFor(String status) {
    switch (status) {
      case 'going':
        return LucideIcons.check;
      case 'interested':
        return LucideIcons.helpCircle;
      case 'declined':
        return LucideIcons.x;
      default:
        return LucideIcons.user;
    }
  }

  Color _colorFor(String status) {
    switch (status) {
      case 'going':
        return AppColors.leben;
      case 'interested':
        return AppColors.amber;
      case 'declined':
        return AppColors.herzrot;
      default:
        return AppColors.mute;
    }
  }
}
