/// SKILL: mensaena-features + mensaena-design
/// BiometricLockGate (F15) — Vollbild-Overlay solange der User die App
/// noch nicht via Fingerprint/Face entsperrt hat. Beobachtet Lifecycle:
/// nach Background > 3min wird der Lock wieder aktiv.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/biometric_service.dart';
import '../effects/bloom.dart';

class BiometricLockGate extends StatefulWidget {
  const BiometricLockGate({required this.child, super.key});

  final Widget child;

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _busy = false;
  bool _checked = false;

  /// CRITICAL: verhindert Endlos-Loop wenn der Biometric-Prompt die App
  /// pausiert. Ohne dieses Flag triggert jeder Lifecycle 'resumed' einen
  /// neuen Prompt — der User cancelt → resumed → Prompt → cancelt → ∞ →
  /// Crash. Wir prompten nur einmal pro App-Session beim ersten Mount.
  bool _autoPromptDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // BUGFIX: KEIN promptImmediately mehr — der native Biometric-Prompt
    // setzt die App auf paused, der Resume triggert wieder den Prompt → ∞.
    // User sieht Lock-Screen und tappt selbst auf 'Entsperren' wenn er
    // bereit ist. Das ist auch UX-konform (iOS macht es genau so).
    _checkLockStatus(promptImmediately: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // BUGFIX (Crash-Loop): Bei Resume nur shouldLock prüfen, KEINEN
      // Auto-Prompt mehr triggern. Wenn die App nach Background-Timeout
      // wieder gesperrt ist, sieht der User den Lock-Screen und tappt
      // selbst auf "Entsperren" — sonst loopen wir mit dem nativen
      // Biometric-Prompt (jeder Prompt-Open setzt die App auf paused,
      // jeder Prompt-Close auf resumed → unendliche Re-Auth).
      _checkLockStatus(promptImmediately: false);
    } else if (state == AppLifecycleState.paused) {
      // Wenn die App pausiert wird (User schickt sie in Background ODER
      // System öffnet einen anderen Activity wie das Biometric-Sheet),
      // reset _autoPromptDone NICHT — das wäre wieder der Loop.
    }
  }

  Future<void> _checkLockStatus({bool promptImmediately = false}) async {
    final shouldLock = await BiometricService.shouldLock();
    if (!mounted) return;
    setState(() {
      _locked = shouldLock;
      _checked = true;
    });
    // Auto-Prompt nur EINMAL pro Mount + nur wenn explizit gewollt.
    if (shouldLock && promptImmediately && !_autoPromptDone) {
      _autoPromptDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
    }
  }

  Future<void> _tryUnlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await BiometricService.authenticate(
      reason: 'biometric.lockReason'.tr(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_locked) return widget.child;
    return Material(
      color: AppColors.voidColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Bloom(
                  color: AppColors.bronze,
                  intensity: 0.6,
                  radius: 24,
                  child: Icon(LucideIcons.fingerprint,
                      size: 72, color: AppColors.bronze),
                ),
                const SizedBox(height: 28),
                Text('biometric.lockTitle'.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.display(
                        size: 22, color: AppColors.ink)),
                const SizedBox(height: 10),
                Text(
                  'biometric.lockHint'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.inkSoft,
                      height: 1.5),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _tryUnlock,
                    icon: const Icon(LucideIcons.fingerprint, size: 18),
                    label: Text('biometric.unlock'.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.bronze,
                      foregroundColor: AppColors.voidColor,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
