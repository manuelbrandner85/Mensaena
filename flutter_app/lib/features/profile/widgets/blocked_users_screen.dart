import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/atmosphere/cinema_scaffold.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/cinema_appbar.dart';
import '../../../core/widgets/cinema_avatar.dart';
import '../../../core/widgets/cinema_empty_state.dart';
import '../../../core/widgets/cinema_loading_skeleton.dart';
import '../../../core/widgets/cinema_toast.dart';
import '../../../core/widgets/glow_button.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/supabase/database_service.dart';

/// Liste der blockierten Nutzer:innen. Erlaubt Entsperren pro Eintrag.
final blockedUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return const [];
  return db.listBlockedUsers(me.id);
});

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedUsersProvider);
    return CinemaScaffold(
      level: AtmosphereLevel.focus,
      appBar: const CinemaAppBar(title: 'BLOCKIERTE NUTZER'),
      body: SafeArea(
        child: async.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(
            child: Text('$e', style: MnTypography.body(color: MnColors.herzrot)),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const Center(
                child: CinemaEmptyState(
                  icon: LucideIcons.userX,
                  title: 'Niemand blockiert',
                  message:
                      'Wenn du jemanden blockierst, kann diese Person dich nicht mehr kontaktieren.',
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(blockedUsersProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _BlockedRow(block: rows[i], onChanged: () {
                  ref.invalidate(blockedUsersProvider);
                },),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BlockedRow extends ConsumerStatefulWidget {
  final Map<String, dynamic> block;
  final VoidCallback onChanged;
  const _BlockedRow({required this.block, required this.onChanged});

  @override
  ConsumerState<_BlockedRow> createState() => _BlockedRowState();
}

class _BlockedRowState extends ConsumerState<_BlockedRow> {
  bool _busy = false;

  Future<void> _unblock() async {
    setState(() => _busy = true);
    try {
      await db.unblockUser(widget.block['id'] as String);
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.success,
        message: 'Entsperrt.',
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: 'Fehler: $e',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = (widget.block['blocked'] as Map<String, dynamic>?) ?? const {};
    final name = (profile['name'] as String?) ?? 'Unbekannt';
    final avatar = profile['avatar_url'] as String?;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MnColors.elevated,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Row(
        children: [
          CinemaAvatar(
            imageUrl: avatar,
            displayName: name,
            size: AvatarSize.sm,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: MnTypography.body(
                color: MnColors.ink,
                weight: FontWeight.w600,
              ),
            ),
          ),
          GlowButton(
            label: _busy ? '...' : 'Entsperren',
            variant: GlowVariant.ghost,
            compact: true,
            onPressed: _busy ? null : _unblock,
          ),
        ],
      ),
    );
  }
}
