import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../providers/active_call_provider.dart';
import '../../../services/call_busy_state.dart';
import '../../../services/call_room_holder.dart';
import '../../../services/dm_call_service.dart';
import '../../../services/end_tone_service.dart';
import '../../../services/live_audio_service.dart';
import '../../../services/livekit_token_service.dart';
import '../../../services/room_events_service.dart';
import '../../../services/sound_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/bloom.dart';
import '../../../widgets/shared/floating_reactions_layer.dart';
import '../../../widgets/shared/user_picker_sheet.dart';

/// SKILL: mensaena-features
/// 1:1-DM-Anruf (Audio + optional Video) via LiveKit.
/// Erwartet einen bereits in dm_calls erstellten Call (callId + roomName).
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    required this.callId,
    required this.roomName,
    required this.peerName,
    this.preAccepted = false,
    super.key,
  });

  final String callId;
  final String roomName;
  final String peerName;

  /// True wenn der Callee den Anruf bereits via CallKit angenommen hat →
  /// CallScreen verbindet sofort, ohne den dm_calls-Status erst abzufragen
  /// (schnellerer Raum-Eintritt, kein "App lädt erst komplett"-Gefühl).
  final bool preAccepted;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

enum _CallState {
  outgoingRinging,
  connecting,
  connected,
  reconnecting,
  ended,
  failed,
}

