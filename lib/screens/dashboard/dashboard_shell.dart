import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/notification_provider.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/providers/dashboard_provider.dart';
import 'package:mensaena/models/notification.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/zeitbank_confirmation_banner.dart';
import 'package:mensaena/widgets/mensaena_bot.dart';
import 'package:mensaena/widgets/onboarding_tour.dart';
import 'package:mensaena/screens/dashboard/app_drawer.dart';

class DashboardShell extends ConsumerStatefulWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  RealtimeChannel? _notifChannel;
  RealtimeChannel? _postsChannel;
  RealtimeChannel? _messagesChannel;
  int _realtimeUnreadDelta = 0;
  AudioPlayer? _audioPlayer;
  bool _soundEnabled = true;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  static const _bottomNavPaths = [
    '/dashboard',
    '/dashboard/map',
    '/dashboard/create',
    '/dashboard/chat',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudio();
    _setupRealtimeNotifications();
    _setupRealtimeDashboard();
    _setupFCM();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer?.dispose();
    _notifChannel?.unsubscribe();
    _postsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  Future<void> _initAudio() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setVolume(0.3);
      await _audioPlayer!.setSource(AssetSource('sounds/notification.mp3'));
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('mensaena_notify_sound') ?? true;
    } catch (_) {}
  }

  Future<void> _playNotificationSound() async {
    if (!_soundEnabled || _lifecycleState != AppLifecycleState.resumed) return;
    try {
      await _audioPlayer?.seek(Duration.zero);
      await _audioPlayer?.resume();
    } catch (_) {}
  }

  Future<void> _setupFCM() async {
    try {
      // Dynamic import to avoid crash when Firebase is not configured
      final messaging = (await _getFirebaseMessaging());
      if (messaging == null) return;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      final userId = ref.read(currentUserIdProvider);
      if (token != null && userId != null) {
        await ref.read(supabaseProvider).from('profiles').update({'fcm_token': token}).eq('id', userId);
      }
    } catch (_) {}
  }

  Future<dynamic> _getFirebaseMessaging() async {
    try {
      // This will throw if Firebase is not initialized
      final dynamic messaging = await _tryImportFirebase();
      return messaging;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _tryImportFirebase() async {
    // Wrapped in try/catch — Firebase may not be available on all devices/emulators
    try {
      final module = await Future.value(null); // placeholder
      return module;
    } catch (_) {
      return null;
    }
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
        _playNotificationSound();
        _showRichNotificationSnackbar(notification);
      },
    );
  }

  void _showRichNotificationSnackbar(AppNotification notification) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/dashboard/notifications') return;

    HapticFeedback.mediumImpact();

    final color = _getNotifColor(notification.type);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.actorId != null)
            FutureBuilder(
              future: ref.read(supabaseProvider).from('profiles').select('name, avatar_url').eq('id', notification.actorId!).maybeSingle(),
              builder: (_, snap) {
                final profile = snap.data;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: AvatarWidget(
                    imageUrl: profile?['avatar_url'] as String?,
                    name: profile?['name'] as String? ?? '?',
                    size: 36,
                  ),
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getNotifIcon(notification.type), size: 18, color: color),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(notification.createdAt, locale: 'de'),
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFF1F2937),
      duration: const Duration(seconds: 6),
      action: notification.link != null
          ? SnackBarAction(
              label: 'Anzeigen',
              textColor: AppColors.primary200,
              onPressed: () {
                if (notification.link!.startsWith('/')) {
                  context.push(notification.link!);
                }
              },
            )
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
      body: Stack(
        children: [
          Column(
            children: [
              const ZeitbankConfirmationBanner(),
              Expanded(child: widget.child),
            ],
          ),
          const MensaenaBot(),
          const OnboardingTour(),
        ],
      ),
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
