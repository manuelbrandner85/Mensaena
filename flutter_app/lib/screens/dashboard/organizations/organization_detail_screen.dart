import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class OrganizationDetailScreen extends ConsumerWidget {
  const OrganizationDetailScreen({required this.orgId, super.key});
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(organizationDetailProvider(orgId));
    return DashboardScaffold(
      title: 'modules.organization'.tr(),
      currentRoute: '/dashboard/organizations',
      body: SafeArea(
        child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
          error: (e, _) =>
              Center(child: Text('$e', style: AppTypography.caption())),
          data: (o) {
            if (o == null) {
              return Center(
                child: Text('organizations.notFound'.tr(),
                    style: AppTypography.caption()),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.name,
                        style: AppTypography.display(
                          size: 26,
                          color: AppColors.ink,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (o.isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(LucideIcons.badgeCheck,
                            color: AppColors.amber),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(o.category, style: AppTypography.label(size: 10)),
                if (o.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    o.description!,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.inkSoft,
                      height: 1.55,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _ContactRow(
                  icon: LucideIcons.mapPin,
                  label: [o.address, o.zipCode, o.city]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(', '),
                ),
                if (o.phone != null && o.phone!.isNotEmpty)
                  _ContactRow(
                    icon: LucideIcons.phone,
                    label: o.phone!,
                    onTap: () => launchUrl(Uri.parse('tel:${o.phone}')),
                  ),
                if (o.email != null && o.email!.isNotEmpty)
                  _ContactRow(
                    icon: LucideIcons.mail,
                    label: o.email!,
                    onTap: () =>
                        launchUrl(Uri.parse('mailto:${o.email}')),
                  ),
                if (o.website != null && o.website!.isNotEmpty)
                  _ContactRow(
                    icon: LucideIcons.globe,
                    label: o.website!,
                    onTap: () => launchUrl(
                      Uri.parse(o.website!),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                if (o.openingHours != null && o.openingHours!.isNotEmpty)
                  _ContactRow(icon: LucideIcons.clock, label: o.openingHours!),
                if (o.services.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('organizations.offers'.tr(), style: AppTypography.label(size: 10)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: o.services
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.elevated,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                s,
                                style: AppTypography.body(
                                  size: 11,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final row = Row(
      children: [
        Icon(icon, size: 14, color: AppColors.amber),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.body(
              size: 13,
              color: onTap != null ? AppColors.amber : AppColors.ink,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: row,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: row),
    );
  }
}
