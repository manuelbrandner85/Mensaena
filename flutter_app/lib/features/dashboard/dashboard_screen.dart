// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/widgets/cinema_app_shell.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../providers/auth_provider.dart';
import 'providers/dashboard_data_provider.dart';
import 'widgets/dashboard_widgets.dart';

/// Dashboard 1:1 zu /src/app/dashboard/page.tsx
///
/// Layout:
///   - Desktop (>=1024px): 2-Col Grid (links 2/3 Content, rechts 1/3 Sidebar)
///   - Mobile/Tablet: Stack (Content + Sidebar untereinander)
///
/// Reihenfolge der Komponenten 1:1 zum Web:
///   Left:  Hero, NinaWarning, FoodWarning, [Onboarding mobile],
///          QuickActions, [UnreadMessages mobile], SmartMatch,
///          NearbyPosts, WeeklyChallenge, ActivityFeed
///   Right: [Onboarding desktop], UnreadMessages, StatsCards,
///          TrustScore, ThanksReceived, [Weather, Holiday],
///          CommunityPulse
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardDataProvider);
    final user = ref.watch(currentUserProvider);

    return CinemaAppShell(
      currentRoute: '/dashboard',
      title: 'DASHBOARD',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardDataProvider),
        color: MnColors.amber,
        backgroundColor: MnColors.elevated,
        child: data.when(
          loading: () => const _Loading(),
          error: (e, _) => CinemaEmptyState(
            icon: LucideIcons.alertCircle,
            title: 'Fehler beim Laden',
            message: e.toString(),
          ),
          data: (d) => _DashboardLayout(data: d, userId: user?.id),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        CinemaLoadingSkeleton(),
        SizedBox(height: 12),
        CinemaLoadingSkeleton(),
        SizedBox(height: 12),
        CinemaLoadingSkeleton(variant: SkeletonVariant.list),
      ],
    );
  }
}

class _DashboardLayout extends StatelessWidget {
  final DashboardData data;
  final String? userId;
  const _DashboardLayout({required this.data, this.userId});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        if (isDesktop) {
          return _DesktopLayout(data: data, userId: userId);
        }
        return _MobileLayout(data: data, userId: userId);
      },
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final DashboardData data;
  final String? userId;
  const _DesktopLayout({required this.data, this.userId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column (2/3)
            Expanded(
              flex: 2,
              child: _LeftColumn(data: data, isMobile: false),
            ),
            const SizedBox(width: 20),
            // Right column (1/3)
            Expanded(
              flex: 1,
              child: _RightColumn(data: data, userId: userId),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final DashboardData data;
  final String? userId;
  const _MobileLayout({required this.data, this.userId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Web-Reihenfolge mobile (left column items)
          _LeftColumn(data: data, isMobile: true),
          const SizedBox(height: 16),
          // Mobile: sidebar-content am Ende
          _RightColumn(data: data, userId: userId),
        ],
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  final DashboardData data;
  final bool isMobile;
  const _LeftColumn({required this.data, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final totalUnread = data.unreadMessages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Hero
        DashboardHeroCard(
          profile: data.profile,
          memberSinceDays: data.memberSinceDays,
        ),
        const SizedBox(height: 16),
        // 2. NinaWarning + FoodWarning (placeholder bis Edge-Function da ist)
        const NinaWarningBanner(),
        // 3. Onboarding (mobile only)
        if (isMobile && !data.onboardingProgress.completed) ...[
          OnboardingChecklist(progress: data.onboardingProgress),
          const SizedBox(height: 16),
        ],
        // 4. QuickActions
        QuickActions(unreadCount: totalUnread),
        const SizedBox(height: 16),
        // 5. UnreadMessages (mobile only)
        if (isMobile && data.unreadMessages.isNotEmpty) ...[
          UnreadMessagesWidget(messages: data.unreadMessages),
          const SizedBox(height: 16),
        ],
        // 6. SmartMatch
        const SmartMatchWidget(),
        const SizedBox(height: 16),
        // 7. NearbyPosts
        NearbyPostsWidget(
          posts: data.nearbyPosts,
          hasCoords: data.profile?['latitude'] != null,
        ),
        const SizedBox(height: 16),
        // 8. Weekly Challenge
        const WeeklyChallengeHighlight(),
        const SizedBox(height: 16),
        // 9. Activity Feed
        ActivityFeedWidget(activities: data.recentActivity),
      ],
    );
  }
}

class _RightColumn extends StatelessWidget {
  final DashboardData data;
  final String? userId;
  const _RightColumn({required this.data, this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Onboarding (desktop only)
        if (!data.onboardingProgress.completed) ...[
          OnboardingChecklist(progress: data.onboardingProgress),
          const SizedBox(height: MnDimensions.spaceMd),
        ],
        // UnreadMessages (desktop)
        if (data.unreadMessages.isNotEmpty) ...[
          UnreadMessagesWidget(messages: data.unreadMessages),
          const SizedBox(height: MnDimensions.spaceMd),
        ],
        // StatsCards
        StatsCards(stats: data.stats),
        const SizedBox(height: MnDimensions.spaceMd),
        // TrustScore
        TrustScoreCard(trustScore: data.trustScore),
        const SizedBox(height: MnDimensions.spaceMd),
        // ThanksReceived
        if (userId != null) ...[
          ThanksReceivedWidget(userId: userId!),
          const SizedBox(height: MnDimensions.spaceMd),
        ],
        // CommunityPulse
        CommunityPulseWidget(
          activeNeighbors: data.stats.activeNeighbors,
          totalNeighbors: data.totalNeighbors,
        ),
      ],
    );
  }
}
