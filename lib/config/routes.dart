import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/screens/auth/login_screen.dart';
import 'package:mensaena/screens/auth/register_screen.dart';
import 'package:mensaena/screens/auth/forgot_password_screen.dart';
import 'package:mensaena/screens/dashboard/dashboard_shell.dart';
import 'package:mensaena/screens/home/home_screen.dart';
import 'package:mensaena/screens/posts/posts_screen.dart';
import 'package:mensaena/screens/posts/post_detail_screen.dart';
import 'package:mensaena/screens/create/create_post_screen.dart';
import 'package:mensaena/screens/map/map_screen.dart';
import 'package:mensaena/screens/chat/chat_screen.dart';
import 'package:mensaena/screens/chat/conversation_screen.dart';
import 'package:mensaena/screens/messages/messages_screen.dart';
import 'package:mensaena/screens/profile/profile_screen.dart';
import 'package:mensaena/screens/profile/profile_edit_screen.dart';
import 'package:mensaena/screens/profile/public_profile_screen.dart';
import 'package:mensaena/screens/notifications/notifications_screen.dart';
import 'package:mensaena/screens/board/board_screen.dart';
import 'package:mensaena/screens/events/events_screen.dart';
import 'package:mensaena/screens/events/event_detail_screen.dart';
import 'package:mensaena/screens/events/event_create_screen.dart';
import 'package:mensaena/screens/organizations/organizations_screen.dart';
import 'package:mensaena/screens/organizations/organization_detail_screen.dart';
import 'package:mensaena/screens/crisis/crisis_screen.dart';
import 'package:mensaena/screens/crisis/crisis_detail_screen.dart';
import 'package:mensaena/screens/crisis/crisis_create_screen.dart';
import 'package:mensaena/screens/groups/groups_screen.dart';
import 'package:mensaena/screens/groups/group_detail_screen.dart';
import 'package:mensaena/screens/settings/settings_screen.dart';
import 'package:mensaena/screens/timebank/timebank_screen.dart';
import 'package:mensaena/screens/challenges/challenges_screen.dart';
import 'package:mensaena/screens/matching/matching_screen.dart';
import 'package:mensaena/screens/interactions/interactions_screen.dart';
import 'package:mensaena/screens/interactions/interaction_detail_screen.dart';
import 'package:mensaena/screens/knowledge/knowledge_screen.dart';
import 'package:mensaena/screens/skills/skills_screen.dart';
import 'package:mensaena/screens/sharing/sharing_screen.dart';
import 'package:mensaena/screens/supply/supply_screen.dart';
import 'package:mensaena/screens/marketplace/marketplace_screen.dart';
import 'package:mensaena/screens/housing/housing_screen.dart';
import 'package:mensaena/screens/mobility/mobility_screen.dart';
import 'package:mensaena/screens/animals/animals_screen.dart';
import 'package:mensaena/screens/badges/badges_screen.dart';
import 'package:mensaena/screens/calendar/calendar_screen.dart';
import 'package:mensaena/screens/community/community_screen.dart';
import 'package:mensaena/screens/mental_support/mental_support_screen.dart';
import 'package:mensaena/screens/rescuer/rescuer_screen.dart';
import 'package:mensaena/screens/harvest/harvest_screen.dart';
import 'package:mensaena/screens/wiki/wiki_screen.dart';
import 'package:mensaena/screens/admin/admin_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) => createRouter(ref));

