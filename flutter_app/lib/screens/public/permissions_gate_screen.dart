/// SKILL: mensaena-features
/// Vollbild-Permission-Gate, der nach Login erscheint und sich nicht
/// wegdrücken lässt, bis jede Berechtigung entweder erteilt oder
/// 3 × abgefragt wurde (danach gilt sie als „nur via Einstellungen").
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/permissions_gate.dart';
import '../../widgets/shared/battery_optimization_prompt.dart';
import '../../widgets/shared/permission_rationale_sheet.dart';

class PermissionsGateScreen extends StatefulWidget {
  const PermissionsGateScreen({super.key});

  @override
  State<PermissionsGateScreen> createState() => _PermissionsGateScreenState();
}

class _PermissionsGateScreenState extends State<PermissionsGateScreen>
    with WidgetsBindingObserver {
  List<GateState> _states = const [];
  final Set<String> _busy = <String>{};
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nach Rückkehr aus den System-Einstellungen Status neu lesen.
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final states = await PermissionsGate.currentStates();
    if (!mounted) return;
    setState(() {
      _states = states;
      _ready = true;
    });
  }

  /// User tippt auf die Aktion eines Items — zeigt Rationale, danach das
  /// System-Dialog (oder die Custom-Action). Bei nicht-permanenten Verweigerungen
  /// erhöht es den Attempt-Zähler.
  Future<void> _onAction(GateState s) async {
    if (_busy.contains(s.item.key)) return;
    final item = s.item;

    // Exhausted ODER permanently denied → direkt in die App-Einstellungen,
    // weil Android weder das System-Dialog noch unsere Action mehr zulässt.
    if (s.isExhausted ||
        s.status.isPermanentlyDenied ||
        s.status.isRestricted) {
      setState(() => _busy.add(item.key));
      try {
        // Für den Battery-Eintrag den Samsung-2-Schritte-Flow nutzen.
        if (item.key == 'battery') {
          await showBatteryOptimizationSetup(context);
        } else {
          await openAppSettings();
        }
      } catch (_) {} finally {
        if (mounted) setState(() => _busy.remove(item.key));
      }
      await _refresh();
      return;
    }

    // Rationale vor dem System-Dialog — User wei0 worum's geht.
    final cont = await showPermissionRationale(context, item.rationale);
    if (!cont || !mounted) return;

    setState(() => _busy.add(item.key));
    var didAttempt = false;
    try {
      if (item.customAction != null) {
        didAttempt = await item.customAction!();
      } else if (item.permission != null) {
        await item.permission!.request();
        didAttempt = true;
      }
    } catch (_) {/* non-fatal */}

    if (didAttempt) {
      await PermissionsGate.recordAttempt(item.key);
    }
    await _refresh();
    if (mounted) setState(() => _busy.remove(item.key));
  }

  Future<void> _onFinish() async {
    // Sicherheits-Refresh: vielleicht hat der User in den App-Einstellungen
    // zwischendurch etwas erteilt.
    await _refresh();
    if (!mounted) return;
    if (_states.any((s) => s.blocksGate)) return;
    // Gate erfolgreich abgeschlossen → Dashboard.
    context.go('/dashboard');
  }

  bool get _allDone => !_states.any((s) => s.blocksGate);
  bool get _hasExhaustedMissing => _states.any((s) => s.isExhausted);

  @override
  Widget build(BuildContext context) {
    // PopScope canPop: false → System-Back-Geste / Hardware-Back fängt nicht.
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.voidColor,
          body: SafeArea(
            child: !_ready
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.bronze),
                  )
                : Column(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(22, 22, 22, 10),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  AppColors.bronze
                                      .withValues(alpha: 0.34),
                                  AppColors.bronze
                                      .withValues(alpha: 0.08),
                                ]),
                              ),
                              child: const Icon(LucideIcons.shieldCheck,
                                  color: AppColors.bronze, size: 26),
                            ),
                            const SizedBox(height: 14),
                            Text('permissions.gate.title'.tr(),
                                style: AppTypography.display(
                                    size: 24,
                                    color: AppColors.ink)),
                            const SizedBox(height: 8),
                            Text(
                              'permissions.gate.subtitle'.tr(),
                              style: AppTypography.body(
                                  size: 13.5,
                                  color: AppColors.inkSoft,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              16, 12, 16, 14),
                          itemCount: _states.length,
                          itemBuilder: (_, i) => _GateTile(
                            state: _states[i],
                            busy: _busy.contains(_states[i].item.key),
                            onAction: () => _onAction(_states[i]),
                          ),
                        ),
                      ),
                      if (_hasExhaustedMissing)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              22, 0, 22, 8),
                          child: Text(
                            'permissions.gate.exhaustedHint'.tr(),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                                size: 12,
                                color: AppColors.amber
                                    .withValues(alpha: 0.85),
                                height: 1.45),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            22, 4, 22, 18),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _allDone ? _onFinish : null,
                            icon: Icon(
                                _allDone
                                    ? LucideIcons.checkCircle2
                                    : LucideIcons.lock,
                                size: 18),
                            label: Text(
                              _allDone
                                  ? 'permissions.gate.continue'.tr()
                                  : 'permissions.gate.continueLocked'
                                      .tr(),
                              style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.voidColor,
                                  weight: FontWeight.w700),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.bronze,
                              foregroundColor: AppColors.voidColor,
                              disabledBackgroundColor: AppColors
                                  .bronze
                                  .withValues(alpha: 0.18),
                              disabledForegroundColor: AppColors
                                  .inkSoft
                                  .withValues(alpha: 0.6),
                              minimumSize:
                                  const Size.fromHeight(52),
                            ),
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

