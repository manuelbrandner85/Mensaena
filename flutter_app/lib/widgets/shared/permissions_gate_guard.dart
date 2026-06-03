/// SKILL: mensaena-features
/// Post-Login-Guard: prüft beim ersten Mount UND bei jedem Login, ob der
/// Permissions-Gate-Screen angezeigt werden muss. Bei "alle erteilt oder
/// 3 × erschöpft, mind. eine noch nicht erteilt" zeigt es einmal pro
/// Session einen unaufdringlichen Hinweis-Snackbar.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../../config/routes/app_router.dart' show rootNavigatorKey;
import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/permissions_gate.dart';
import '../../services/supabase_service.dart';

class PermissionsGateGuard extends ConsumerStatefulWidget {
  const PermissionsGateGuard({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PermissionsGateGuard> createState() =>
      _PermissionsGateGuardState();
}

class _PermissionsGateGuardState extends ConsumerState<PermissionsGateGuard> {
  StreamSubscription<dynamic>? _authSub;
  Timer? _initialCheck;
  // SessionId für „Hint pro Session nur einmal" — wechselt bei Login/Logout.
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    // Erste Prüfung erst kurz nach App-Start, damit Router gemountet ist.
    _initialCheck = Timer(const Duration(seconds: 3), _checkAndShow);
    _authSub = sb.auth.onAuthStateChange.listen((evt) {
      if (evt.event == AuthChangeEvent.signedIn) {
        _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        // Beim frischen Login Attempt-Zähler nicht zurücksetzen — sie sollen
        // pro Gerät weiterleben, nicht pro Konto. Direkt zum Gate.
        Timer(const Duration(milliseconds: 800), _checkAndShow);
      } else if (evt.event == AuthChangeEvent.signedOut) {
        _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      }
    });
  }

  @override
  void dispose() {
    _initialCheck?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAndShow() async {
    if (!mounted) return;
    if (!SupabaseService.isLoggedIn) return;
    try {
      final needsGate = await PermissionsGate.shouldShowGate();
      if (!mounted) return;
      if (needsGate) {
        final nav = rootNavigatorKey.currentState;
        final ctx = nav?.context;
        if (ctx != null && ctx.mounted) {
          final loc =
              GoRouter.of(ctx).routerDelegate.currentConfiguration.uri.path;
          // Nicht doppelt pushen wenn Gate schon offen ist.
          if (loc != '/gate') {
            ctx.push('/gate');
          }
        }
        return;
      }
      // Kein Gate nötig, aber vielleicht "settings-only"-Reste vorhanden →
      // einmal pro Session dezent darauf hinweisen.
      final hint =
          await PermissionsGate.shouldShowSettingsHint(_sessionId);
      if (!mounted || !hint) return;
      final ctx = rootNavigatorKey.currentState?.context;
      if (ctx == null || !ctx.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      messenger?.showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 6),
        content: Text(
          'permissions.gate.snackbarHint'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
    } catch (_) {/* non-fatal: Gate bleibt einfach aus */}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