GoRouter createRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/auth/login',
    refreshListenable: ref.read(authNotifierProvider),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isAuthenticated && !isAuthRoute) return '/auth/login';
      if (isAuthenticated && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Dashboard Shell with Bottom Navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/dashboard/map',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MapScreen(),
            ),
          ),
          GoRoute(
            path: '/dashboard/create',
            builder: (context, state) => CreatePostScreen(
              module: state.uri.queryParameters['module'],
              initialType: state.uri.queryParameters['type'],
              initialCategory: state.uri.queryParameters['category'],
            ),
          ),
          GoRoute(
            path: '/dashboard/messages',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MessagesScreen(),
            ),
          ),
          GoRoute(
            path: '/dashboard/chat',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChatScreen(),
            ),
          ),

          // Posts
          GoRoute(
            path: '/dashboard/posts',
            builder: (context, state) => const PostsScreen(),
          ),
          GoRoute(
            path: '/dashboard/posts/:id',
            builder: (context, state) => PostDetailScreen(
              postId: state.pathParameters['id']!,
            ),
          ),

          // Profile
          GoRoute(
            path: '/dashboard/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/dashboard/profile/edit',
            builder: (context, state) => const ProfileEditScreen(),
          ),
          GoRoute(
            path: '/dashboard/profile/:userId',
            builder: (context, state) => PublicProfileScreen(
              userId: state.pathParameters['userId']!,
            ),
          ),

          // Notifications
          GoRoute(
            path: '/dashboard/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),

          // Board
          GoRoute(
            path: '/dashboard/board',
            builder: (context, state) => const BoardScreen(),
          ),

          // Events
          GoRoute(
            path: '/dashboard/events',
            builder: (context, state) => const EventsScreen(),
          ),
          GoRoute(
            path: '/dashboard/events/create',
            builder: (context, state) => const EventCreateScreen(),
          ),
          GoRoute(
            path: '/dashboard/events/:id',
            builder: (context, state) => EventDetailScreen(
              eventId: state.pathParameters['id']!,
            ),
          ),

          // Organizations
          GoRoute(
            path: '/dashboard/organizations',
            builder: (context, state) => const OrganizationsScreen(),
          ),
          GoRoute(
            path: '/dashboard/organizations/:orgId',
            builder: (context, state) => OrganizationDetailScreen(
              orgId: state.pathParameters['orgId']!,
            ),
          ),

          // Crisis
          GoRoute(
            path: '/dashboard/crisis',
            builder: (context, state) => const CrisisScreen(),
          ),
          GoRoute(
            path: '/dashboard/crisis/create',
            builder: (context, state) => const CrisisCreateScreen(),
          ),
          GoRoute(
            path: '/dashboard/crisis/:crisisId',
            builder: (context, state) => CrisisDetailScreen(
              crisisId: state.pathParameters['crisisId']!,
            ),
          ),

          // Groups
          GoRoute(
            path: '/dashboard/groups',
            builder: (context, state) => const GroupsScreen(),
          ),
          GoRoute(
            path: '/dashboard/groups/:groupId',
            builder: (context, state) => GroupDetailScreen(
              groupId: state.pathParameters['groupId']!,
            ),
          ),

          // Chat Conversation
          GoRoute(
            path: '/dashboard/chat/:conversationId',
            builder: (context, state) => ConversationScreen(
              conversationId: state.pathParameters['conversationId']!,
            ),
          ),

          // Settings
          GoRoute(
            path: '/dashboard/settings',
            builder: (context, state) => const SettingsScreen(),
          ),

          // Timebank
          GoRoute(
            path: '/dashboard/timebank',
            builder: (context, state) => const TimebankScreen(),
          ),

          // Challenges
          GoRoute(
            path: '/dashboard/challenges',
            builder: (context, state) => const ChallengesScreen(),
          ),

          // Matching
          GoRoute(
            path: '/dashboard/matching',
            builder: (context, state) => const MatchingScreen(),
          ),

          // Interactions
          GoRoute(
            path: '/dashboard/interactions',
            builder: (context, state) => const InteractionsScreen(),
          ),
          GoRoute(
            path: '/dashboard/interactions/:interactionId',
            builder: (context, state) => InteractionDetailScreen(
              interactionId: state.pathParameters['interactionId']!,
            ),
          ),

          // Module Screens
          GoRoute(
            path: '/dashboard/knowledge',
            builder: (context, state) => const KnowledgeScreen(),
          ),
          GoRoute(
            path: '/dashboard/skills',
            builder: (context, state) => const SkillsScreen(),
          ),
          GoRoute(
            path: '/dashboard/sharing',
            builder: (context, state) => const SharingScreen(),
          ),
          GoRoute(
            path: '/dashboard/supply',
            builder: (context, state) => const SupplyScreen(),
          ),
          GoRoute(
            path: '/dashboard/marketplace',
            builder: (context, state) => const MarketplaceScreen(),
          ),
          GoRoute(
            path: '/dashboard/housing',
            builder: (context, state) => const HousingScreen(),
          ),
          GoRoute(
            path: '/dashboard/mobility',
            builder: (context, state) => const MobilityScreen(),
          ),
          GoRoute(
            path: '/dashboard/animals',
            builder: (context, state) => const AnimalsScreen(),
          ),
          GoRoute(
            path: '/dashboard/badges',
            builder: (context, state) => const BadgesScreen(),
          ),
          GoRoute(
            path: '/dashboard/calendar',
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/dashboard/community',
            builder: (context, state) => const CommunityScreen(),
          ),
          GoRoute(
            path: '/dashboard/mental-support',
            builder: (context, state) => const MentalSupportScreen(),
          ),
          GoRoute(
            path: '/dashboard/rescuer',
            builder: (context, state) => const RescuerScreen(),
          ),
          GoRoute(
            path: '/dashboard/harvest',
            builder: (context, state) => const HarvestScreen(),
          ),
          GoRoute(
            path: '/dashboard/wiki',
            builder: (context, state) => const WikiScreen(),
          ),
          GoRoute(
            path: '/dashboard/admin',
            builder: (context, state) => const AdminScreen(),
          ),
        ],
      ),
    ],
  );
}
