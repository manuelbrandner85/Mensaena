import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import '../shared/address_autocomplete_field.dart';

/// SKILL: mensaena-design + mensaena-features
/// 1:1-Pendant zu `src/app/dashboard/components/LocationOnboardingModal.tsx`.
/// Wird einmalig angezeigt wenn `profile.latitude` und `profile.longitude` null.
/// Bietet GPS-Detection ODER manuelle Adress-Eingabe.
class LocationOnboardingModal extends StatefulWidget {
  const LocationOnboardingModal({
    required this.userId,
    required this.onSaved,
    super.key,
  });

  final String userId;
  final void Function(double lat, double lng, String location) onSaved;

  @override
  State<LocationOnboardingModal> createState() =>
      _LocationOnboardingModalState();
}

class _LocationOnboardingModalState
    extends State<LocationOnboardingModal> {
  final _ctrl = TextEditingController();
  double? _lat;
  double? _lng;
  bool _saving = false;
  bool _gpsLoading = false;
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() {
      _gpsLoading = true;
      _err = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _err = 'Standort-Zugriff verweigert.';
          _gpsLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      _lat = pos.latitude;
      _lng = pos.longitude;
      _ctrl.text =
          'GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
    } catch (_) {
      if (mounted) setState(() => _err = 'Standort nicht verfügbar.');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null) {
      setState(() =>
          _err = 'Bitte Standort per GPS oder Adresse setzen.');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await sb.from('profiles').update({
        'latitude': _lat,
        'longitude': _lng,
        'location': _ctrl.text.trim(),
      }).eq('id', widget.userId);
      if (!mounted) return;
      widget.onSaved(_lat!, _lng!, _ctrl.text.trim());
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = 'Speichern fehlgeschlagen.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Editorial-Style Header
            Row(
              children: [
                Container(
                  width: 16,
                  height: 1,
                  color: AppColors.bronze.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  '§ Standort / Onboarding',
                  style: AppTypography.label(
                    size: 9,
                    color: AppColors.bronze.withValues(alpha: 0.85),
                    letterSpacing: 0.20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: AppTypography.display(
                  size: 22,
                  color: AppColors.ink,
                  height: 1.15,
                ),
                children: const [
                  TextSpan(text: 'Wo bist du '),
                  TextSpan(
                    text: 'zu Hause',
                    style: TextStyle(
                      color: AppColors.bronze,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  TextSpan(text: '?'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Damit wir dir Beiträge, Krisen und Hilfe in deiner Nähe zeigen können — sonst nichts.',
              style: AppTypography.body(
                size: 13,
                color: AppColors.mute,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),

            // GPS-Button
            _BigOptionButton(
              icon: LucideIcons.locate,
              title: 'onboarding.gpsTitle'.tr(),
              subtitle: 'onboarding.gpsSubtitle'.tr(),
              loading: _gpsLoading,
              done: _lat != null,
              onTap: _useGps,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: Divider(
                        color: Colors.white
                            .withValues(alpha: 0.07))),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8),
                  child: Text('common.or'.tr(),
                      style: AppTypography.label(
                          size: 9, color: AppColors.mute)),
                ),
                Expanded(
                    child: Divider(
                        color: Colors.white
                            .withValues(alpha: 0.07))),
              ],
            ),
            const SizedBox(height: 10),
            AddressAutocompleteField(
              controller: _ctrl,
              label: 'Adresse manuell',
              hint: 'Straße, PLZ oder Ort',
              onSelected: (s) {
                setState(() {
                  _lat = s.lat;
                  _lng = s.lng;
                });
              },
            ),

            if (_err != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.herzrot.withValues(alpha: 0.08),
                  border: Border.all(
                      color:
                          AppColors.herzrot.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_err!,
                    style: AppTypography.body(
                        size: 12,
                        color: AppColors.herzrotWarm)),
              ),
            ],

            const SizedBox(height: 20),
            // Save Button (Bronze-Gradient)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (_lat == null || _saving) ? null : _save,
                borderRadius: BorderRadius.circular(14),
                child: Opacity(
                  opacity: _lat == null ? 0.5 : 1,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.bronze,
                          AppColors.bronzeSoft,
                          AppColors.bronze,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bronze
                              .withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.voidColor,
                            ),
                          )
                        : Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text('home.saveLocation'.tr(),
                                  style: AppTypography.body(
                                    size: 14,
                                    color: AppColors.voidColor,
                                    weight: FontWeight.w600,
                                  )),
                              const SizedBox(width: 6),
                              const Icon(LucideIcons.arrowRight,
                                  size: 16,
                                  color: AppColors.voidColor),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Später',
                  style: AppTypography.label(
                      size: 10, color: AppColors.mute),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigOptionButton extends StatelessWidget {
  const _BigOptionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
    this.done = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: done
                ? AppColors.leben.withValues(alpha: 0.10)
                : AppColors.elevated,
            border: Border.all(
              color: done
                  ? AppColors.leben.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.leben.withValues(alpha: 0.2)
                      : AppColors.bronze.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bronze,
                        ),
                      )
                    : Icon(done ? LucideIcons.checkCircle2 : icon,
                        size: 20,
                        color: done
                            ? AppColors.leben
                            : AppColors.bronze),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTypography.caption()),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight,
                  size: 16, color: AppColors.mute),
            ],
          ),
        ),
      ),
    );
  }
}
