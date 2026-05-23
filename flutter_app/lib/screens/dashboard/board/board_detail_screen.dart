import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/board_post.dart';
import '../../../repositories/board_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

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
      title: 'Notiz',
      currentRoute: '/dashboard/board',
      body: SafeArea(
        child: post.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
          error: (e, _) => Center(child: Text('$e', style: AppTypography.caption())),
          data: (p) {
            if (p == null) {
              return Center(
                child: Text('Notiz nicht gefunden.',
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
                              tooltip: 'Bearbeiten',
                              icon: const Icon(LucideIcons.pencil,
                                  size: 16, color: AppColors.amber),
                              onPressed: () => _openEditModal(context, p),
                            ),
                            IconButton(
                              tooltip: 'Löschen',
                              icon: const Icon(LucideIcons.trash2,
                                  size: 16, color: AppColors.herzrot),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    backgroundColor: AppColors.surface,
                                    title: Text('Pin löschen?',
                                        style: AppTypography.display(
                                            size: 18,
                                            color: AppColors.ink)),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(
                                              context, false),
                                          child: const Text('Abbrechen')),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppColors.herzrot),
                                        onPressed: () => Navigator.pop(
                                            context, true),
                                        child: const Text('Löschen'),
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
                      Text(
                        p.content,
                        style: AppTypography.body(
                          size: 16,
                          color: AppColors.ink,
                          height: 1.55,
                        ),
                      ),
                      if (p.contactInfo != null && p.contactInfo!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.5),
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.phone,
                                  size: 14, color: AppColors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p.contactInfo!,
                                  style: AppTypography.mono(
                                    size: 13,
                                    color: AppColors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(p.createdAt),
                        style: AppTypography.caption(),
                      ),
                      const SizedBox(height: 20),
                      Text('Kommentare', style: AppTypography.label(size: 10)),
                      const SizedBox(height: 8),
                      comments.when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) =>
                            Text('$e', style: AppTypography.caption()),
                        data: (list) {
                          if (list.isEmpty) {
                            return Text(
                              'Noch keine Kommentare.',
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
                          decoration: const InputDecoration(
                            hintText: 'Kommentar…',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
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
    String category = post.category;
    String color = post.color;
    bool saving = false;
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setLocal) => Padding(
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
              Text('Pin bearbeiten',
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
                  hintText: 'Was möchtest du teilen?',
                  hintStyle: AppTypography.body(
                      size: 13, color: AppColors.mute),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Kategorie', style: AppTypography.label(size: 10)),
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
              Text('Farbe', style: AppTypography.label(size: 10)),
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
                        final ok = await BoardRepository.update(
                          id: post.id,
                          content: contentCtrl.text.trim(),
                          category: category,
                          color: color,
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
                    : const Text('Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
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
}
