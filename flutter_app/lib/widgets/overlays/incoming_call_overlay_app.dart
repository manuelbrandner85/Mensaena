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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

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
    _sub = FlutterOverlayWindow.overlayListener.listen(_handleMessage);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
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
    // Main-Isolate informieren — der weiß, wie er die App in den Vordergrund
    // bringt und den Call-Screen aufmacht.
    try {
      await FlutterOverlayWindow.shareData({
        'type': 'overlay_action',
        'action': 'accept',
        'callId': _callId,
      });
    } catch (_) {}
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  Future<void> _onDecline() async {
    HapticFeedback.selectionClick();
    try {
      await FlutterOverlayWindow.shareData({
        'type': 'overlay_action',
        'action': 'decline',
        'callId': _callId,
      });
    } catch (_) {}
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: AppColors.voidColor,
        child: SafeArea(
          child: Stack(
            children: [
              // Hintergrund-Glow.
              Positioned(
                top: -size.width * 0.3,
                left: -size.width * 0.25,
                child: Container(
                  width: size.width * 1.4,
                  height: size.width * 1.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.bronze.withValues(alpha: 0.18),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 60, 32, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _labelIncoming.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppTypography.label(
                        size: 11,
                        color: AppColors.bronze,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _callType == 'video' ? 'Video' : 'Audio',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        size: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const Spacer(),
                    // Pulsierende Ringe + Avatar.
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) {
                        final t = _pulse.value;
                        return SizedBox(
                          height: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              for (var i = 0; i < 3; i++)
                                _pulseRing(t, i),
                              _avatar(),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _callerName.isEmpty ? '...' : _callerName,
                      textAlign: TextAlign.center,
                      style: AppTypography.display(
                        size: 28,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RoundAction(
                          icon: Icons.call_end,
                          color: AppColors.herzrot,
                          label: _labelDecline,
                          onTap: _onDecline,
                        ),
                        _RoundAction(
                          icon: Icons.call,
                          color: AppColors.leben,
                          label: _labelAccept,
                          onTap: _onAccept,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pulseRing(double t, int i) {
    final phase = ((t + i * 0.33) % 1.0);
    final size = 120.0 + phase * 100.0;
    final opacity = (1.0 - phase) * 0.4;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.bronze.withValues(alpha: opacity),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    final initial = _callerName.trim().isEmpty
        ? '?'
        : _callerName.trim().substring(0, 1).toUpperCase();
    final hasAvatar = _callerAvatar != null && _callerAvatar!.isNotEmpty;
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.bronze.withValues(alpha: 0.7),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bronze.withValues(alpha: 0.35),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      child: hasAvatar
          ? ClipOval(
              child: Image.network(
                _callerAvatar!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackInitial(initial),
              ),
            )
          : _fallbackInitial(initial),
    );
  }

  Widget _fallbackInitial(String c) {
    return Center(
      child: Text(
        c,
        style: AppTypography.display(size: 48, color: AppColors.bronze),
      ),
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
