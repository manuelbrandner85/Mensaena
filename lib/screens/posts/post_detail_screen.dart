import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/interaction_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/badge_widget.dart';
import 'package:mensaena/widgets/trust_score_badge.dart';
import 'package:mensaena/widgets/section_header.dart';
import 'package:mensaena/models/post.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  bool _isSaved = false;
  bool _isSavedLoading = true;
  int _userVote = 0; // -1, 0, 1
  int _voteScore = 0;
  bool _isVoting = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkSavedState();
  }

  Future<void> _checkSavedState() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _isSavedLoading = false);
      return;
    }
    try {
      final saved = await ref
          .read(postServiceProvider)
          .isPostSaved(widget.postId, userId);
      if (mounted) {
        setState(() {
          _isSaved = saved;
          _isSavedLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSavedLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beitrag'),
        actions: [
          if (!_isSavedLoading)
            IconButton(
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_outline,
                color: _isSaved ? AppColors.primary500 : null,
              ),
              onPressed: () => _toggleSave(userId),
              tooltip: _isSaved ? 'Lesezeichen entfernen' : 'Lesezeichen setzen',
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(),
            tooltip: 'Teilen',
          ),
        ],
      ),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (post) {
          if (post == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text(
                    'Beitrag nicht gefunden',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }
          // Initialize vote score from post data
          if (_voteScore == 0 && post.voteScore != null) {
            _voteScore = post.voteScore!;
          }
          return _buildDetail(context, post, userId);
        },
      ),
    );
  }

  Widget _buildDetail(BuildContext context, Post post, String? userId) {
    final isOwner = userId == post.userId;
    final postType = post.postType;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Images with page indicator
          if (post.allImages.isNotEmpty) _buildImageCarousel(post),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Badge + Status
                Row(
                  children: [
                    AppBadge(
                      label: '${postType.emoji} ${postType.label}',
                      color: AppColors.primary500,
                    ),
                    const SizedBox(width: 8),
                    if (post.status != 'active')
                      AppBadge(
                        label: _statusLabel(post.status),
                        color: _statusColor(post.status),
                      ),
                    if (post.urgency != null) ...[
                      const SizedBox(width: 8),
                      AppBadge(
                        label: _urgencyLabel(post.urgency!),
                        color: _urgencyColor(post.urgency!),
                        small: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),

                // Author row
                GestureDetector(
                  onTap: () =>
                      context.push('/dashboard/profile/${post.userId}'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        AvatarWidget(
                          imageUrl: post.authorAvatarUrl,
                          name: post.authorName,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      size: 12,
                                      color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeago.format(post.createdAt,
                                        locale: 'de'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (post.profile != null)
                          TrustScoreBadge(
                            score: (post.profile!['trust_score'] as num?)
                                    ?.toDouble() ??
                                0,
                            size: TrustBadgeSize.small,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Vote buttons
                _buildVoteSection(post, userId),
                const SizedBox(height: 16),

                const Divider(),
                const SizedBox(height: 16),

                // Description
                if (post.description != null &&
                    post.description!.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'Beschreibung',
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.description!,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Location
                if (post.locationText != null) ...[
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
                          child: Text(
                            post.locationText!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Event date / time
                if (post.eventDate != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: AppColors.primary500, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          post.eventDate!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (post.eventTime != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time,
                              color: AppColors.primary500, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            post.eventTime!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (post.durationHours != null) ...[
                          const Spacer(),
                          Text(
                            '${post.durationHours!.toStringAsFixed(post.durationHours! == post.durationHours!.roundToDouble() ? 0 : 1)} Std.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Tags
                if (post.tags.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'Tags',
                    icon: Icons.label_outline,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: post.tags
                        .map((tag) => Chip(
                              label: Text(
                                '#$tag',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary700,
                                ),
                              ),
                              backgroundColor: AppColors.primary50,
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Contact Section - for non-owners
                if (!isOwner && post.status == 'active') ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  const SectionHeader(
                    title: 'Kontakt aufnehmen',
                    icon: Icons.connect_without_contact,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _offerHelp(context, post, userId),
                          icon: const Icon(
                              Icons.volunteer_activism, size: 18),
                          label: const Text('Hilfe anbieten'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary500,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (userId == null) return;
                            context.push('/dashboard/messages');
                          },
                          icon: const Icon(
                              Icons.chat_bubble_outline, size: 18),
                          label: const Text('Nachricht'),
                        ),
                      ),
                      if (post.contactPhone != null) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.phone_outlined,
                              size: 18),
                          label: const Text('Anrufen'),
                        ),
                      ],
                    ],
                  ),
                ],

                // Owner Actions
                if (isOwner) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  const SectionHeader(
                    title: 'Beitrag verwalten',
                    icon: Icons.settings_outlined,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (post.status == 'active')
                        OutlinedButton.icon(
                          onPressed: () =>
                              _updateStatus(post.id, 'fulfilled'),
                          icon: const Icon(
                              Icons.check_circle_outline, size: 18),
                          label: const Text('Erledigt'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.success,
                            side: const BorderSide(
                                color: AppColors.success),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _updateStatus(post.id, 'archived'),
                        icon: const Icon(Icons.archive_outlined,
                            size: 18),
                        label: const Text('Archivieren'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _deletePost(post.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                              color: AppColors.error),
                        ),
                        icon: const Icon(Icons.delete_outline,
                            size: 18),
                        label: const Text('Löschen'),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(Post post) {
    final images = post.allImages;
    return Stack(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: images[i],
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(
                color: AppColors.border,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.border,
                child: const Center(
                  child: Icon(Icons.broken_image,
                      size: 48, color: AppColors.textMuted),
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => Container(
                  width: i == _currentImageIndex ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == _currentImageIndex
                        ? AppColors.primary500
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        // Image counter badge
        if (images.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVoteSection(Post post, String? userId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Upvote
          IconButton(
            onPressed: _isVoting
                ? null
                : () => _vote(post.id, userId, 1),
            icon: Icon(
              _userVote == 1
                  ? Icons.thumb_up
                  : Icons.thumb_up_outlined,
              color: _userVote == 1
                  ? AppColors.primary500
                  : AppColors.textMuted,
              size: 22,
            ),
            tooltip: 'Hilfreich',
          ),
          Text(
            '$_voteScore',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _voteScore > 0
                  ? AppColors.primary500
                  : _voteScore < 0
                      ? AppColors.error
                      : AppColors.textSecondary,
            ),
          ),
          // Downvote
          IconButton(
            onPressed: _isVoting
                ? null
                : () => _vote(post.id, userId, -1),
            icon: Icon(
              _userVote == -1
                  ? Icons.thumb_down
                  : Icons.thumb_down_outlined,
              color: _userVote == -1
                  ? AppColors.error
                  : AppColors.textMuted,
              size: 22,
            ),
            tooltip: 'Nicht hilfreich',
          ),
          const Spacer(),
          // Comment count (if available)
          if (post.commentCount != null) ...[
            const Icon(Icons.comment_outlined,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              '${post.commentCount}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 16),
          ],
          // Share
          IconButton(
            onPressed: _share,
            icon: const Icon(Icons.share_outlined,
                size: 20, color: AppColors.textMuted),
            tooltip: 'Teilen',
          ),
        ],
      ),
    );
  }

  Future<void> _vote(
      String postId, String? userId, int voteValue) async {
    if (userId == null) return;

    setState(() => _isVoting = true);
    try {
      if (_userVote == voteValue) {
        // Remove vote
        await ref.read(postServiceProvider).removeVote(postId, userId);
        setState(() {
          _voteScore -= voteValue;
          _userVote = 0;
        });
      } else {
        // Apply vote
        await ref
            .read(postServiceProvider)
            .vote(postId, userId, voteValue);
        setState(() {
          _voteScore -= _userVote; // Remove old vote
          _voteScore += voteValue; // Add new vote
          _userVote = voteValue;
        });
      }
    } catch (_) {
      // Silently fail
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Future<void> _offerHelp(
      BuildContext context, Post post, String? userId) async {
    if (userId == null) return;

    final messageController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hilfe anbieten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Du möchtest bei "${post.title}" helfen?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                hintText: 'Kurze Nachricht (optional)...',
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

    try {
      await ref.read(interactionServiceProvider).createInteraction(
            postId: post.id,
            helperId: userId,
            message: result.isNotEmpty ? result : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hilfe angeboten! Der Ersteller wird benachrichtigt.'),
          ),
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

  Future<void> _toggleSave(String? userId) async {
    if (userId == null) return;
    final service = ref.read(postServiceProvider);
    try {
      if (_isSaved) {
        await service.unsavePost(widget.postId, userId);
      } else {
        await service.savePost(widget.postId, userId);
      }
      setState(() => _isSaved = !_isSaved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isSaved ? 'Lesezeichen gesetzt' : 'Lesezeichen entfernt'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {}
  }

  void _share() {
    Share.share(
        'Schau dir diesen Beitrag auf Mensaena an! https://mensaena.de');
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktiv';
      case 'fulfilled':
        return 'Erledigt';
      case 'archived':
        return 'Archiviert';
      case 'pending':
        return 'Ausstehend';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'fulfilled':
        return AppColors.info;
      case 'archived':
        return AppColors.textMuted;
      case 'pending':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  String _urgencyLabel(String urgency) {
    switch (urgency) {
      case 'critical':
        return 'Kritisch';
      case 'high':
        return 'Hoch';
      case 'medium':
        return 'Mittel';
      case 'low':
        return 'Niedrig';
      default:
        return urgency;
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'critical':
        return AppColors.emergency;
      case 'high':
        return Colors.orange;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  Future<void> _updateStatus(String postId, String status) async {
    try {
      await ref.read(postServiceProvider).updateStatus(postId, status);
      ref.invalidate(postDetailProvider(postId));
      if (mounted) {
        final label = _statusLabel(status);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status auf "$label" geändert')),
        );
      }
    } catch (_) {}
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beitrag löschen?'),
        content: const Text(
            'Dieser Vorgang kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(postServiceProvider).deletePost(postId);
      if (mounted) context.pop();
    }
  }
}
