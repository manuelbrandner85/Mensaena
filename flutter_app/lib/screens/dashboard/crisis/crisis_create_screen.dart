import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/crisis_repository.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/voice_dictation_button.dart';
import '../../../widgets/shared/readable_width.dart';
import '../../../widgets/shared/app_snackbar.dart';

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
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  String _category = 'medical';
  String _urgency = 'high';
  double? _lat;
  double? _lng;
  int _affected = 0;
  int _neededHelpers = 0;
  final Set<String> _skills = <String>{};
  final Set<String> _resources = <String>{};
  final List<File> _images = <File>[];
  bool _anonymous = false;
  bool _submitting = false;
  bool _titleError = false;
  bool _descError = false;
  String? _error;
  late final AnimationController _pulse;

  // Krisen-spezifische Hilfe-Bedarfe (Wert wird gespeichert, Label übersetzt).
  static const List<({String value, String i18n})> _skillOptions = [
    (value: 'medical', i18n: 'crisisCreate.skillMedical'),
    (value: 'transport', i18n: 'crisisCreate.skillTransport'),
    (value: 'shelter', i18n: 'crisisCreate.skillShelter'),
    (value: 'manpower', i18n: 'crisisCreate.skillManpower'),
    (value: 'technical', i18n: 'crisisCreate.skillTechnical'),
    (value: 'translation', i18n: 'crisisCreate.skillTranslation'),
    (value: 'childcare', i18n: 'crisisCreate.skillChildcare'),
    (value: 'animalcare', i18n: 'crisisCreate.skillAnimalcare'),
  ];

  static const List<({String value, String i18n})> _resourceOptions = [
    (value: 'water', i18n: 'crisisCreate.resWater'),
    (value: 'food', i18n: 'crisisCreate.resFood'),
    (value: 'blankets', i18n: 'crisisCreate.resBlankets'),
    (value: 'clothing', i18n: 'crisisCreate.resClothing'),
    (value: 'medicine', i18n: 'crisisCreate.resMedicine'),
    (value: 'power', i18n: 'crisisCreate.resPower'),
    (value: 'tools', i18n: 'crisisCreate.resTools'),
    (value: 'vehicle', i18n: 'crisisCreate.resVehicle'),
  ];

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
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_images.length >= 3) return;
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 80,
    );
    if (result == null) return;
    setState(() => _images.add(File(result.path)));
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
      AppSnackBar.error(context, 'crisis.locationUnavailable'.tr());
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
    if (_anonymous && _contactPhone.text.trim().isEmpty) {
      setState(() => _error = 'crisis.anonymousNeedsPhone'.tr());
      return;
    }
    // K1: GPS-Bestätigung
    final confirmed = await _confirmLocation();
    if (!confirmed) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    // Bilder sind bei einer Krise NEBENSÄCHLICH — ein Upload-Fehler darf die
    // Notfall-Meldung niemals blockieren. Wir laden best-effort, merken uns
    // aber, ob etwas fehlschlug, um nach dem Anlegen kurz zu warnen.
    var imageFailures = 0;
    final imageUrls = _images.isEmpty
        ? const <String>[]
        : await ImageUploadService.upload(
            _images,
            onError: (_, __) => imageFailures++,
          );
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
      affectedCount: _affected > 0 ? _affected : null,
      neededHelpers: _neededHelpers > 0 ? _neededHelpers : null,
      neededSkills: _skills.toList(),
      neededResources: _resources.toList(),
      contactName:
          _anonymous ? null : _contactName.text.trim(),
      contactPhone: _contactPhone.text.trim(),
      imageUrls: imageUrls,
      isAnonymous: _anonymous,
    );
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _submitting = false;
        _error = 'crisis.saveFailed'.tr();
      });
      return;
    }
    if (imageFailures > 0) {
      AppSnackBar.error(context, 'create.imagePartialFailed'.tr());
    } else {
      AppSnackBar.success(context, 'common.created'.tr());
    }
    context.go('/dashboard/crisis/$id');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'crisis.createTitle'.tr(),
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: ReadableWidth(
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
            const SizedBox(height: 24),
            // ─── Weitere, krisen-spezifische Details (alle optional) ─────
            Row(
              children: [
                Icon(LucideIcons.listPlus,
                    size: 14, color: AppColors.bronze.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
                Text('crisisCreate.moreDetails'.tr(),
                    style: AppTypography.label(size: 10)),
              ],
            ),
            const SizedBox(height: 12),
            // Betroffene Personen + benötigte Helfer:innen als kompakte Stepper.
            Row(
              children: [
                Expanded(
                  child: _CounterField(
                    label: 'crisisCreate.affectedCount'.tr(),
                    icon: LucideIcons.users,
                    value: _affected,
                    onChanged: (v) => setState(() => _affected = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CounterField(
                    label: 'crisisCreate.neededHelpers'.tr(),
                    icon: LucideIcons.helpingHand,
                    value: _neededHelpers,
                    onChanged: (v) => setState(() => _neededHelpers = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Benötigte Fähigkeiten (Mehrfachauswahl).
            Text('crisisCreate.neededSkills'.tr(),
                style: AppTypography.label(size: 10)),
            const SizedBox(height: 10),
            _ChipMultiSelect(
              options: _skillOptions,
              selected: _skills,
              onToggle: (v) => setState(() =>
                  _skills.contains(v) ? _skills.remove(v) : _skills.add(v)),
            ),
            const SizedBox(height: 18),
            // Benötigte Ressourcen (Mehrfachauswahl).
            Text('crisisCreate.neededResources'.tr(),
                style: AppTypography.label(size: 10)),
            const SizedBox(height: 10),
            _ChipMultiSelect(
              options: _resourceOptions,
              selected: _resources,
              onToggle: (v) => setState(() => _resources.contains(v)
                  ? _resources.remove(v)
                  : _resources.add(v)),
            ),
            const SizedBox(height: 18),
            // Fotos (max 3) — helfen Helfenden bei der Lageeinschätzung.
            Text('crisisCreate.photos'.tr(),
                style: AppTypography.label(size: 10)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_images[i],
                            width: 76, height: 76, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xCC000000),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.x,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_images.length < 3)
                  GestureDetector(
                    onTap: _addPhoto,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.5),
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.camera,
                          color: AppColors.bronze, size: 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            // Kontakt (entfällt bei anonymer Meldung).
            if (!_anonymous) ...[
              TextField(
                controller: _contactName,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'crisisCreate.contactName'.tr(),
                  prefixIcon: const Icon(LucideIcons.user, size: 18),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s/()-]')),
              ],
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'crisisCreate.contactPhone'.tr(),
                prefixIcon: const Icon(LucideIcons.phone, size: 18),
                helperText: _anonymous
                    ? 'crisisCreate.anonymousPhoneHint'.tr()
                    : null,
                helperMaxLines: 3,
                helperStyle: AppTypography.caption(),
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _anonymous,
              activeColor: AppColors.herzrot,
              onChanged: (v) => setState(() => _anonymous = v),
              title: Text('crisisCreate.anonymous'.tr(),
                  style: AppTypography.body(size: 14, color: AppColors.ink)),
              subtitle: Text('crisisCreate.anonymousHint'.tr(),
                  style: AppTypography.caption()),
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
        )),
      ),
    );
  }
}

/// Kompakter +/−-Zähler für kleine Mengenangaben (Betroffene/Helfer:innen).
class _CounterField extends StatelessWidget {
  const _CounterField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption()),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepBtn(
                icon: LucideIcons.minus,
                onTap: value > 0 ? () => onChanged(value - 1) : null,
              ),
              Text(value == 0 ? '–' : '$value',
                  style: AppTypography.body(
                      size: 17,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
              _StepBtn(
                icon: LucideIcons.plus,
                onTap: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    // Sichtbarer Kreis bleibt 34dp, die Tap-Fläche ist 48dp (A11y-Minimum —
    // im Krisen-Kontext besonders wichtig, zitternde Hände treffen sonst
    // daneben).
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.bronze.withValues(alpha: 0.16)
                  : AppColors.surface.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 16,
                color: enabled ? AppColors.bronze : AppColors.mute),
          ),
        ),
      ),
    );
  }
}

/// Mehrfach-Auswahl als Chips. Speichert stabile `value`, zeigt `i18n.tr()`.
class _ChipMultiSelect extends StatelessWidget {
  const _ChipMultiSelect({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<({String value, String i18n})> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final active = selected.contains(o.value);
        return GestureDetector(
          onTap: () => onToggle(o.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.bronze.withValues(alpha: 0.20)
                  : AppColors.surface.withValues(alpha: 0.5),
              border: Border.all(
                color: active ? AppColors.bronze : AppColors.line,
                width: active ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active) ...[
                  const Icon(LucideIcons.check,
                      size: 12, color: AppColors.bronze),
                  const SizedBox(width: 5),
                ],
                Text(o.i18n.tr(),
                    style: AppTypography.label(
                      size: 11,
                      color: active ? AppColors.bronze : AppColors.inkSoft,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
