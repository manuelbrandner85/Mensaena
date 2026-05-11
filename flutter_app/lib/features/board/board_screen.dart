// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas, unused_import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_sheet.dart';
import '../../core/widgets/glow_button.dart';
import '../../core/widgets/nachbarschaft_card.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase/supabase_service.dart';

final _boardPostsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase.client
      .from('board_posts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);
});

final _pinnedProvider = FutureProvider<Set<String>>((ref) async {
  final res = await supabase.client.from('board_pins').select('post_id');
  return {for (final r in res as List) r['post_id'] as String};
});

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(_boardPostsProvider);
    final pinned = ref.watch(_pinnedProvider).asData?.value ?? const <String>{};

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'SCHWARZES BRETT'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: MnColors.amber,
        foregroundColor: MnColors.voidColor,
        onPressed: () => _showCreate(context, ref),
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: posts.when(
          loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
          error: (e, _) => CinemaEmptyState(
            icon: LucideIcons.alertCircle,
            title: 'Fehler',
            message: e.toString(),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const CinemaEmptyState(
                icon: LucideIcons.fileText,
                title: 'Noch keine Aushaenge.',
                message: 'Sei die*der Erste am schwarzen Brett.',
              );
            }
            final sorted = [...list]..sort((a, b) {
              final aP = pinned.contains(a['id']);
              final bP = pinned.contains(b['id']);
              if (aP != bP) return bP ? 1 : -1;
              return 0;
            });
            return ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (_, i) {
                final p = sorted[i];
                final isPinned = pinned.contains(p['id']);
                return Container(
                  decoration: isPinned
                      ? BoxDecoration(
                          color: MnColors.amber.withValues(alpha: 0.05),
                          border: Border.all(
                            color: MnColors.amber.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                        )
                      : null,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Stack(
                    children: [
                      NachbarschaftCard(
                        timeAgo: (p['created_at'] as String?) ?? '',
                        content: (p['content'] as String?) ?? '',
                        authorName: p['author_name'] as String?,
                      ),
                      if (isPinned)
                        const Positioned(
                          top: 16,
                          right: 28,
                          child: Icon(
                            LucideIcons.pin,
                            color: MnColors.amber,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    CinemaSheet.show<void>(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Neuer Aushang', style: MnTypography.display(size: 22)),
          const SizedBox(height: 16),
          CinemaInput(controller: titleCtrl, label: 'TITEL'),
          const SizedBox(height: 12),
          CinemaInput(
            controller: contentCtrl,
            label: 'INHALT',
            variant: CinemaInputVariant.multiline,
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          GlowButton(
            label: 'Posten',
            variant: GlowVariant.primary,
            fullWidth: true,
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              await supabase.client.from('board_posts').insert({
                'user_id': user.id,
                'title': titleCtrl.text.trim(),
                'content': contentCtrl.text.trim(),
              });
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
