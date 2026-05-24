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

/// SKILL: mensaena-features
/// Crisis-Create — Schnellformular fuer Notfallmeldung.
class CrisisCreateScreen extends ConsumerStatefulWidget {
  const CrisisCreateScreen({super.key});

  @override
  ConsumerState<CrisisCreateScreen> createState() =>
      _CrisisCreateScreenState();
}

class _CrisisCreateScreenState extends ConsumerState<CrisisCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  String _category = 'medical';
  String _urgency = 'high';
  double? _lat;
  double? _lng;
  bool _submitting = false;
  String? _error;

  static const List<({String value, String label, String emoji})> _categories = [
    (value: 'medical', label: 'Medizinisch', emoji: '🚑'),
    (value: 'fire', label: 'Feuer', emoji: '🔥'),
    (value: 'flood', label: 'Hochwasser', emoji: '🌊'),
    (value: 'storm', label: 'Sturm', emoji: '⛈️'),
    (value: 'missing', label: 'Vermisst', emoji: '🔍'),
    (value: 'other', label: 'Sonstiges', emoji: '⚠️'),
  ];

  static const List<({String value, String label, Color color})> _urgencies = [
    (value: 'critical', label: 'KRITISCH', color: AppColors.herzrot),
    (value: 'high', label: 'HOCH', color: Color(0xFFFB923C)),
    (value: 'medium', label: 'MITTEL', color: AppColors.amber),
    (value: 'low', label: 'NIEDRIG', color: AppColors.teal),
  ];

  @override
  void dispose() {
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

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      setState(() => _error = 'Titel und Beschreibung sind Pflicht.');
      return;
    }
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
        _error = 'Konnte Krise nicht speichern.';
      });
      return;
    }
    context.go('/dashboard/crisis/$id');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Krise melden',
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.herzrot.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.herzrot),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertOctagon,
                      color: AppColors.herzrot),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bei akuter Lebensgefahr ZUERST 112 anrufen.',
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.herzrotWarm,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('crisis.categoryLabel'.tr(), style: AppTypography.label(size: 10)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories.map((c) {
                final active = c.value == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = c.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.herzrot.withValues(alpha: 0.2)
                          : AppColors.surface.withValues(alpha: 0.5),
                      border: Border.all(
                        color: active ? AppColors.herzrot : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(c.label,
                            style: AppTypography.label(
                              size: 10,
                              color: active
                                  ? AppColors.herzrotWarm
                                  : AppColors.inkSoft,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text('crisis.urgency'.tr(), style: AppTypography.label(size: 10)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: _urgencies.map((u) {
                final active = u.value == _urgency;
                return GestureDetector(
                  onTap: () => setState(() => _urgency = u.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? u.color.withValues(alpha: 0.2)
                          : AppColors.surface.withValues(alpha: 0.5),
                      border: Border.all(
                        color: active ? u.color : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      u.label,
                      style: AppTypography.label(
                        size: 10,
                        color: active ? u.color : AppColors.inkSoft,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 120,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Titel'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 5,
              maxLength: 1500,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Was ist passiert?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _location,
                    style: AppTypography.body(size: 14, color: AppColors.ink),
                    decoration:
                        const InputDecoration(labelText: 'Ort / Adresse'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _useGps,
                  icon: const Icon(LucideIcons.locate, size: 16),
                  label: const Text('GPS'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.herzrotWarm,
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.herzrot,
                  foregroundColor: AppColors.ink,
                ),
                onPressed: _submitting ? null : _submit,
                icon: const Icon(LucideIcons.alertTriangle, size: 16),
                label: Text(_submitting ? 'Sende…' : 'Krise melden'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
