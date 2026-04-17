import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/notification_provider.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/providers/dashboard_provider.dart';
import 'package:mensaena/models/notification.dart';
import 'package:mensaena/screens/dashboard/app_drawer.dart';

class DashboardShell extends ConsumerStatefulWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  RealtimeChannel? _notifChannel;
  RealtimeChannel? _postsChannel;
  RealtimeChannel? _messagesChannel;
  int _realtimeUnreadDelta = 0;

  static const _bottomNavPaths = [
    '/dashboard',
    '/dashboard/map',
    '/dashboard/create',
    '/dashboard/chat',
  ];

  @override
  void initState() {
    super.initState();
    _setupRealtimeNotifications();
    _setupRealtimeDashboard();
  }

  @override
  void dispose() {
    _notifChannel?.unsubscribe();
    _postsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeDashboard() {
    final client = ref.read(supabaseProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    _postsChannel = client.channel('dashboard-posts:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (_) {
            if (mounted) ref.invalidate(dashboardDataProvider);
          },
        )
        .subscribe();

    _messagesChannel = client.channel('dashboard-messages:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (mounted) ref.invalidate(unreadCountProvider);
          },
        )
        .subscribe();
  }

  void _setupRealtimeNotifications() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    _notifChannel = ref.read(notificationServiceProvider).subscribeToNotifications(
      userId,
      (notification) {
        if (!mounted) return;
        setState(() => _realtimeUnreadDelta++);
        ref.invalidate(unreadNotificationCountProvider);
        _showNotificationSnackbar(notification);
      },
    );
  }

  void _showNotificationSnackbar(AppNotification notification) {
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _getNotifColor(notification.type).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getNotifIcon(notification.type), size: 16, color: _getNotifColor(notification.type)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
                Text(notification.body, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: notification.link != null
          ? SnackBarAction(label: 'Anzeigen', textColor: AppColors.primary200, onPressed: () {
              if (notification.link!.startsWith('/')) {
                context.push(notification.link!);
              }
            })
          : null,
    ));
  }

  IconData _getNotifIcon(String type) {
    switch (type) {
      case 'message': return Icons.chat_bubble_outline;
      case 'interaction': return Icons.handshake_outlined;
      case 'trust_rating': return Icons.shield_outlined;
      case 'post_nearby': return Icons.location_on_outlined;
      case 'crisis': return Icons.warning_outlined;
      case 'comment': return Icons.comment_outlined;
      case 'event': return Icons.event_outlined;
      case 'matching': return Icons.auto_awesome;
      case 'zeitbank_confirmation': return Icons.access_time;
      case 'welcome': return Icons.waving_hand;
      case 'badge': return Icons.military_tech;
      default: return Icons.notifications_outlined;
    }
  }

  Color _getNotifColor(String type) {
    switch (type) {
      case 'crisis': return AppColors.emergency;
      case 'message': return AppColors.info;
      case 'interaction': return AppColors.primary500;
      case 'trust_rating': return AppColors.trust;
      case 'matching': return AppColors.warning;
      default: return AppColors.primary500;
    }
  }

  void _onTabTapped(int index) {
    if (index == 4) {
      _scaffoldKey.currentState?.openDrawer();
      return;
    }
    setState(() => _currentIndex = index);
    context.go(_bottomNavPaths[index]);
  }

  int _getIndexForPath(String path) {
    for (int i = 0; i < _bottomNavPaths.length; i++) {
      if (path == _bottomNavPaths[i]) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final navIndex = _getIndexForPath(location);
    if (navIndex >= 0 && navIndex != _currentIndex) {
      _currentIndex = navIndex;
    }

    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final unreadMessages = ref.watch(unreadCountProvider);
    final totalNotifCount = (unreadNotifications.valueOrNull ?? 0) + _realtimeUnreadDelta;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex < 4 ? _currentIndex : 0,
        onDestinationSelected: _onTabTapped,
        backgroundColor: AppColors.surface,
        elevation: 8,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Karte',
          ),
          NavigationDestination(
            icon: Transform.translate(
              offset: const Offset(0, -4),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1EAAA6), Color(0xFF38a169)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary500.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
            label: 'Erstellen',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${unreadMessages.valueOrNull ?? 0}', style: const TextStyle(fontSize: 10)),
              isLabelVisible: (unreadMessages.valueOrNull ?? 0) > 0,
              child: const Icon(Icons.chat_outlined),
            ),
            selectedIcon: Badge(
              label: Text('${unreadMessages.valueOrNull ?? 0}', style: const TextStyle(fontSize: 10)),
              isLabelVisible: (unreadMessages.valueOrNull ?? 0) > 0,
              child: const Icon(Icons.chat),
            ),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$totalNotifCount', style: const TextStyle(fontSize: 10)),
              isLabelVisible: totalNotifCount > 0,
              child: const Icon(Icons.menu),
            ),
            label: 'Mehr',
          ),
        ],
      ),
    );
  }
}
