/// SKILL: mensaena-features (P8) — Live-Location-Share im Chat.
/// User teilt für N Minuten seinen Standort mit einem Conversation.
/// Updates alle 15s in `live_locations` mit `expires_at`.
library;

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'supabase_service.dart';

class LiveLocationService {
  LiveLocationService._();
  static final LiveLocationService instance = LiveLocationService._();

  Timer? _timer;
  StreamSubscription<Position>? _sub;
  String? _conversationId;

  bool get isSharing => _timer != null || _sub != null;
  String? get currentConversationId => _conversationId;

  Future<bool> start({
    required String conversationId,
    Duration duration = const Duration(minutes: 30),
  }) async {
    await stop();
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      final req = await Geolocator.requestPermission();
      if (req == LocationPermission.denied ||
          req == LocationPermission.deniedForever) {
        return false;
      }
    }
    _conversationId = conversationId;
    final expiresAt = DateTime.now().add(duration);

    Future<void> publish(Position pos) async {
      try {
        await sb.from('live_locations').upsert({
          'user_id': uid,
          'conversation_id': conversationId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'updated_at': DateTime.now().toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        }, onConflict: 'user_id,conversation_id');
      } catch (_) {}
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      await publish(pos);
    } catch (_) {}

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(publish);

    _timer = Timer(duration, () => stop());
    return true;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;
    final uid = SupabaseService.currentUser?.id;
    if (uid != null && _conversationId != null) {
      try {
        await sb
            .from('live_locations')
            .delete()
            .eq('user_id', uid)
            .eq('conversation_id', _conversationId!);
      } catch (_) {}
    }
    _conversationId = null;
  }
}