class _CallScreenState extends ConsumerState<CallScreen> {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  _CallState _state = _CallState.connecting;
  bool _micEnabled = true;
  bool _camEnabled = false;
  bool _speakerOn = false;
  String? _error;
  String? _peerAvatarUrl;
  bool _isCaller = false;
  AudioPlayer? _ringback;
  Timer? _ringbackHaptic;
  Timer? _ringingTimeout;
  Timer? _ringingTicker;
  int _ringingElapsed = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _callStatusSub;
  // Call-Duration-Timer — startet bei connected.
  // PERF (Audit): ValueNotifier statt setState(){} damit der 1s-Tick NUR
  // den kleinen Subtitle-Text rebuildet (ValueListenableBuilder, s.u.) —
  // nicht den ganzen Call-Screen mit LiveKit-Video-Tracks + Gradient +
  // Controls (das war ein 1Hz-Vollrebuild und zog Frames).
  final Stopwatch _stopwatch = Stopwatch();
  final ValueNotifier<int> _elapsedSec = ValueNotifier<int>(0);
  Timer? _ticker;
  // Mini-Cam-Preview-Position (draggable).
  Offset _camPreviewPos = const Offset(16, 100);
  // Floating Reactions + Room-Events (DataChannel-Wrapper).
  final FloatingReactionsController _reactionsCtrl =
      FloatingReactionsController();
  RoomEventsService? _events;
  StreamSubscription<RoomEvent>? _eventsSub;
  // F11: Connection-Quality
  lk.ConnectionQuality _quality = lk.ConnectionQuality.unknown;
  bool _poorWarningShown = false;
  // F12: Screen-Share
  bool _screenShareEnabled = false;
  // Punkt 6: true nur bei echtem Auflegen — steuert ob dispose() den
  // Room trennt oder im CallRoomHolder weiterlaufen lässt.
  bool _hungUp = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _loadPeerAvatar();
  }

  /// Entscheidet ob wir Caller (Outgoing-Ringing-UI + Ringback) oder
  /// Callee (sofort LiveKit-Connect — Annahme erfolgt schon vor Nav) sind.
  Future<void> _bootstrap() async {
    // Punkt 6: Reattach an einen noch laufenden Call (Mini-Player getappt).
    if (CallRoomHolder.hasRoomFor(widget.callId)) {
      await _reattach();
      return;
    }
    // Callee hat via CallKit angenommen → direkt verbinden, kein
    // redundanter dm_calls-Status-Query. Status-Update läuft fire-and-forget.
    if (widget.preAccepted) {
      unawaited(_markActive());
      await _connect();
      return;
    }
    try {
      final me = SupabaseService.currentUser?.id;
      final call = await sb
          .from('dm_calls')
          .select('caller_id, callee_id, status')
          .eq('id', widget.callId)
          .maybeSingle();
      if (call == null) {
        await _connect();
        return;
      }
      final callerId = call['caller_id'] as String?;
      final status = call['status'] as String?;
      _isCaller = me != null && callerId == me;
      // Caller + Status noch 'ringing' → Outgoing-Ringing-Modus.
      if (_isCaller && status == 'ringing') {
        if (mounted) {
          setState(() => _state = _CallState.outgoingRinging);
        }
        _startRingback();
        _watchCallStatus();
        // Ringing-Countdown: 45s totale Klingelzeit, jede Sekunde
        // ein setState damit der OutgoingRingingView den Counter neu rendert.
        _ringingElapsed = 0;
        _ringingTicker?.cancel();
        _ringingTicker =
            Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) {
            _ringingTicker?.cancel();
            return;
          }
          if (_state != _CallState.outgoingRinging) {
            _ringingTicker?.cancel();
            return;
          }
          setState(() => _ringingElapsed++);
        });
        // 45s Timeout (parallel zur Callee-Seite).
        _ringingTimeout = Timer(const Duration(seconds: 45), () {
          if (_state == _CallState.outgoingRinging) {
            _onPeerUnreachable(status: 'missed');
          }
        });
        return;
      }
      // Sonst: direkt connecten (Callee-Side oder bereits 'active').
      await _connect();
    } catch (_) {
      await _connect();
    }
  }

  /// Setzt den Call auf 'active' (fire-and-forget) — beim direkten Beitritt
  /// nach CallKit-Accept, damit der Caller-Status sofort umspringt.
  Future<void> _markActive() async {
    try {
      await sb.from('dm_calls').update({'status': 'active'}).eq(
            'id',
            widget.callId,
          );
    } catch (_) {}
  }

  void _watchCallStatus() {
    try {
      _callStatusSub = sb
          .from('dm_calls')
          .stream(primaryKey: ['id'])
          .eq('id', widget.callId)
          .listen((rows) async {
            if (rows.isEmpty) return;
            final r = rows.first;
            final s = r['status'] as String?;
            if (s == 'active') {
              _ringingTimeout?.cancel();
              await _stopRingback();
              if (!mounted) return;
              setState(() => _state = _CallState.connecting);
              await _connect();
            } else if (s == 'cancelled' || s == 'missed' || s == 'ended') {
              _onPeerUnreachable(status: s ?? 'cancelled');
            }
          });
    } catch (_) {}
  }

  Future<void> _startRingback() async {
    // Versuche zuerst die Asset-MP3. Wenn nicht vorhanden — Vibrations-Pulse
    // als Fallback (haptic alle 2s).
    // Punkt 7: Lautstärke + Vibration aus User-Einstellungen.
    final vol = await SoundService.ringVolume();
    final vibrate = await SoundService.callVibration();
    try {
      if (vol > 0) {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setVolume(vol);
        await player.play(AssetSource('sounds/ringback.mp3'));
        _ringback = player;
      }
    } catch (_) {
      _ringback = null;
    }
    // Haptic-Pulse parallel: dezenter Tap alle 2 Sekunden bis Verbindung.
    if (vibrate) {
      _ringbackHaptic = Timer.periodic(const Duration(seconds: 2), (_) {
        HapticFeedback.lightImpact();
      });
    }
  }

  Future<void> _stopRingback() async {
    _ringbackHaptic?.cancel();
    _ringbackHaptic = null;
    try {
      await _ringback?.stop();
      await _ringback?.dispose();
    } catch (_) {}
    _ringback = null;
  }

  Future<void> _onPeerUnreachable({String status = 'missed'}) async {
    _hungUp = true;
    LiveAudioService.stop(); // Punkt 11
    _ringingTimeout?.cancel();
    _ringingTicker?.cancel();
    await _stopRingback();
    await EndToneService.play();
    // Punkt 6: Call endgültig → Holder leeren.
    _room = null;
    await CallRoomHolder.clear();
    // Active-Call-Banner clearen falls noch gesetzt.
    if (ref.read(activeCallProvider)?.callId == widget.callId) {
      ref.read(activeCallProvider.notifier).state = null;
    }
    if (status == 'missed') {
      try {
        await sb.from('dm_calls').update({
          'status': 'missed',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', widget.callId);
      } catch (_) {}
    }
    if (!mounted) return;
    final msg = status == 'cancelled'
        ? 'call.callDeclined'.tr()
        : 'call.notReachable'.tr();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(msg,
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard/messages');
    }
  }

  Future<void> _cancelOutgoing() async {
    _ringingTimeout?.cancel();
    _ringingTicker?.cancel();
    await _stopRingback();
    await EndToneService.play();
    if (ref.read(activeCallProvider)?.callId == widget.callId) {
      ref.read(activeCallProvider.notifier).state = null;
    }
    await DmCallService.cancel(widget.callId);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard/messages');
    }
  }

  Future<void> _loadPeerAvatar() async {
    // Versuch: ermittle Peer-ID via dm_calls + lade Profil-Bild.
    try {
      final me = SupabaseService.currentUser?.id;
      if (me == null) return;
      final call = await sb
          .from('dm_calls')
          .select('caller_id, callee_id')
          .eq('id', widget.callId)
          .maybeSingle();
      if (call == null) return;
      final peerId = call['caller_id'] == me
          ? call['callee_id'] as String?
          : call['caller_id'] as String?;
      if (peerId == null) return;
      final p = await sb
          .from('profiles')
          .select('avatar_url')
          .eq('id', peerId)
          .maybeSingle();
      if (mounted) {
        setState(() => _peerAvatarUrl = p?['avatar_url'] as String?);
      }
    } catch (_) {}
  }

  Future<void> _connect() async {
    // Permissions
    final mic = await Permission.microphone.request();
    if (mic.isDenied || mic.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.failed;
        _error = 'Mikrofon-Berechtigung verweigert.';
      });
      return;
    }

    // Display Name fuer LiveKit-Identity (best-effort)
    final myId = SupabaseService.currentUser?.id ?? 'guest';
    String myName = 'Mitglied';
    try {
      final p = await sb
          .from('profiles')
          .select('display_name, name')
          .eq('id', myId)
          .maybeSingle();
      myName = (p?['display_name'] as String?) ??
          (p?['name'] as String?) ??
          'Mitglied';
    } catch (_) {}

    // Token holen
    final ({String token, String url}) tok;
    try {
      tok = await LivekitTokenService.fetch(
        roomName: widget.roomName,
        displayName: myName,
        canPublish: true,
      );
    } on LivekitTokenError catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.failed;
        _error = 'Token-Fehler: ${e.message}';
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.failed;
        _error = 'Token-Fehler: $e';
      });
      return;
    }

    final room = lk.Room();
    _room = room;
    // Punkt 4: User ist jetzt im Call → eingehende Anrufe als besetzt ablehnen.
    CallBusyState.inCall = true;
    LiveAudioService.start(); // Punkt 11: Hintergrund-/Screen-off-Audio.
    _attachRoomListeners(room);

    try {
      await room.connect(tok.url, tok.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) return;
      setState(() => _state = _CallState.connected);
      // Call-Duration-Timer starten.
      _stopwatch
        ..reset()
        ..start();
      _elapsedSec.value = 0;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _elapsedSec.value = _stopwatch.elapsed.inSeconds;
      });
      final startedAt = DateTime.now();
      // Active-Call-Banner: ab jetzt weiss die App-Shell vom laufenden
      // Call, so kann der User wegnavigieren ohne den Call zu verlieren.
      ref.read(activeCallProvider.notifier).state = ActiveCallInfo(
        callId: widget.callId,
        roomName: widget.roomName,
        peerName: widget.peerName,
        startedAt: startedAt,
      );
      // Punkt 6: Room im Holder ablegen damit er Screen-Disposal überlebt.
      CallRoomHolder.store(
        r: room,
        callId: widget.callId,
        roomName: widget.roomName,
        peerName: widget.peerName,
        startedAt: startedAt,
      );
      // Room-Events-Bus: Floating-Reactions + Cheer-Pings.
      _attachEventsBus(room);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.failed;
        _error = 'Verbindungs-Fehler: $e';
      });
    }
  }

  /// Punkt 6: Reattach an einen im CallRoomHolder laufenden Room (nach
  /// Minimieren). Kein neuer LiveKit-Join — Audio lief durchgehend weiter.
  Future<void> _reattach() async {
    final room = CallRoomHolder.room;
    if (room == null) {
      // Holder doch leer → normaler Connect.
      await _connect();
      return;
    }
    _room = room;
    CallBusyState.inCall = true;
    LiveAudioService.start(); // Punkt 11: Hintergrund-/Screen-off-Audio.
    _attachRoomListeners(room);
    _attachEventsBus(room);
    if (!mounted) return;
    setState(() => _state = _CallState.connected);
    // Duration ab dem ursprünglichen Start fortführen.
    _stopwatch
      ..reset()
      ..start();
    _elapsedSec.value = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _elapsedSec.value = _stopwatch.elapsed.inSeconds;
    });
  }

  /// Hängt alle Room-Event-Listener an [room]. Wird von _connect UND
  /// _reattach genutzt (bei Reattach mit neuem State neu erstellt).
  void _attachRoomListeners(lk.Room room) {
    _listener = room.createListener()
      ..on<lk.RoomDisconnectedEvent>((_) async {
        if (!mounted) return;
        // Wenn waehrend Reconnecting der Server endgueltig aufgibt,
        // kommt RoomDisconnectedEvent. Sonst war's ein sauberer Hangup.
        setState(() => _state = _CallState.ended);
        _stopwatch.stop();
        _ticker?.cancel();
        await EndToneService.play();
        if (ref.read(activeCallProvider)?.callId == widget.callId) {
          ref.read(activeCallProvider.notifier).state = null;
        }
        // Server-seitiges Ende → Holder aufräumen + Busy-Status freigeben.
        _hungUp = true;
        CallBusyState.inCall = false;
        LiveAudioService.stop();
        CallRoomHolder.room = null;
        CallRoomHolder.callId = null;
      })
      ..on<lk.RoomReconnectingEvent>((_) {
        if (!mounted) return;
        setState(() => _state = _CallState.reconnecting);
      })
      ..on<lk.RoomReconnectedEvent>((_) {
        if (!mounted) return;
        setState(() => _state = _CallState.connected);
      })
      // F11: Verbindungsqualität live tracken. Bei 'poor' Snackbar-Warnung,
      // Indicator-Badge oben rechts zeigt die aktuelle Stufe.
      ..on<lk.ParticipantConnectionQualityUpdatedEvent>((ev) {
        if (!mounted) return;
        if (ev.participant.identity != room.localParticipant?.identity) {
          return;
        }
        setState(() => _quality = ev.connectionQuality);
        if (ev.connectionQuality == lk.ConnectionQuality.poor &&
            !_poorWarningShown) {
          _poorWarningShown = true;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.surface,
            duration: const Duration(seconds: 4),
            content: Text('call.poorConnection'.tr(),
                style: AppTypography.body(
                    size: 13, color: AppColors.herzrotWarm)),
          ));
        }
        if (ev.connectionQuality != lk.ConnectionQuality.poor) {
          _poorWarningShown = false;
        }
      });
  }

  /// Events-Bus (Floating-Reactions) an [room] hängen + CallKit-connected
  /// melden. Wird von _connect UND _reattach genutzt.
  void _attachEventsBus(lk.Room room) {
    _events = RoomEventsService(room: room);
    _eventsSub = _events!.stream.listen((ev) {
      if (ev.type == RoomEventType.reaction) {
        final emoji = ev.data['emoji'] as String?;
        if (emoji != null && emoji.isNotEmpty) {
          _reactionsCtrl.spawn(emoji);
          HapticFeedback.selectionClick();
        }
      }
    });
    // Critical: tell CallKit/Telecom the call connected. Without this,
    // iOS auto-ends after 30s "no answer" and Android's ConnectionService
    // stays in a half-ringing state.
    try {
      FlutterCallkitIncoming.setCallConnected(widget.callId);
    } catch (_) {}
  }

  Future<void> _toggleMic() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !_micEnabled;
    await lp.setMicrophoneEnabled(next);
    setState(() => _micEnabled = next);
  }

  /// F12: Screen-Share toggeln. Auf Android braucht das ggf. eine
  /// Foreground-Service-Permission; bei Fehler zeigen wir Snackbar statt
  /// zu crashen.
  Future<void> _toggleScreenShare() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !_screenShareEnabled;
    try {
      await lp.setScreenShareEnabled(next);
      if (!mounted) return;
      setState(() => _screenShareEnabled = next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('call.screenShareFailed'.tr(),
            style: AppTypography.body(
                size: 13, color: AppColors.herzrotWarm)),
      ));
    }
  }

  Future<void> _toggleCam() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    if (!_camEnabled) {
      final cam = await Permission.camera.request();
      if (cam.isPermanentlyDenied) {
        if (!mounted) return;
        // User-Fix: zeigt klare Aufforderung statt stillem Fail.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'call.cameraDeniedPermanent'.tr(),
            style: AppTypography.body(
                size: 13, color: AppColors.herzrotWarm),
          ),
          action: SnackBarAction(
            label: 'call.openSettings'.tr(),
            onPressed: openAppSettings,
          ),
          duration: const Duration(seconds: 6),
        ));
        return;
      }
      if (cam.isDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('call.cameraDenied'.tr(),
              style: AppTypography.body(
                  size: 13, color: AppColors.herzrotWarm)),
        ));
        return;
      }
    }
    final next = !_camEnabled;
    try {
      await lp.setCameraEnabled(next);
      if (!mounted) return;
      setState(() => _camEnabled = next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'call.cameraFailed'.tr(),
          style: AppTypography.body(
              size: 13, color: AppColors.herzrotWarm),
        ),
      ));
    }
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    try {
      await lk.Hardware.instance.setSpeakerphoneOn(next);
      setState(() => _speakerOn = next);
    } catch (_) {/* Hardware-Plattform-Bridge fehlt evtl. */}
  }

  Future<void> _hangUp() async {
    // Punkt 6: echtes Auflegen → Holder leeren (trennt + disposed Room).
    _hungUp = true;
    LiveAudioService.stop(); // Punkt 11
    _room = null; // dispose() soll den Room nicht doppelt anfassen
    await CallRoomHolder.clear();
    await DmCallService.end(widget.callId);
    await EndToneService.play();
    if (ref.read(activeCallProvider)?.callId == widget.callId) {
      ref.read(activeCallProvider.notifier).state = null;
    }
    // Post-Call-Note: zeigt sich vor der Navigation, async.
    await _maybeShowPostCallNote();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard/messages');
    }
  }

  @override
  void dispose() {
    // Punkt 6: Bei reinem Minimieren (nicht aufgelegt) bleibt der Room im
    // CallRoomHolder aktiv → Audio läuft im Hintergrund weiter, Mini-Player
    // sichtbar. Nur bei echtem Auflegen ist alles schon via
    // CallRoomHolder.clear() getrennt → dann auch Busy-Status zurücksetzen.
    if (_hungUp) {
      CallBusyState.inCall = false;
    }
    _ringingTimeout?.cancel();
    _ringingTicker?.cancel();
    _ringbackHaptic?.cancel();
    _callStatusSub?.cancel();
    _ticker?.cancel();
    _stopwatch.stop();
    _elapsedSec.dispose();
    try {
      _ringback?.stop();
      _ringback?.dispose();
    } catch (_) {}
    // Listener + Events-Bus gehören zu DIESEM State → immer lösen
    // (bei Reattach baut der neue State sie neu auf). Der Room selbst wird
    // NUR bei echtem Auflegen disposed (sonst lebt er im Holder weiter).
    _eventsSub?.cancel();
    _events?.dispose();
    _reactionsCtrl.dispose();
    _listener?.dispose();
    if (_hungUp) {
      _room?.dispose();
    }
    super.dispose();
  }

  void _sendReaction(String emoji) {
    _reactionsCtrl.spawn(emoji);
    HapticFeedback.lightImpact();
    _events?.send(RoomEventType.reaction, {'emoji': emoji}, reliable: false);
  }

  Future<void> _maybeShowPostCallNote() async {
    // Sheet erscheint NUR wenn der Call laenger als 10s ging.
    if (_stopwatch.elapsed.inSeconds < 10) return;
    if (!mounted) return;
    final note = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final ctrl = TextEditingController();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('call.postCallNoteTitle'.tr(),
                    style: AppTypography.display(
                        size: 16, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text('call.postCallNoteHint'.tr(),
                    style: AppTypography.caption()),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'call.postCallNotePlaceholder'.tr(),
                    filled: true,
                    fillColor: AppColors.elevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: AppTypography.body(size: 13, color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('common.skip'.tr()),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(LucideIcons.send, size: 14),
                      label: Text('common.save'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.bronze,
                      ),
                      onPressed: () =>
                          Navigator.pop(ctx, ctrl.text.trim()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (note == null || note.isEmpty) return;
    // Notiz als SYSTEM-Chat-Message speichern. Conv-ID per Call-Lookup.
    try {
      final call = await sb
          .from('dm_calls')
          .select('conversation_id')
          .eq('id', widget.callId)
          .maybeSingle();
      final convId = call?['conversation_id'] as String?;
      if (convId == null) return;
      final me = SupabaseService.currentUser?.id;
      if (me == null) return;
      await sb.from('messages').insert({
        'conversation_id': convId,
        'sender_id': me,
        'content': '[SYSTEM_NOTE:$note]',
      });
    } catch (_) {/* fail-silent */}
  }

  @override
  Widget build(BuildContext context) {
    // Outgoing-Ringing-Sonder-UI: Avatar mit Pulse-Ring + Cancel-Button.
    if (_state == _CallState.outgoingRinging) {
      // 45s totale Klingelzeit, _ringingElapsed steigt um 1/s via Ticker.
      final remaining = (45 - _ringingElapsed).clamp(0, 45);
      return _OutgoingRingingView(
        peerName: widget.peerName,
        avatarUrl: _peerAvatarUrl,
        remainingSeconds: remaining,
        onCancel: _cancelOutgoing,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: Stack(
        children: [
          SafeArea(child: _buildBody()),
          // F11: Connection-Quality-Badge oben rechts (während Call aktiv).
          if (_state == _CallState.connected &&
              _quality != lk.ConnectionQuality.unknown)
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(child: _ConnectionQualityBadge(_quality)),
            ),
          // Floating-Reactions ueber dem Video/Avatar — andere Seite sieht
          // gesendete Reaktionen automatisch via Stream.
          Positioned.fill(
            child: FloatingReactionsLayer(controller: _reactionsCtrl),
          ),
          // Reaktions-Picker oben mittig
          if (_state == _CallState.connected)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: ReactionPickerBar(onPick: _sendReaction),
              ),
            ),
          if (_camEnabled && _room != null)
            Positioned(
              left: _camPreviewPos.dx,
              top: _camPreviewPos.dy,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    _camPreviewPos += d.delta;
                  });
                },
                child: _LocalCamPreview(room: _room!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
          children: [
            const SizedBox(height: 24),
            Text(
              widget.peerName,
              style: AppTypography.display(
                  size: 26, color: AppColors.ink, height: 1.2),
            ),
            const SizedBox(height: 6),
            // PERF (Audit): nur das Duration-Update rebuildet via
            // ValueListenableBuilder. Im connected-State liest der
            // Builder _stopwatch.elapsed beim Tick (1Hz) — der Rest
            // des Call-Screens bleibt stabil.
            ValueListenableBuilder<int>(
              valueListenable: _elapsedSec,
              builder: (_, __, ___) => Text(_subtitle(),
                  style: AppTypography.body(
                      size: 13, color: AppColors.inkSoft)),
            ),
            const Spacer(),
            // Wenn Remote-Video vorhanden: zeige Video. Sonst: großer Avatar.
            _PeerVideoOrAvatar(
              room: _room,
              peerName: widget.peerName,
              avatarUrl: _peerAvatarUrl,
            ),
            if (_state == _CallState.failed && _error != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                      size: 12, color: AppColors.herzrotWarm),
                ),
              ),
            ],
            const Spacer(),
            // Sekundär-Aktionen (wrapped, damit auf schmalen Geräten und in
            // jeder Sprache nichts überläuft). Vorher: 7 Buttons in einer
            // einzigen Row → Overflow auf kleinen Devices.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 10,
                children: [
                  _CircleAction(
                    icon: _camEnabled
                        ? LucideIcons.video
                        : LucideIcons.videoOff,
                    label: _camEnabled ? 'Cam aus' : 'Cam an',
                    color: _camEnabled
                        ? AppColors.bronze
                        : AppColors.mute,
                    onTap: _state == _CallState.connected ? _toggleCam : null,
                  ),
                  _CircleAction(
                    icon: _screenShareEnabled
                        ? LucideIcons.monitorOff
                        : LucideIcons.monitor,
                    label: _screenShareEnabled
                        ? 'call.screenShareOff'.tr()
                        : 'call.screenShareOn'.tr(),
                    color: _screenShareEnabled
                        ? AppColors.amber
                        : AppColors.mute,
                    onTap: _state == _CallState.connected
                        ? _toggleScreenShare
                        : null,
                  ),
                  _CircleAction(
                    icon: LucideIcons.minimize2,
                    label: 'call.minimize'.tr(),
                    color: AppColors.bronze,
                    onTap: _state == _CallState.connected
                        ? () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/dashboard');
                            }
                          }
                        : null,
                  ),
                  _CircleAction(
                    icon: LucideIcons.userPlus,
                    label: 'call.addParticipant'.tr(),
                    color: AppColors.leben,
                    onTap: _state == _CallState.connected
                        ? _addParticipant
                        : null,
                  ),
                ],
              ),
            ),
            // Primär-Bar: Mic — Auflegen (groß, mittig) — Lautsprecher.
            // Drei feste Slots, garantiert kein Overflow.
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 36),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleAction(
                    icon: _micEnabled
                        ? LucideIcons.mic
                        : LucideIcons.micOff,
                    label: _micEnabled ? 'Mute' : 'Unmute',
                    color: _micEnabled
                        ? AppColors.bronze
                        : AppColors.herzrotWarm,
                    onTap: _state == _CallState.connected ? _toggleMic : null,
                  ),
                  _CircleAction(
                    icon: LucideIcons.phoneOff,
                    label: 'Auflegen',
                    color: AppColors.herzrot,
                    big: true,
                    onTap: _hangUp,
                  ),
                  _CircleAction(
                    icon: _speakerOn
                        ? LucideIcons.volume2
                        : LucideIcons.volumeX,
                    label: _speakerOn ? 'Lautspr.' : 'Hörer',
                    color: _speakerOn ? AppColors.bronze : AppColors.mute,
                    onTap:
                        _state == _CallState.connected ? _toggleSpeaker : null,
                  ),
                ],
              ),
            ),
          ],
        );
  }

  /// Punkt 13: Öffnet ein Sheet mit Freunden und lädt die gewählte Person
  /// in den laufenden Call ein (klingelt bei ihr, gleicher LiveKit-Raum).
  Future<void> _addParticipant() async {
    // conversation_id + call_type aus der aktuellen Call-Row holen.
    String? convId;
    String callType = 'video';
    try {
      final row = await sb
          .from('dm_calls')
          .select('conversation_id, call_type')
          .eq('id', widget.callId)
          .maybeSingle();
      convId = row?['conversation_id'] as String?;
      callType = (row?['call_type'] as String?) ?? 'video';
    } catch (_) {}
    if (convId == null || !mounted) return;
    final cid = convId;
    // Globales User-Picker-Sheet: JEDEN einladbar, nicht nur Freunde.
    await UserPickerSheet.show(
      context,
      title: 'call.addParticipant'.tr(),
      pickedLabelKey: 'call.addRinging',
      failedLabelKey: 'call.addFailed',
      onPick: (id, _) async {
        final newId = await DmCallService.invite(
          roomName: widget.roomName,
          conversationId: cid,
          calleeId: id,
          callType: callType,
        );
        return newId != null;
      },
    );
  }

  String _subtitle() {
    switch (_state) {
      case _CallState.outgoingRinging:
        return 'call.calling'.tr();
      case _CallState.connecting:
        return 'Verbinde…';
      case _CallState.connected:
        return _formatDuration(_stopwatch.elapsed);
      case _CallState.reconnecting:
        return 'Verbindung wird wiederhergestellt…';
      case _CallState.ended:
        return 'call.callEnded'.tr();
      case _CallState.failed:
        return 'Verbindung fehlgeschlagen';
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─────────────────────────────────────────────────────────────
// OutgoingRingingView — WhatsApp-Style "Klingelt…" beim Anrufen
// ─────────────────────────────────────────────────────────────
class _OutgoingRingingView extends StatefulWidget {
  const _OutgoingRingingView({
    required this.peerName,
    required this.onCancel,
    required this.remainingSeconds,
    this.avatarUrl,
  });

  final String peerName;
  final String? avatarUrl;
  final int remainingSeconds;
  final VoidCallback onCancel;

  @override
  State<_OutgoingRingingView> createState() => _OutgoingRingingViewState();
}

class _OutgoingRingingViewState extends State<_OutgoingRingingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.peerName.isNotEmpty
        ? widget.peerName[0].toUpperCase()
        : '?';
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final scale = 1.0 + _pulse.value * 0.18;
                final opacity = 0.55 - _pulse.value * 0.35;
                return SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.bronze
                                  .withValues(alpha: opacity),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 160,
                        height: 160,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bronze.withValues(alpha: 0.18),
                          border:
                              Border.all(color: AppColors.bronze, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: widget.avatarUrl != null &&
                                widget.avatarUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Text(
                                  initial,
                                  style: AppTypography.display(
                                      size: 56, color: AppColors.bronze),
                                ),
                                errorWidget: (_, __, ___) => Text(
                                  initial,
                                  style: AppTypography.display(
                                      size: 56, color: AppColors.bronze),
                                ),
                              )
                            : Text(
                                initial,
                                style: AppTypography.display(
                                    size: 56, color: AppColors.bronze),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              widget.peerName,
              style: AppTypography.display(
                  size: 28, color: AppColors.ink, height: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'call.ringingCountdown'.tr(
                  namedArgs: {'n': '${widget.remainingSeconds}'}),
              style: AppTypography.body(
                size: 14,
                color: widget.remainingSeconds < 10
                    ? AppColors.herzrot
                    : AppColors.inkSoft,
                weight: widget.remainingSeconds < 10
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 56),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: widget.onCancel,
                    borderRadius: BorderRadius.circular(72),
                    child: Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.herzrot.withValues(alpha: 0.22),
                        border:
                            Border.all(color: AppColors.herzrot, width: 2),
                      ),
                      child: const Icon(LucideIcons.phoneOff,
                          color: AppColors.herzrot, size: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'call.cancelCall'.tr(),
                    style: AppTypography.label(
                        size: 11, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 72.0 : 60.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
            ),
            child: Icon(icon, color: color, size: big ? 28 : 22),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: AppTypography.label(size: 10, color: AppColors.inkSoft)),
      ],
    );
  }
}

