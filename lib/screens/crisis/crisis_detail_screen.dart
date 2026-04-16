import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/crisis_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/models/crisis.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/badge_widget.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/section_header.dart';

class CrisisDetailScreen extends ConsumerStatefulWidget {
  final String crisisId;
  const CrisisDetailScreen({super.key, required this.crisisId});

  @override
  ConsumerState<CrisisDetailScreen> createState() =>
      _CrisisDetailScreenState();
}

class _CrisisDetailScreenState extends ConsumerState<CrisisDetailScreen> {
  final _updateController = TextEditingController();
  bool _showUpdateForm = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }

  Color _urgencyColor(CrisisUrgency urgency) {
    switch (urgency) {
      case CrisisUrgency.critical:
        return AppColors.emergency;
      case CrisisUrgency.high:
        return Colors.orange;
      case CrisisUrgency.medium:
        return AppColors.warning;
      case CrisisUrgency.low:
        return AppColors.success;
    }
  }

  Color _statusColor(CrisisStatus status) {
    switch (status) {
      case CrisisStatus.active:
        return AppColors.emergency;
      case CrisisStatus.inProgress:
        return AppColors.warning;
      case CrisisStatus.resolved:
        return AppColors.success;
      case CrisisStatus.falseAlarm:
        return AppColors.textMuted;
      case CrisisStatus.cancelled:
        return AppColors.textMuted;
    }
  }

  IconData _updateTypeIcon(String type) {
    switch (type) {
      case 'status_change':
        return Icons.swap_horiz;
      case 'info':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_amber;
      case 'resolution':
        return Icons.check_circle_outline;
      default:
        return Icons.update;
    }
  }

  @override
  Widget build(BuildContext context) {
    final crisisAsync = ref.watch(crisisDetailProvider(widget.crisisId));
    final helpersAsync = ref.watch(crisisHelpersProvider(widget.crisisId));
    final updatesAsync = ref.watch(crisisUpdatesProvider(widget.crisisId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Krisenmeldung'),
        backgroundColor: AppColors.emergencyLight,
        actions: [
          crisisAsync.whenOrNull(
                data: (crisis) {
                  if (crisis == null) return null;
                  if (crisis.reporterId == currentUserId) {
                    return PopupMenuButton<String>(
                      onSelected: (value) => _handleStatusChange(value),
                      itemBuilder: (_) => [
                        if (crisis.crisisStatus != CrisisStatus.inProgress)
                          const PopupMenuItem(
                            value: 'in_progress',
                            child: Text('Als "In Bearbeitung" markieren'),
                          ),
                        if (crisis.crisisStatus != CrisisStatus.resolved)
                          const PopupMenuItem(
                            value: 'resolved',
                            child: Text('Als gelöst markieren'),
                          ),
                        if (crisis.crisisStatus != CrisisStatus.cancelled)
                          const PopupMenuItem(
                            value: 'cancelled',
                            child: Text('Abbrechen'),
                          ),
                      ],
                    );
                  }
                  return null;
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: crisisAsync.when(
        loading: () => const LoadingSkeleton(type: SkeletonType.card),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (crisis) {
          if (crisis == null) {
            return const EmptyState(
              icon: Icons.warning_outlined,
              title: 'Nicht gefunden',
              message: 'Diese Krisenmeldung existiert nicht.',
            );
          }
          return _buildContent(
            context,
            crisis,
            helpersAsync,
            updatesAsync,
            currentUserId,
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Crisis crisis,
    AsyncValue<List<CrisisHelper>> helpersAsync,
    AsyncValue<List<CrisisUpdate>> updatesAsync,
    String? currentUserId,
  ) {
    final urgency = crisis.urgency;
    final urgencyCol = _urgencyColor(urgency);
    final statusCol = _statusColor(crisis.crisisStatus);
    final isCreator = currentUserId == crisis.reporterId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Urgency + Status + Verified row
        Row(
          children: [
            AppBadge(label: urgency.label, color: urgencyCol),
            const SizedBox(width: 8),
            AppBadge(label: crisis.crisisStatus.label, color: statusCol),
            if (crisis.verified) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 14, color: AppColors.info),
                    SizedBox(width: 4),
                    Text(
                      'Verifiziert',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Category + Title
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              crisis.crisisCategory.emoji,
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crisis.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    crisis.crisisCategory.label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Description
        if (crisis.description != null &&
            crisis.description!.isNotEmpty) ...[
          Text(
            crisis.description!,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Location
        if (crisis.address != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: AppColors.primary500),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crisis.address!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (crisis.city != null)
                        Text(
                          crisis.city!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Contact phone
        if (crisis.contactPhone != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.emergencyLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.emergency.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone, color: AppColors.emergency),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kontakttelefon',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        crisis.contactPhone!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Reporter + created date
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              AvatarWidget(
                imageUrl: crisis.isAnonymous
                    ? null
                    : crisis.reporterProfile?['avatar_url'] as String?,
                name: crisis.isAnonymous
                    ? 'Anonym'
                    : (crisis.reporterProfile?['nickname'] as String? ??
                        crisis.reporterProfile?['name'] as String? ??
                        'Unbekannt'),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crisis.isAnonymous
                          ? 'Anonymer Melder'
                          : (crisis.reporterProfile?['nickname']
                                  as String? ??
                              crisis.reporterProfile?['name'] as String? ??
                              'Unbekannt'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Gemeldet ${timeago.format(crisis.createdAt, locale: 'de')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Helper count bar
        _buildHelperProgress(crisis),
        const SizedBox(height: 20),

        const Divider(),
        const SizedBox(height: 12),

        // Helpers list
        helpersAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('Fehler beim Laden der Helfer: $e'),
          data: (helpers) => _buildHelpersSection(helpers, currentUserId),
        ),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),

        // Timeline / Updates
        updatesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('Fehler beim Laden der Updates: $e'),
          data: (updates) =>
              _buildUpdatesTimeline(updates, isCreator, currentUserId),
        ),

        const SizedBox(height: 24),

        // Offer help button
        if (crisis.crisisStatus != CrisisStatus.resolved &&
            crisis.crisisStatus != CrisisStatus.cancelled &&
            !isCreator) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () => _offerHelp(currentUserId),
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Hilfe anbieten'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],

        // Resolved info
        if (crisis.crisisStatus == CrisisStatus.resolved &&
            crisis.resolvedAt != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Krise gelöst',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        'Gelöst ${timeago.format(crisis.resolvedAt!, locale: 'de')}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHelperProgress(Crisis crisis) {
    final current = crisis.helperCount ?? 0;
    // If needed_helpers is not in the model, we use a sensible default
    final needed = 5;
    final progress = needed > 0 ? (current / needed).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline,
                  color: AppColors.primary500, size: 20),
              const SizedBox(width: 8),
              Text(
                '$current Helfer',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$current/$needed Helfer',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.primary500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpersSection(
      List<CrisisHelper> helpers, String? currentUserId) {
    final hasOffered = helpers.any((h) => h.userId == currentUserId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Helfer (${helpers.length})',
          icon: Icons.people_outline,
        ),
        if (helpers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Noch keine Helfer. Sei der Erste!',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...helpers.map((helper) => _buildHelperTile(helper)),
        if (hasOffered)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    color: AppColors.success, size: 16),
                SizedBox(width: 6),
                Text(
                  'Du hast bereits Hilfe angeboten',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHelperTile(CrisisHelper helper) {
    final name = helper.profile?['nickname'] as String? ??
        helper.profile?['name'] as String? ??
        'Unbekannt';
    final avatarUrl = helper.profile?['avatar_url'] as String?;
    final statusLabel = _helperStatusLabel(helper.status);
    final statusColor = _helperStatusColor(helper.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            AvatarWidget(imageUrl: avatarUrl, name: name, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (helper.message != null &&
                      helper.message!.isNotEmpty)
                    Text(
                      helper.message!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (helper.skills.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        children: helper.skills
                            .take(3)
                            .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primary700,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            AppBadge(
              label: statusLabel,
              color: statusColor,
              small: true,
            ),
          ],
        ),
      ),
    );
  }

  String _helperStatusLabel(String status) {
    switch (status) {
      case 'offered':
        return 'Angeboten';
      case 'accepted':
        return 'Akzeptiert';
      case 'active':
        return 'Aktiv';
      case 'completed':
        return 'Erledigt';
      case 'declined':
        return 'Abgelehnt';
      default:
        return status;
    }
  }

  Color _helperStatusColor(String status) {
    switch (status) {
      case 'offered':
        return AppColors.warning;
      case 'accepted':
        return AppColors.info;
      case 'active':
        return AppColors.primary500;
      case 'completed':
        return AppColors.success;
      case 'declined':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  Widget _buildUpdatesTimeline(
    List<CrisisUpdate> updates,
    bool isCreator,
    String? currentUserId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Verlauf (${updates.length})',
          icon: Icons.timeline,
          actionLabel: isCreator ? 'Update posten' : null,
          onAction: isCreator
              ? () => setState(() => _showUpdateForm = !_showUpdateForm)
              : null,
        ),

        // Update form for creator
        if (_showUpdateForm && isCreator) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary500),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _updateController,
                  decoration: const InputDecoration(
                    hintText: 'Status-Update schreiben...',
                    border: InputBorder.none,
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _showUpdateForm = false);
                        _updateController.clear();
                      },
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _postUpdate(currentUserId),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Posten'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        if (updates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Noch keine Updates vorhanden.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...updates
              .asMap()
              .entries
              .map((entry) => _buildTimelineItem(
                    entry.value,
                    isLast: entry.key == updates.length - 1,
                  )),
      ],
    );
  }

  Widget _buildTimelineItem(CrisisUpdate update, {bool isLast = false}) {
    final authorName = update.profile?['nickname'] as String? ??
        update.profile?['name'] as String? ??
        'Unbekannt';
    final avatarUrl = update.profile?['avatar_url'] as String?;
    final icon = _updateTypeIcon(update.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary500, width: 2),
                  ),
                  child: Icon(icon,
                      size: 14, color: AppColors.primary500),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarWidget(
                          imageUrl: avatarUrl,
                          name: authorName,
                          size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        timeago.format(update.createdAt, locale: 'de'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    update.content,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _offerHelp(String? userId) async {
    if (userId == null) return;

    final messageController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hilfe anbieten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Beschreibe kurz, wie du helfen kannst (optional):',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                hintText: 'z.B. Ich bin Ersthelfer...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, messageController.text),
            child: const Text('Hilfe anbieten'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(crisisServiceProvider).offerHelp(
            crisisId: widget.crisisId,
            userId: userId,
            message: result.isNotEmpty ? result : null,
          );
      ref.invalidate(crisisHelpersProvider(widget.crisisId));
      ref.invalidate(crisisDetailProvider(widget.crisisId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hilfe angeboten! Danke!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _postUpdate(String? userId) async {
    final content = _updateController.text.trim();
    if (content.isEmpty || userId == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(crisisServiceProvider).addUpdate(
            crisisId: widget.crisisId,
            userId: userId,
            type: 'info',
            content: content,
          );
      _updateController.clear();
      setState(() => _showUpdateForm = false);
      ref.invalidate(crisisUpdatesProvider(widget.crisisId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update gepostet')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleStatusChange(String newStatus) async {
    try {
      await ref
          .read(crisisServiceProvider)
          .updateCrisisStatus(widget.crisisId, newStatus);
      ref.invalidate(crisisDetailProvider(widget.crisisId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status aktualisiert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }
}
