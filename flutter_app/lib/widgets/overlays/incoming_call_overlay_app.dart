/// SKILL: mensaena-features
/// Vollbild-Anruf-Overlay, das via SYSTEM_ALERT_WINDOW über jede App
/// gezeichnet wird — auch wenn die Mensaena-App geschlossen ist und
/// Samsung One UI eigentlich nur eine Heads-up-Notification zeigen würde.
///
/// WICHTIG: Dieser Code läuft in einer eigenen Flutter-Isolate. Er hat
/// KEINEN Zugriff auf Riverpod-Provider, Supabase, easy_localization etc.
/// Alle Labels und Anrufer-Daten kommen via `FlutterOverlayWindow.shareData`
/// vom Main-Isolate. Aktionen (Annehmen/Ablehnen) gehen denselben Weg zurück.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../config/theme/cinema_theme.dart' show LightLeakSpot;
import '../effects/atmospheric_layers.dart';
import '../effects/bloom.dart';
import '../effects/film_grain.dart';
import '../effects/light_leaks.dart';
import '../effects/vignette.dart';

/// Shared zwischen Overlay-Isolate und Main-Isolate: kleiner Brückenspeicher
/// für „User hat im Overlay angenommen/abgelehnt, Main soll's übernehmen".
/// Same Process = same EncryptedSharedPreferences, beide Isolates sehen es.
const String kOverlayPendingActionKey =
    'mensaena_overlay_pending_action_v1';

/// Vom Main-Isolate via overlay registriert (`@pragma('vm:entry-point')`).
/// Liest die Anrufer-Daten vom Listener-Stream und rendert den Vollbild-Screen.
@pragma('vm:entry-point')
void incomingCallOverlayEntry() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _IncomingCallOverlayApp());
}

class _IncomingCallOverlayApp extends StatelessWidget {
  const _IncomingCallOverlayApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const IncomingCallOverlayRoot(),
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
    );
  }
}

/// Public damit auch das Main-Isolate die Klasse referenzieren kann
/// (Tree-Shaking-Hinweis fürs Kompilieren).
class IncomingCallOverlayRoot extends StatefulWidget {
  const IncomingCallOverlayRoot({super.key});

  @override
  State<IncomingCallOverlayRoot> createState() =>
      _IncomingCallOverlayRootState();
}