// ── PeerVideoOrAvatar — zeigt Remote-Video oder großen Avatar ──────
class _PeerVideoOrAvatar extends StatefulWidget {
  const _PeerVideoOrAvatar({
    required this.room,
    required this.peerName,
    required this.avatarUrl,
  });

  final lk.Room? room;
  final String peerName;
  final String? avatarUrl;

  @override
  State<_PeerVideoOrAvatar> createState() => _PeerVideoOrAvatarState();
}

class _PeerVideoOrAvatarState extends State<_PeerVideoOrAvatar> {
  lk.EventsListener<lk.RoomEvent>? _listener;
  // Sprecher-Aura: wenn peer-Participant gerade spricht, bekommt der Avatar
  // einen pulsierenden Bronze-Glow (via PulseBloom-Intensity).
  bool _peerSpeaking = false;

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    if (r != null) {
      _listener = r.createListener()
        ..on<lk.TrackSubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackUnsubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackMutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackUnmutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.ActiveSpeakersChangedEvent>((ev) {
          if (!mounted) return;
          final remoteSpeaking = ev.speakers.any(
              (p) => p.identity != r.localParticipant?.identity);
          if (remoteSpeaking != _peerSpeaking) {
            setState(() => _peerSpeaking = remoteSpeaking);
          }
        });
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  lk.VideoTrack? _findPeerVideo() {
    final r = widget.room;
    if (r == null) return null;
    for (final p in r.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        if (pub.muted || !pub.subscribed) continue;
        final t = pub.track;
        if (t is lk.VideoTrack) return t;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final video = _findPeerVideo();
    if (video != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 240,
          height: 320,
          child: lk.VideoTrackRenderer(
            video,
            fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      );
    }
    final initial = widget.peerName.isNotEmpty
        ? widget.peerName[0].toUpperCase()
        : '?';
    // Wenn peer spricht: Glow staerker, sonst dezent.
    return PulseBloom(
      color: AppColors.bronze,
      radius: _peerSpeaking ? 56 : 38,
      minIntensity: _peerSpeaking ? 0.7 : 0.4,
      maxIntensity: _peerSpeaking ? 1.0 : 0.8,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bronze.withValues(alpha: 0.22),
          border: Border.all(
            color: AppColors.bronze.withValues(alpha: 0.55),
            width: 3,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _initial(initial),
                errorWidget: (_, __, ___) => _initial(initial),
              )
            : _initial(initial),
      ),
    );
  }

  Widget _initial(String letter) => Container(
        color: AppColors.bronze.withValues(alpha: 0.18),
        alignment: Alignment.center,
        child: Text(letter,
            style:
                AppTypography.display(size: 72, color: AppColors.bronze)),
      );
}

// ── LocalCamPreview — eigenes Kamerabild als kleines draggable Tile ──
class _LocalCamPreview extends StatefulWidget {
  const _LocalCamPreview({required this.room});
  final lk.Room room;

