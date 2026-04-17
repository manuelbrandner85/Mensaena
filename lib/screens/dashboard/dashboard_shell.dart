import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/notification_provider.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/providers/dashboard_provider.dart';
import 'package:mensaena/widgets/notification_snackbar.dart';
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
        await ref.read(supabaseProvider).from('profiles').update({'push_token': token, 'fcm_token': token}).eq('id', userId);
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
        HapticFeedback.mediumImpact();
        showRichNotificationSnackbar(context, ref, notification);
      },
    );
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
