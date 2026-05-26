/// SKILL: mensaena-features (Dashboard-Edit)
/// 1x-pro-User Onboarding-Tooltip — "long-press fürs Bearbeiten".
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class DashboardOnboardingTooltip extends StatefulWidget {
  const DashboardOnboardingTooltip({super.key});

  @override
  State<DashboardOnboardingTooltip> createState() =>
      _DashboardOnboardingTooltipState();
}

class _DashboardOnboardingTooltipState
    extends State<DashboardOnboardingTooltip> {
  static const _storage = FlutterSecureStorage();
  static const _flagKey = 'mensaena_dashboard_onboarding_v1';

  bool _shouldShow = false;
  bool _visible = false;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _maybeShow();
  }

  Future<void> _maybeShow() async {
    try {
      final seen = await _storage.read(key: _flagKey);
      if (seen == 'true' || !mounted) return;
      setState(() => _shouldShow = true);
      // 500ms Delay, dann fade-in
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _visible = true);
      _autoDismiss = Timer(const Duration(seconds: 8), _dismiss);
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    _autoDismiss?.cancel();
    if (!mounted) return;
    setState(() => _visible = false);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() => _shouldShow = false);
    try {
      await _storage.write(key: _flagKey, value: 'true');
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _dismiss,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: AppColors.bronze.withValues(alpha: 0.15),
            border: Border.all(
                color: AppColors.bronze.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(LucideIcons.lightbulb,
                size: 18, color: AppColors.bronze),
            const SizedBox(width: 10),
            Expanded(
              child: Text('dashboard.edit.onboarding'.tr(),
                  style: AppTypography.body(
                      size: 12, color: AppColors.ink, height: 1.4)),
            ),
            TextButton(
              onPressed: _dismiss,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.bronze,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text('dashboard.edit.onboarding_ok'.tr()),
            ),
          ]),
        ),
      ),
    );
  }
}
