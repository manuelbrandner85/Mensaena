import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/crisis_repository.dart';
import '../../../services/location_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/voice_dictation_button.dart';

/// SKILL: mensaena-features
/// Crisis-Create — Schnellformular fuer Notfallmeldung.
/// UX-Polish: Voice-Diktat im Description-Feld, große Touch-Ziele (>=56dp),
/// pulsierende Lebensgefahr-Warnung, eindeutige CTA.
class CrisisCreateScreen extends ConsumerStatefulWidget {
  const CrisisCreateScreen({super.key});

  @override
  ConsumerState<CrisisCreateScreen> createState() =>
      _CrisisCreateScreenState();
}

class _CrisisCreateScreenState extends ConsumerState<CrisisCreateScreen>
    with SingleTickerProviderStateMixin {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  String _category = 'medical';
  String _urgency = 'high';
  double? _lat;
  double? _lng;
  bool _submitting = false;
  bool _titleError = false;
  bool _descError = false;
  String? _error;
  late final AnimationController _pulse;

  static const List<({String value, String i18n})> _categories = [
    (value: 'medical', i18n: 'crisis.catMedical'),
    (value: 'fire', i18n: 'crisis.catFire'),
    (value: 'flood', i18n: 'crisis.catFlood'),
    (value: 'storm', i18n: 'crisis.catStorm'),
    (value: 'accident', i18n: 'crisis.catAccident'),
    (value: 'violence', i18n: 'crisis.catViolence'),
    (value: 'missing_person', i18n: 'crisis.catMissing'),
    (value: 'infrastructure', i18n: 'crisis.catInfrastructure'),
    (value: 'supply', i18n: 'crisis.catSupply'),
    (value: 'evacuation', i18n: 'crisis.catEvacuation'),
    (value: 'other', i18n: 'crisis.catOther'),
  ];

  static const List<({String value, String i18n, Color color})> _urgencies = [
    (value: 'critical', i18n: 'crisis.urgCritical', color: AppColors.herzrot),
    (value: 'high', i18n: 'crisis.urgHigh', color: Color(0xFFFB923C)),
    (value: 'medium', i18n: 'crisis.urgMedium', color: AppColors.amber),
    (value: 'low', i18n: 'crisis.urgLow', color: AppColors.teal),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    try {
      final pos = await LocationService.getCurrentPosition(
        accuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _location.text =
            'GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('crisis.locationUnavailable'.tr())),
      );
    }
  }

  Future<bool> _confirmLocation() async {
    // K1: GPS-Bestätigung VOR dem Insert — User soll explizit bestätigen
    // dass die gemeldete Krise an der angegebenen Position passiert.
    // Verhindert Falschmeldungen mit alter/falscher Location.
    final hasGps = _lat != null && _lng != null;
    final hint = hasGps
        ? 'GPS-Position: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
        : _location.text.trim().isEmpty
            ? 'Keine Position angegeben — die Krise wird ohne Standort gemeldet.'
            : 'Adresse: ${_location.text.trim()}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: const Icon(LucideIcons.mapPin,
            size: 32, color: AppColors.herzrotWarm),
        title: Text('crisisCreate.areYouHere'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        content: Text(hint,
            textAlign: TextAlign.center,
            style: AppTypography.body(
                size: 13, color: AppColors.inkSoft, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dCtx, true),
            icon: const Icon(LucideIcons.check, size: 14),
            label: Text('crisisCreate.yesReportHere'.tr()),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.herzrot,
                foregroundColor: AppColors.ink),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submit() async {
    final titleEmpty = _title.text.trim().isEmpty;
    final descEmpty = _desc.text.trim().isEmpty;
    if (titleEmpty || descEmpty) {
      setState(() {
        _titleError = titleEmpty;
        _descError = descEmpty;
        _error = 'crisis.fieldTitleRequired'.tr();
      });
      return;
    }
    // K1: GPS-Bestätigung
    final confirmed = await _confirmLocation();
    if (!confirmed) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final id = await CrisisRepository.create(
      title: _title.text.trim(),
      description: _desc.text.trim(),
      category: _category,
      urgency: _urgency,
      locationText: _location.text.trim().isEmpty
          ? null
          : _location.text.trim(),
      latitude: _lat,
      longitude: _lng,
    );
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _submitting = false;
        _error = 'crisis.saveFailed'.tr();
      });
      return;
    }
    context.go('/dashboard/crisis/$id');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'crisis.createTitle'.tr(),
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Pulsierender Lebensgefahr-Banner (auf dieser Seite sehr prominent)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = _pulse.value;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.herzrot.withValues(alpha: 0.10 + t * 0.06),
                    border: Border.all(
                      color: AppColors.herzrot.withValues(alpha: 0.5 + t * 0.4),
                      width: 1.6 + t * 0.6,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.herzrot
                            .withValues(alpha: 0.08 + t * 0.18),
                        blurRadius: 10 + t * 14,
                        spreadRadius: t * 1.5,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertOctagon,
                          color: AppColors.herzrot, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'crisis.lifeDangerHint'.tr(),
                          style: AppTypography.body(
                            size: 13,
                            color: AppColors.herzrotWarm,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Kategorie
            Text('crisis.categoryLabel'.tr(),
                style: AppTypography.label(size: 10)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final active = c.value == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = c.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.herzrot.withValues(alpha: 0.22)
                          : AppColors.surface.withValues(alpha: 0.5),
                      border: Border.all(
                        color:
                            active ? AppColors.herzrot : AppColors.line,
                        width: active ? 1.6 : 1,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(c.i18n.tr(),
                        style: AppTypography.label(
                          size: 11,
                          color: active
                              ? AppColors.herzrotWarm
                              : AppColors.inkSoft,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            // Dringlichkeit
            Text('crisis.urgency'.tr(), style: AppTypography.label(size: 10)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _urgencies.map((u) {
                final active = u.value == _urgency;
                return GestureDetector(
                  onTap: () => setState(() => _urgency = u.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? u.color.withValues(alpha: 0.22)
                          : AppColors.surface.withValues(alpha: 0.5),
                      border: Border.all(
                        color: active ? u.color : AppColors.line,
                        width: active ? 1.8 : 1,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      u.i18n.tr(),
                      style: AppTypography.label(
                        size: 11,
                        color: active ? u.color : AppColors.inkSoft,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Titel
            TextField(
              controller: _title,
              maxLength: 120,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              onChanged: _titleError
                  ? (_) => setState(() => _titleError = false)
                  : null,
              decoration: InputDecoration(
                labelText: 'crisis.fieldTitle'.tr(),
                errorText: _titleError ? 'create.titleRequired'.tr() : null,
              ),
            ),
            const SizedBox(height: 14),
            // Beschreibung mit Voice-Diktat-Button rechts oben
            Stack(
              children: [
                TextField(
                  controller: _desc,
                  maxLines: 5,
                  maxLength: 1500,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  onChanged: _descError
                      ? (_) => setState(() => _descError = false)
                      : null,
                  decoration: InputDecoration(
                    labelText: 'crisis.fieldDescription'.tr(),
                    alignLabelWithHint: true,
                    helperText: 'crisis.voiceHint'.tr(),
                    helperStyle: AppTypography.caption(),
                    errorText:
                        _descError ? 'create.descRequired'.tr() : null,
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: VoiceDictationButton(controller: _desc),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Ort + GPS — größere GPS-Taste
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _location,
                    style: AppTypography.body(size: 14, color: AppColors.ink),
                    decoration: InputDecoration(
                      labelText: 'crisis.fieldLocation'.tr(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _useGps,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.bronze,
                      side: BorderSide(
                          color: AppColors.bronze.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(LucideIcons.locate, size: 18),
                    label: const Text('GPS'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.herzrot.withValues(alpha: 0.10),
                  border: Border.all(
                      color: AppColors.herzrot.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertCircle,
                        color: AppColors.herzrotWarm, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.herzrotWarm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Großer Senden-Button — mind. 60dp hoch
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.herzrot,
                  foregroundColor: AppColors.ink,
                  textStyle: AppTypography.body(
                      size: 16, weight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ).copyWith(
                  shadowColor:
                      const WidgetStatePropertyAll(AppColors.herzrotGlow),
                ),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.ink),
                      )
                    : const Icon(LucideIcons.alertTriangle, size: 20),
                label: Text(_submitting
                    ? 'crisis.sendingShort'.tr()
                    : 'crisis.reportButton'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
