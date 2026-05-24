import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/organization.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../repositories/profiles_repository.dart';
import '../../../services/locale_country_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class OrganizationsScreen extends ConsumerWidget {
  const OrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = LocaleCountryService.forContext(context);
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final radius =
        myProfile?.notificationRadiusKm ?? myProfile?.radiusKm;
    final lat = myProfile?.latitude ?? myProfile?.homeLat;
    final lng = myProfile?.longitude ?? myProfile?.homeLng;
    final args = (
      country: country,
      lat: lat,
      lng: lng,
      radiusKm: radius,
    );
    final async = ref.watch(organizationsForUserProvider(args));
    return DashboardScaffold(
      title: 'organizations.organizationsTitle'.tr(),
      currentRoute: '/dashboard/organizations',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('/dashboard/organizations/suggest'),
        icon: const Icon(LucideIcons.plus),
        label: Text('organizations.suggestOrg'.tr()),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async =>
              ref.invalidate(organizationsForUserProvider(args)),
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
            error: (e, _) => Center(child: Text('$e', style: AppTypography.caption())),
            data: (list) {
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(LucideIcons.building2,
                              size: 32, color: AppColors.mute),
                          const SizedBox(height: 10),
                          Text(
                            'organizations.emptyForRegion'.tr(
                                namedArgs: {'country': country}),
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (context, i) => _OrgTile(org: list[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrgTile extends StatelessWidget {
  const _OrgTile({required this.org});
  final Organization org;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/dashboard/organizations/${org.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.building2,
                  color: AppColors.amber, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          org.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (org.isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(LucideIcons.badgeCheck,
                              size: 14, color: AppColors.amber),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(org.category,
                          style: AppTypography.label(size: 9)),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.mapPin,
                          size: 10, color: AppColors.mute),
                      const SizedBox(width: 3),
                      Text(org.city, style: AppTypography.caption()),
                    ],
                  ),
                  if (org.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      org.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 12,
                        color: AppColors.inkSoft,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
