import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/board_repository.dart';
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
}