  @override
  State<_LocalCamPreview> createState() => _LocalCamPreviewState();
}

class _LocalCamPreviewState extends State<_LocalCamPreview> {
  lk.EventsListener<lk.RoomEvent>? _listener;

  @override
  void initState() {
    super.initState();
    _listener = widget.room.createListener()
      ..on<lk.LocalTrackPublishedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<lk.LocalTrackUnpublishedEvent>((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  lk.VideoTrack? _findLocalVideo() {
    final lp = widget.room.localParticipant;
    if (lp == null) return null;
    for (final pub in lp.videoTrackPublications) {
      final t = pub.track;
      if (t is lk.VideoTrack) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final video = _findLocalVideo();
    if (video == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bronze.withValues(alpha: 0.5)),
        ),
        child: lk.VideoTrackRenderer(
          video,
          fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          mirrorMode: lk.VideoViewMirrorMode.mirror,
        ),
      ),
    );
  }
}


/// F11: Connection-Quality-Badge.
class _ConnectionQualityBadge extends StatelessWidget {
  const _ConnectionQualityBadge(this.quality);
  final lk.ConnectionQuality quality;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (quality) {
      lk.ConnectionQuality.excellent => (
          AppColors.leben,
          LucideIcons.signal,
          'call.qualityExcellent'.tr()
        ),
      lk.ConnectionQuality.good => (
          AppColors.amber,
          LucideIcons.signal,
          'call.qualityGood'.tr()
        ),
      lk.ConnectionQuality.poor => (
          AppColors.herzrotWarm,
          LucideIcons.signalLow,
          'call.qualityPoor'.tr()
        ),
      _ => (AppColors.mute, LucideIcons.signalZero, '')
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.voidColor.withValues(alpha: 0.65),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: AppTypography.label(size: 9, color: color)),
      ]),
    );
  }
}
