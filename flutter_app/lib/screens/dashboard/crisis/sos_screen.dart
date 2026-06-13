import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/emergency_alert.dart';
import '../../../providers/emergency_provider.dart';
import '../../../repositories/emergency_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../widgets/shared/location_map_view.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  String _selectedType = 'medical';
  bool _sending = false;
  EmergencyAlert? _myAlert;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendSos() async {
    if (_sending) return;
    setState(() => _sending = true);
    HapticService.heavy();

    try {
      final pos = await LocationService.getCurrentPosition();
      final userId = sb.auth.currentUser?.id ?? '';
      final alert = await EmergencyRepository.createAlert(
        userId: userId,
        alertType: _selectedType,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      if (!mounted) return;
      if (alert != null) {
        setState(() => _myAlert = alert);
        AppSnackbar.success(context, 'sos.alertSent'.tr());
      } else {
        AppSnackbar.error(context, 'sos.alertError'.tr());
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'sos.locationError'.tr());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resolveMyAlert() async {
    if (_myAlert == null) return;
    final ok = await EmergencyRepository.resolveAlert(_myAlert!.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _myAlert = null);
      AppSnackbar.success(context, 'sos.alertResolved'.tr());
    }
  }

  Future<void> _respond(EmergencyAlert alert) async {
    final userId = sb.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;
    await EmergencyRepository.respondToAlert(alert.id, userId);
    if (!mounted) return;
    AppSnackbar.success(context, 'sos.respondConfirm'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(emergencyAlertsProvider);

    return DashboardScaffold(
      title: 'sos.screenTitle'.tr(),
      body: Column(
        children: [
          _TypeSelector(
            selected: _selectedType,
            onChanged: (v) => setState(() => _selectedType = v),
          ),
          const SizedBox(height: 24),
          _SosButton(
            sending: _sending,
            hasActiveAlert: _myAlert != null,
            pulseAnim: _pulseAnim,
            onSend: _sendSos,
            onResolve: _resolveMyAlert,
          ),
          const SizedBox(height: 24),
          alerts.when(
            data: (list) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (list.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'sos.nearbyAlerts'.tr(namedArgs: {'count': '${list.length}'}),
                        style: AppTypography.label(color: AppColors.inkSoft),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: LocationMapView(
                        markers: list
                            .where((a) =>
                                a.latitude != 0 && a.longitude != 0)
                            .map((a) => MapMarkerData(
                                  id: a.id,
                                  lat: a.latitude,
                                  lng: a.longitude,
                                  color: _typeColor(a.alertType),
                                  title: 'sos.type.${a.alertType}'.tr(),
                                  icon: _typeIcon(a.alertType),
                                ))
                            .toList(),
                        initialZoom: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _AlertCard(
                          alert: list[i],
                          isOwn: list[i].userId ==
                              sb.auth.currentUser?.id,
                          onRespond: () => _respond(list[i]),
                        ),
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'sos.noNearbyAlerts'.tr(),
                          style: AppTypography.body(color: AppColors.mute),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Expanded(
              child: Center(
                child: Text('errors.generic'.tr(),
                    style: AppTypography.body(color: AppColors.mute)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'medical':
      return AppColors.herzrot;
    case 'fire':
      return AppColors.amber;
    case 'accident':
      return AppColors.amberWarm;
    default:
      return AppColors.teal;
  }
}

IconData _typeIcon(String type) {
  switch (type) {
    case 'medical':
      return LucideIcons.heart;
    case 'fire':
      return LucideIcons.flame;
    case 'accident':
      return LucideIcons.alertTriangle;
    default:
      return LucideIcons.helpCircle;
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  static const _types = ['medical', 'fire', 'accident', 'other'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _types.map((t) {
          final active = t == selected;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? _typeColor(t).withValues(alpha: 0.18)
                        : AppColors.elevated,
                    border: Border.all(
                      color: active ? _typeColor(t) : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(t),
                          size: 18,
                          color: active ? _typeColor(t) : AppColors.ghost),
                      const SizedBox(height: 4),
                      Text(
                        'sos.type.$t'.tr(),
                        style: AppTypography.label(
                          size: 9,
                          color: active ? _typeColor(t) : AppColors.ghost,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({
    required this.sending,
    required this.hasActiveAlert,
    required this.pulseAnim,
    required this.onSend,
    required this.onResolve,
  });
  final bool sending;
  final bool hasActiveAlert;
  final Animation<double> pulseAnim;
  final VoidCallback onSend;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    if (hasActiveAlert) {
      return Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.herzrot.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.herzrot, width: 2),
            ),
            child: Center(
              child: Icon(LucideIcons.shieldCheck,
                  color: AppColors.herzrot, size: 52),
            ),
          ),
          const SizedBox(height: 12),
          Text('sos.alertActive'.tr(),
              style: AppTypography.body(color: AppColors.herzrot)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onResolve,
            child: Text('sos.resolveAlert'.tr(),
                style: AppTypography.label(color: AppColors.mute)),
          ),
        ],
      );
    }

    return ScaleTransition(
      scale: pulseAnim,
      child: GestureDetector(
        onTap: sending ? null : onSend,
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.herzrot,
                AppColors.herzrotDeep,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.herzrot.withValues(alpha: 0.45),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: sending
                ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3)
                : Text(
                    'SOS',
                    style: AppTypography.display(
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.isOwn,
    required this.onRespond,
  });
  final EmergencyAlert alert;
  final bool isOwn;
  final VoidCallback onRespond;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(alert.alertType);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(_typeIcon(alert.alertType), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sos.type.${alert.alertType}'.tr(),
                  style: AppTypography.body(color: AppColors.ink),
                ),
                if (alert.description?.isNotEmpty == true)
                  Text(
                    alert.description!,
                    style: AppTypography.caption(color: AppColors.mute),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  'sos.responders'.tr(namedArgs: {
                    'count': '${alert.respondents.length}',
                  }),
                  style: AppTypography.label(
                      size: 10, color: AppColors.ghost),
                ),
              ],
            ),
          ),
          if (!isOwn)
            TextButton(
              onPressed: onRespond,
              child: Text('sos.respond'.tr(),
                  style: AppTypography.label(color: color)),
            ),
        ],
      ),
    );
  }
}
