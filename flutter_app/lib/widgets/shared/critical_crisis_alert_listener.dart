/// SKILL: mensaena-features (UX-Welle1 K2)
/// Triggert Haptic + System-Sound, wenn eine NEUE kritische, aktive Krise
/// erscheint. Dedupliziert über SecureStorage (letzter gesehener Krisen-ID).
/// Wird im DashboardScaffold gemountet und pollt alle 60 Sekunden.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/haptics.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_service.dart';

const _lastSeenKey = 'last_seen_critical_crisis_v1';
const _storage = FlutterSecureStorage();

class CriticalCrisisAlertListener extends ConsumerStatefulWidget {
  const CriticalCrisisAlertListener({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<CriticalCrisisAlertListener> createState() =>
      _CriticalCrisisAlertListenerState();
}

class _CriticalCrisisAlertListenerState
    extends ConsumerState<CriticalCrisisAlertListener>
    with WidgetsBindingObserver {
  Timer? _timer;
  String? _lastSeenId;
  bool _bootstrapped = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        _lastSeenId = await _storage.read(key: _lastSeenKey);
      } catch (_) {/* default null */}
      _bootstrapped = true;
      await _checkOnce();
      _startTimer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    // PERF-FIX (App-langsam-Report): Polling-Intervall von 60s auf 120s
    // verlängert (kritische Krisen sind seltene, dringliche Events — alle
    // 60s war Overkill). + Lifecycle-Gate: Timer läuft nur im Vordergrund,
    // im Hintergrund/Inaktiv wird komplett gestoppt → kein Netz-/CPU-Spam
    // wenn der User in einer anderen App ist.
    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(seconds: 120), (_) => _checkOnce());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      // Beim Vordergrund-Rückkehr einmal nachfassen + Timer wieder starten.
      _startTimer();
      _checkOnce();
    } else {
      // Hintergrund/Inaktiv → Timer stoppen, kein Polling.
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _checkOnce() async {
    if (!_bootstrapped) return;
    if (_lifecycle != AppLifecycleState.resumed) return;
    try {
      final rows = await sb
          .from('crises')
          .select('id, created_at')
          .eq('status', 'active')
          .eq('urgency', 'critical')
          .order('created_at', ascending: false)
          .limit(1);
      final list = (rows as List).whereType<Map<String, dynamic>>().toList();
      if (list.isEmpty) return;
      final newestId = list.first['id'] as String?;
      if (newestId == null || newestId == _lastSeenId) return;

      final isFirstRun = _lastSeenId == null;
      _lastSeenId = newestId;
      try {
        await _storage.write(key: _lastSeenKey, value: newestId);
      } catch (_) {}

      if (isFirstRun) return;

      Haptics.heavyImpact();
      await SoundService.alert();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      Haptics.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      Haptics.heavyImpact();
    } catch (_) {/* offline / RLS — silent */}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
