/// SKILL: mensaena-features + mensaena-design
/// ContactRequestsScreen (Schritt 11): Übersicht aller eingehenden Anfragen
/// gruppiert nach Post.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post_contact_request.dart';
import '../../providers/post_contact_provider.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/post/contact_requests_manager.dart';

class ContactRequestsScreen extends ConsumerWidget {
  const ContactRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myIncomingContactRequestsProvider);
    return DashboardScaffold(
      title: 'contact.requests.title'.tr(),
      currentRoute: '/contact-requests',
      onRefresh: () async {
        ref.invalidate(myIncomingContactRequestsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.bronze),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.inbox,
                        size: 32, color: AppColors.mute),
                    const SizedBox(height: 8),
                    Text('contact.requests.empty'.tr(),
                        style: AppTypography.caption()),
                  ],
                ),
              ),
            );
          }
          // Gruppieren nach post_id
          final groups = <String, List<PostContactRequest>>{};
          for (final r in list) {
            groups.putIfAbsent(r.postId, () => []).add(r);
          }
          final keys = groups.keys.toList();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            itemCount: keys.length,
            itemBuilder: (_, i) {
              final pid = keys[i];
              final group = groups[pid]!;
              final title = group.first.postTitle ?? '—';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => ContactRequestsManager.show(context, pid),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                AppColors.bronze.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${group.length}',
                              style: AppTypography.display(
                                  size: 16,
                                  color: AppColors.bronze)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(title,
                              style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.ink,
                                  weight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const Icon(LucideIcons.chevronRight,
                            size: 16, color: AppColors.mute),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
