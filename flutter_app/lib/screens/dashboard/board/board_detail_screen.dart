import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/board_post.dart';
import '../../../repositories/board_repository.dart';
import '../../../repositories/content_reports_repository.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/share_service.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/safe_launch.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/error_state_widget.dart';
import '../../../widgets/shared/app_snackbar.dart';

class BoardDetailScreen extends ConsumerStatefulWidget {
  const BoardDetailScreen({required this.boardPostId, super.key});
  final String boardPostId;

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final ok = await BoardRepository.addComment(
      boardPostId: widget.boardPostId,
      content: text,
    );
    if (!ok || !mounted) return;
    _commentCtrl.clear();
    ref.invalidate(boardCommentsProvider(widget.boardPostId));
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(boardPostDetailProvider(widget.boardPostId));
    final comments = ref.watch(boardCommentsProvider(widget.boardPostId));
    final pinned = ref.watch(boardIsPinnedProvider(widget.boardPostId));

    return DashboardScaffold(
      title: 'board.title'.tr(),
      currentRoute: '/dashboard/board',
      body: SafeArea(
        child: post.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
          error: (e, _) => Center(
            child: ErrorStateWidget(
              onRetry: () =>
                  ref.invalidate(boardPostDetailProvider(widget.boardPostId)),
            ),
          ),
          data: (p) {
            if (p == null) {
              return Center(
                child: Text('board.notFound'.tr(),
                    style: AppTypography.caption()),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              p.category.toUpperCase(),
                              style: AppTypography.label(size: 9),
                            ),
                          ),
                          const Spacer(),
                          if (p.authorId ==
                              SupabaseService.currentUser?.id) ...[
                            IconButton(
                              tooltip: 'common.edit'.tr(),
                              icon: const Icon(LucideIcons.pencil,
                                  size: 16, color: AppColors.amber),
                              onPressed: () => _openEditModal(context, p),
                            ),
                            IconButton(
                              tooltip: 'common.delete'.tr(),
                              icon: const Icon(LucideIcons.trash2,
                                  size: 16, color: AppColors.herzrot),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    backgroundColor: AppColors.surface,
                                    title: Text('board.deletePinTitle'.tr(),
                                        style: AppTypography.display(
                                            size: 18,
                                            color: AppColors.ink)),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(
                                              context, false),
                                          child: Text('common.cancel'.tr())),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppColors.herzrot),
                                        onPressed: () => Navigator.pop(
                                            context, true),
                                        child: Text('common.delete'.tr()),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                                final deleted =
                                    await BoardRepository.delete(p.id);
                                if (!context.mounted) return;
                                if (deleted) {
                                  ref.invalidate(boardPostsProvider);
                                  context.go('/dashboard/board');
                                }
                              },
                            ),
                          ],
                          IconButton(
                            tooltip: 'common.share'.tr(),
                            icon: const Icon(LucideIcons.share2,
                                size: 16, color: AppColors.bronze),
                            onPressed: () => ShareService.share(
                              type: ShareableType.board,
                              id: p.id,
                              titleOrText: p.content,
                            ),
                          ),
                          // Melden — nur bei fremden Pinnwand-Einträgen
                          // (Betrugs-/Spam-Schutz; bisher fehlte die Aktion).
                          if (p.authorId != SupabaseService.currentUser?.id)
                            IconButton(
                              tooltip: 'marketplace.report'.tr(),
                              icon: const Icon(LucideIcons.flag,
                                  size: 16, color: AppColors.mute),
                              onPressed: () => _reportPost(p.id),
                            ),
                          IconButton(
                            tooltip: 'common.pin'.tr(),
                            icon: Icon(
                              LucideIcons.pin,
                              size: 18,
                              color: pinned.asData?.value == true
                                  ? AppColors.amber
                                  : AppColors.mute,
                            ),
                            onPressed: () async {
                              await BoardRepository.togglePin(p.id);
                              ref.invalidate(
                                  boardIsPinnedProvider(widget.boardPostId));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (p.imageUrl != null && p.imageUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: p.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        p.content,
                        style: AppTypography.body(
                          size: 16,
                          color: AppColors.ink,
                          height: 1.55,
                        ),
                      ),
                      if (p.contactInfo != null && p.contactInfo!.isNotEmpty)
                        _ContactRow(info: p.contactInfo!),
                      const SizedBox(height: 14),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(p.createdAt),
                        style: AppTypography.caption(),
                      ),
                      if (p.expiresAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(LucideIcons.calendarClock,
                                size: 12, color: AppColors.mute),
                            const SizedBox(width: 6),
                            Text(
                              'board.expiresOn'.tr(namedArgs: {
                                'date': DateFormat('dd.MM.yyyy')
                                    .format(p.expiresAt!)
                              }),
                              style: AppTypography.caption(),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text('board.comments'.tr(), style: AppTypography.label(size: 10)),
                      const SizedBox(height: 8),
                      comments.when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) =>
                            Text('$e', style: AppTypography.caption()),
                        data: (list) {
                          if (list.isEmpty) {
                            return Text(
                              'board.noComments'.tr(),
                              style: AppTypography.caption(),
                            );
                          }
                          return Column(
                            children: list.map((c) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withValues(alpha: 0.4),
                                  border: Border.all(color: AppColors.line),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.content,
                                      style: AppTypography.body(
                                        size: 13,
                                        color: AppColors.inkSoft,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('dd.MM. HH:mm')
                                          .format(c.createdAt),
                                      style: AppTypography.caption(),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.deep,
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          style: AppTypography.body(
                              size: 14, color: AppColors.ink),
                          decoration: InputDecoration(
                            hintText: 'board.commentHint'.tr(),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'common.send'.tr(),
                        onPressed: _submitComment,
                        icon: const Icon(LucideIcons.send,
                            color: AppColors.amber),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEditModal(BuildContext ctx, BoardPost post) async {
    final contentCtrl = TextEditingController(text: post.content);
    final contactInfoCtrl =
        TextEditingController(text: post.contactInfo ?? '');
    String category = post.category;
    String color = post.color;
    DateTime? modalExpiresAt = post.expiresAt;
    File? newImage;
    String? existingImageUrl = post.imageUrl;
    bool saving = false;

    Future<void> pickImage(StateSetter setLocal) async {
      final picker = ImagePicker();
      final result = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 80,
      );
      if (result == null) return;
      setLocal(() {
        newImage = File(result.path);
        existingImageUrl = null;
      });
    }

    Future<void> pickExpiry(StateSetter setLocal) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: ctx,
        initialDate: modalExpiresAt ?? now.add(const Duration(days: 7)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (picked != null) setLocal(() => modalExpiresAt = picked);
    }

    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setLocal) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20, 16, 20,
            16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('board.editPin'.tr(),
                  style: AppTypography.display(
                      size: 20, color: AppColors.ink)),
              const SizedBox(height: 14),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                minLines: 3,
                style:
                    AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.elevated,
                  hintText: 'board.contentHint'.tr(),
                  hintStyle: AppTypography.body(
                      size: 13, color: AppColors.mute),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactInfoCtrl,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.elevated,
                  labelText: 'create.contactOptional'.tr(),
                  hintText: 'create.pinContactHint'.tr(),
                  hintStyle: AppTypography.body(
                      size: 13, color: AppColors.mute),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('board.category'.tr(), style: AppTypography.label(size: 10)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final c in const [
                    'general', 'gesucht', 'biete', 'event',
                    'info', 'warnung', 'verloren', 'fundbuero',
                  ])
                    ChoiceChip(
                      label: Text(c, style: AppTypography.label(size: 9)),
                      selected: category == c,
                      onSelected: (_) =>
                          setLocal(() => category = c),
                      selectedColor: AppColors.amber.withValues(alpha: 0.3),
                      backgroundColor: AppColors.elevated,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('board.color'.tr(), style: AppTypography.label(size: 10)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in const [
                    'yellow', 'green', 'blue', 'pink', 'orange', 'purple'
                  ])
                    GestureDetector(
                      onTap: () => setLocal(() => color = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _colorFor(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == c
                                ? AppColors.amber
                                : AppColors.line,
                            width: color == c ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Bild
              Text('board.image'.tr(), style: AppTypography.label(size: 10)),
              const SizedBox(height: 8),
              if (newImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(newImage!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: GestureDetector(
                        onTap: () => setLocal(() => newImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xCC000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.x,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              else if (existingImageUrl != null &&
                  existingImageUrl!.isNotEmpty)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        existingImageUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: GestureDetector(
                        onTap: () =>
                            setLocal(() => existingImageUrl = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xCC000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.x,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              else
                GestureDetector(
                  onTap: () => pickImage(setLocal),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.camera,
                            color: AppColors.bronze, size: 18),
                        const SizedBox(width: 8),
                        Text('board.addImage'.tr(),
                            style: AppTypography.caption()),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              // Ablaufdatum
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => pickExpiry(setLocal),
                      icon: const Icon(LucideIcons.calendarClock,
                          size: 16),
                      label: Text(
                        modalExpiresAt == null
                            ? 'board.setExpiry'.tr()
                            : 'board.expiresOn'.tr(namedArgs: {
                                'date':
                                    '${modalExpiresAt!.day}.${modalExpiresAt!.month}.${modalExpiresAt!.year}'
                              }),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.inkSoft,
                        side: const BorderSide(color: AppColors.line),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (modalExpiresAt != null)
                    IconButton(
                      onPressed: () =>
                          setLocal(() => modalExpiresAt = null),
                      icon: const Icon(LucideIcons.x, size: 16),
                      color: AppColors.mute,
                      tooltip: 'board.noExpiry'.tr(),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.voidColor,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        setLocal(() => saving = true);
                        String? uploadedUrl;
                        if (newImage != null) {
                          final urls = await ImageUploadService.upload(
                              [newImage!]);
                          if (urls.isEmpty) {
                            setLocal(() => saving = false);
                            return;
                          }
                          uploadedUrl = urls.first;
                        }
                        final hadImage = post.imageUrl != null &&
                            post.imageUrl!.isNotEmpty;
                        final imageRemoved =
                            hadImage && existingImageUrl == null &&
                                newImage == null;
                        final ok = await BoardRepository.update(
                          id: post.id,
                          content: contentCtrl.text.trim(),
                          category: category,
                          color: color,
                          contactInfo: contactInfoCtrl.text.trim(),
                          expiresAt: modalExpiresAt,
                          clearExpiresAt: post.expiresAt != null &&
                              modalExpiresAt == null,
                          imageUrl: uploadedUrl,
                          clearImageUrl: imageRemoved,
                        );
                        if (!sheetCtx.mounted) return;
                        Navigator.pop(sheetCtx);
                        if (ok) {
                          ref.invalidate(boardPostDetailProvider(post.id));
                          ref.invalidate(boardPostsProvider);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.voidColor,
                        ),
                      )
                    : Text('common.save'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
    contentCtrl.dispose();
    contactInfoCtrl.dispose();
  }

  Color _colorFor(String c) {
    switch (c) {
      case 'green':
        return const Color(0xFFBBF7D0);
      case 'blue':
        return const Color(0xFFBFDBFE);
      case 'pink':
        return const Color(0xFFFBCFE8);
      case 'orange':
        return const Color(0xFFFED7AA);
      case 'purple':
        return const Color(0xFFE9D5FF);
      default:
        return const Color(0xFFFEF08A);
    }
  }

  /// Meldet einen Pinnwand-Eintrag zur Moderation. Grund-Auswahl per Sheet,
  /// dann INSERT in reports (content_type='board'). Parität zum Marktplatz.
  Future<void> _reportPost(String postId) async {
    const reasons = <String, String>{
      'fraud': 'report.reasonFraud',
      'spam': 'report.reasonSpam',
      'false_info': 'report.reasonFalseInfo',
      'danger': 'report.reasonDanger',
      'other': 'report.reasonOther',
    };
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('marketplace.reportTitle'.tr(),
                  style: AppTypography.display(size: 17, color: AppColors.ink)),
            ),
            for (final e in reasons.entries)
              ListTile(
                leading: const Icon(LucideIcons.flag,
                    size: 16, color: AppColors.mute),
                title: Text(e.value.tr(),
                    style: AppTypography.body(size: 14, color: AppColors.ink)),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    final ok = await ContentReportsRepository.report(
      contentType: 'board',
      contentId: postId,
      reason: reason,
    );
    if (!mounted) return;
    AppSnackBar.info(context, ok ? 'report.thanks'.tr() : 'common.errorGeneric'.tr());
  }
}

/// Klickbare Kontakt-Zeile: erkennt E-Mail/Telefon im Freitext und öffnet
/// das passende System-Intent (mailto:/tel:). Vorher reiner Text → User
/// musste die Nummer/E-Mail abtippen.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.info});
  final String info;

  static final _emailRe = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
  static final _phoneRe = RegExp(r'(\+?\d[\d\s\-/()]{6,}\d)');

  ({IconData icon, String? launchUrl}) _detect() {
    final email = _emailRe.firstMatch(info)?.group(0);
    if (email != null) return (icon: LucideIcons.mail, launchUrl: 'mailto:$email');
    final phone = _phoneRe.firstMatch(info)?.group(0)?.replaceAll(RegExp(r'[\s\-/()]'), '');
    if (phone != null && phone.length >= 6) {
      return (icon: LucideIcons.phone, launchUrl: 'tel:$phone');
    }
    return (icon: LucideIcons.phone, launchUrl: null);
  }

  @override
  Widget build(BuildContext context) {
    final d = _detect();
    final tap = d.launchUrl == null
        ? null
        : () => safeLaunch(d.launchUrl!, context: context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(d.icon, size: 14, color: AppColors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(info,
                    style: AppTypography.mono(
                        size: 13, color: AppColors.amber)),
              ),
              if (tap != null)
                const Icon(LucideIcons.externalLink,
                    size: 12, color: AppColors.mute),
            ],
          ),
        ),
      ),
    );
  }
}