class _IncomingCallOverlayRootState extends State<IncomingCallOverlayRoot>
    with TickerProviderStateMixin {
  StreamSubscription<dynamic>? _sub;
  late final AnimationController _pulse;
  // Intro-Controller: letterbox-Bars und Hero-Reveal in den ersten 400 ms.
  late final AnimationController _intro;

  // Daten vom Main-Isolate.
  String _callerName = '';
  String? _callerAvatar;
  String _callType = 'audio';
  String _callId = '';
  // Lokalisierte Labels.
  String _labelIncoming = 'Eingehender Anruf';
  String _labelAccept = 'Annehmen';
  String _labelDecline = 'Ablehnen';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _sub = FlutterOverlayWindow.overlayListener.listen(_handleMessage);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
    _intro.dispose();
    super.dispose();
  }

  void _handleMessage(dynamic raw) {
    if (raw is! Map) return;
    final type = raw['type'];
    if (type != 'incoming') return;
    if (!mounted) return;
    setState(() {
      _callerName = (raw['callerName'] as String?) ?? _callerName;
      _callerAvatar = raw['callerAvatar'] as String?;
      _callType = (raw['callType'] as String?) ?? _callType;
      _callId = (raw['callId'] as String?) ?? _callId;
      _labelIncoming = (raw['labelIncoming'] as String?) ?? _labelIncoming;
      _labelAccept = (raw['labelAccept'] as String?) ?? _labelAccept;
      _labelDecline = (raw['labelDecline'] as String?) ?? _labelDecline;
    });
  }

  Future<void> _onAccept() async {
    HapticFeedback.selectionClick();
    await _signalAction('accept');
    // Wenn das Main-Isolate lebt, fängt es das shareData-Event direkt ab.
    // Wenn nicht, schreiben wir die Aktion zusätzlich in SecureStorage und
    // starten MainActivity per Intent — der Boot liest die SecureStorage-
    // Brücke und führt den Accept aus.
    await _persistPendingAction('accept');
    await _launchMainApp();
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  Future<void> _onDecline() async {
    HapticFeedback.selectionClick();
    await _signalAction('decline');
    await _persistPendingAction('decline');
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  Future<void> _signalAction(String action) async {
    try {
      await FlutterOverlayWindow.shareData(<String, dynamic>{
        'type': 'overlay_action',
        'action': action,
        'callId': _callId,
      });
    } catch (_) {/* non-fatal */}
  }

  Future<void> _persistPendingAction(String action) async {
    try {
      const storage = FlutterSecureStorage();
      await storage.write(
        key: kOverlayPendingActionKey,
        value: '$action:$_callId',
      );
    } catch (_) {/* non-fatal */}
  }

  Future<void> _launchMainApp() async {
    try {
      // ignore: prefer_const_constructors
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'de.mensaena.app',
        componentName: 'de.mensaena.app/.MainActivity',
        flags: const <int>[
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
          Flag.FLAG_ACTIVITY_SINGLE_TOP,
        ],
      );
      await intent.launch();
    } catch (_) {/* non-fatal: User kann CallKit-Notification antippen */}
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: AppColors.voidColor,
        child: Stack(
          children: [
            // ── 1. Atmosphere: Haze + Light-Leaks + Vignette + Grain ───
            const Positioned.fill(
              child: AtmosphericHaze(
                topColor: AppColors.bronze,
                bottomColor: AppColors.herzrotDeep,
                intensity: 0.6,
              ),
            ),
            const Positioned.fill(
              child: LightLeaksOverlay(
                intensity: 0.45,
                spots: <LightLeakSpot>[
                  LightLeakSpot(
                    alignment: Alignment(-0.85, -0.6),
                    color: AppColors.bronze,
                    radius: 240,
                    opacity: 0.35,
                    pulse: true,
                  ),
                  LightLeakSpot(
                    alignment: Alignment(0.9, 0.5),
                    color: AppColors.herzrotWarm,
                    radius: 280,
                    opacity: 0.22,
                    pulse: true,
                  ),
                ],
              ),
            ),
            const Positioned.fill(child: VignetteOverlay(intensity: 0.55)),
            const Positioned.fill(child: FilmGrainOverlay(opacity: 0.04)),
            // ── 2. Letterbox-Bars (Netflix-Style) — gleiten in den ersten ───
            //      ~250 ms in den Screen.
            _LetterboxBar(
              alignment: Alignment.topCenter,
              animation: _intro,
            ),
            _LetterboxBar(
              alignment: Alignment.bottomCenter,
              animation: _intro,
            ),
            // ── 3. Content ──────────────────────────────────────────────
            SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: _onVerticalDrag,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(28, 30, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mensaena-Watermark
                      Center(
                        child: Text(
                          'Mensaena',
                          style: AppTypography.display(
                            size: 13,
                            color: AppColors.bronze
                                .withValues(alpha: 0.55),
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Text(
                          _labelIncoming.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: AppTypography.label(
                            size: 11,
                            color: AppColors.bronze,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: _CallTypePill(callType: _callType),
                      ),
                      const Spacer(),
                      // Radar-Pings + Sweep-Ring + Avatar
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) {
                          final t = _pulse.value;
                          return SizedBox(
                            height: 280,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                for (var i = 0; i < 5; i++)
                                  _radarPing(t, i),
                                _sweepRing(t),
                                _avatar(),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      // Caller-Name (Hero-Display + Bronze-Underglow)
                      Center(
                        child: Text(
                          _callerName.isEmpty ? '...' : _callerName,
                          textAlign: TextAlign.center,
                          style: AppTypography.display(
                            size: 36,
                            color: AppColors.ink,
                            shadows: [
                              Shadow(
                                color: AppColors.bronze
                                    .withValues(alpha: 0.45),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          _RoundAction(
                            icon: Icons.call_end,
                            color: AppColors.herzrot,
                            label: _labelDecline,
                            onTap: _onDecline,
                          ),
                          _AcceptAction(
                            label: _labelAccept,
                            onTap: _onAccept,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          // Subtiler Swipe-Hinweis. Sprachunabhängig (Pfeile).
                          '↓ ablehnen   ·   annehmen ↑',
                          style: AppTypography.label(
                            size: 10,
                            color: AppColors.inkSoft
                                .withValues(alpha: 0.55),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Expandierende Radar-Pings (5 Stück, gestaffelt).
  Widget _radarPing(double t, int i) {
    final phase = ((t + i * 0.2) % 1.0);
    final size = 130.0 + phase * 180.0;
    final opacity = (1.0 - phase) * 0.6;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.bronze.withValues(alpha: opacity * 0.9),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  /// Rotierender Gold-Ring (SweepGradient) direkt um den Avatar.
  Widget _sweepRing(double t) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: t * math.pi * 2,
        child: Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                AppColors.bronze.withValues(alpha: 0.0),
                AppColors.bronze.withValues(alpha: 0.85),
                AppColors.bronzeSoft.withValues(alpha: 0.6),
                AppColors.bronze.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
            ),
          ),
          // Inner Mask: hohler Ring durch zentralen voidColor-Punkt
          child: Center(
            child: Container(
              width: 192,
              height: 192,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.voidColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Swipe-Geste: ↑ Annehmen, ↓ Ablehnen ──────────────────────────────
  void _onVerticalDrag(DragEndDetails d) {
    final vy = d.primaryVelocity ?? 0;
    if (vy < -800) {
      _onAccept();
    } else if (vy > 800) {
      _onDecline();
    }
  }

  Widget _avatar() {
    final initial = _callerName.trim().isEmpty
        ? '?'
        : _callerName.trim().substring(0, 1).toUpperCase();
    final hasAvatar = _callerAvatar != null && _callerAvatar!.isNotEmpty;
    return Bloom(
      color: AppColors.bronze,
      intensity: 0.85,
      radius: 32,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(
            color: AppColors.bronze.withValues(alpha: 0.85),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: hasAvatar
              ? Image.network(
                  _callerAvatar!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackInitial(initial),
                )
              : _fallbackInitial(initial),
        ),
      ),
    );
  }

  Widget _fallbackInitial(String c) {
    return Center(
      child: Text(
        c,
        style: AppTypography.display(size: 68, color: AppColors.bronze),
      ),
    );
  }
}

/// Schmale Cinema-Letterbox-Bar oben/unten — gleitet in den ersten ~420 ms
/// in den Screen (Netflix-Style-Intro).
class _LetterboxBar extends StatelessWidget {
  const _LetterboxBar({required this.alignment, required this.animation});
  final AlignmentGeometry alignment;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          final t = Curves.easeOutCubic.transform(animation.value);
          return Container(
            width: double.infinity,
            height: 32 * t,
            color: Colors.black,
          );
        },
      ),
    );
  }
}

class _CallTypePill extends StatelessWidget {
  const _CallTypePill({required this.callType});
  final String callType;

  @override
  Widget build(BuildContext context) {
    final isVideo = callType == 'video';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bronze.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isVideo ? Icons.videocam : Icons.call,
              size: 11, color: AppColors.bronze),
          const SizedBox(width: 6),
          Text(
            isVideo ? 'Video' : 'Audio',
            style: AppTypography.label(
              size: 10,
              color: AppColors.bronze,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Variante des Accept-Buttons mit konstantem grünen Bloom + leichtem
/// Scale-Heartbeat — visueller Magnet für den Daumen.
class _AcceptAction extends StatefulWidget {
  const _AcceptAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_AcceptAction> createState() => _AcceptActionState();
}

class _AcceptActionState extends State<_AcceptAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hb;

  @override
  void initState() {
    super.initState();
    _hb = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _hb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _hb,
          builder: (_, __) {
            final s = 1.0 + 0.05 * _hb.value;
            return Transform.scale(
              scale: s,
              child: Bloom(
                color: AppColors.leben,
                intensity: 0.95,
                radius: 36,
                child: InkResponse(
                  onTap: widget.onTap,
                  radius: 60,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.leben,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.leben.withValues(alpha: 0.55),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.call,
                        color: Colors.white, size: 38),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          widget.label,
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 50,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Transform.rotate(
              angle: icon == Icons.call_end ? math.pi / 2 + 0.4 : 0,
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ],
    );
  }
}