class _GateTile extends StatelessWidget {
  const _GateTile({
    required this.state,
    required this.busy,
    required this.onAction,
  });

  final GateState state;
  final bool busy;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final granted = state.isGranted;
    final exhausted = state.isExhausted;
    final permanentlyDenied = state.status.isPermanentlyDenied ||
        state.status.isRestricted;
    final accent = granted
        ? AppColors.leben
        : exhausted
            ? AppColors.amber
            : AppColors.bronze;
    final actionLabel = granted
        ? 'permissions.gate.statusGranted'.tr()
        : (exhausted || permanentlyDenied)
            ? 'permissions.gate.actionSettings'.tr()
            : state.attempts == 0
                ? 'permissions.gate.actionGrant'.tr()
                : 'permissions.gate.actionRetry'.tr();
    final attemptsLeft =
        kPermissionsGateMaxAttempts - state.attempts;
    final attemptsHint = (!granted && !exhausted && state.attempts > 0)
        ? (attemptsLeft == 1
            ? 'permissions.gate.attemptLast'.tr()
            : 'permissions.gate.attemptsRemaining'
                .tr(namedArgs: {'n': '$attemptsLeft'}))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(state.item.icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.item.labelKey.tr(),
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(state.item.descKey.tr(),
                    style: AppTypography.body(
                        size: 12,
                        color: AppColors.inkSoft,
                        height: 1.4)),
                if (attemptsHint != null) ...[
                  const SizedBox(height: 4),
                  Text(attemptsHint,
                      style: AppTypography.label(
                          size: 10,
                          color: AppColors.amber
                              .withValues(alpha: 0.85))),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: granted
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.leben
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.checkCircle2,
                                  size: 14, color: AppColors.leben),
                              const SizedBox(width: 6),
                              Text(actionLabel,
                                  style: AppTypography.body(
                                      size: 12,
                                      color: AppColors.leben,
                                      weight: FontWeight.w700)),
                            ],
                          ),
                        )
                      : FilledButton(
                          onPressed: busy ? null : onAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: AppColors.voidColor,
                            minimumSize: const Size.fromHeight(40),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.voidColor,
                                  ),
                                )
                              : Text(actionLabel,
                                  style: AppTypography.body(
                                      size: 13,
                                      color: AppColors.voidColor,
                                      weight: FontWeight.w700)),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
