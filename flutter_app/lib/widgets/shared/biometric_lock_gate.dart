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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockStatus(promptImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLockStatus(promptImmediately: true);
    }
  }

  Future<void> _checkLockStatus({bool promptImmediately = false}) async {
    final shouldLock = await BiometricService.shouldLock();
    if (!mounted) return;
    setState(() {
      _locked = shouldLock;
      _checked = true;
    });
    if (shouldLock && promptImmediately) {
      // Nicht sofort — UI muss erst gemounted sein.
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
