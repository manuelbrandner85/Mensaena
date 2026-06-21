import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/skills_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/location_service.dart';
import '../../../widgets/effects/mini_confetti.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../widgets/shared/readable_width.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../utils/form_validators.dart';

class SkillsCreateScreen extends ConsumerStatefulWidget {
  const SkillsCreateScreen({super.key});

  @override
  ConsumerState<SkillsCreateScreen> createState() => _SkillsCreateScreenState();
}

class _SkillsCreateScreenState extends ConsumerState<SkillsCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  String? _category;
  String? _level;
  bool _isFree = true;
  bool _isOnline = false;
  bool _submitting = false;
  bool _locating = false;
  String? _error;

  static const Map<String, String> _categories = {
    'sprachen': 'skills.create.catSprachen',
    'it': 'skills.create.catIt',
    'musik': 'skills.create.catMusik',
    'sport': 'skills.create.catSport',
    'kochen': 'skills.create.catKochen',
    'handwerk': 'skills.create.catHandwerk',
    'kunst': 'skills.create.catKunst',
    'nachhilfe': 'skills.create.catNachhilfe',
    'sonstiges': 'skills.create.catSonstiges',
  };

  static const Map<String, String> _levels = {
    'anfaenger': 'skills.create.levelAnfaenger',
    'fortgeschritten': 'skills.create.levelFortgeschritten',
    'experte': 'skills.create.levelExperte',
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        if (_locationCtrl.text.trim().isEmpty) {
          _locationCtrl.text =
              '${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
        }
      });
    } catch (_) {
      // Standort bleibt optional.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      Haptics.error();
      setState(() => _error = null);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final id = await SkillsRepository.create(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      skillCategory: _category,
      level: _level,
      isFree: _isFree,
      hourlyRate: _isFree
          ? null
          : double.tryParse(_rateCtrl.text.trim().replaceAll(',', '.')),
      isOnline: _isOnline,
      locationAddress: _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim(),
    );

    if (!mounted) return;
    if (id == null) {
      Haptics.error();
      setState(() {
        _submitting = false;
        _error = 'common.errorGeneric'.tr();
      });
      return;
    }

    Haptics.success();
    MiniConfetti.show(context);
    AppSnackBar.success(context, 'common.created'.tr());
    context.go('/dashboard/skills');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'skills.create.screenTitle'.tr(),
      currentRoute: '/dashboard/skills',
      body: SafeArea(
        child: ReadableWidth(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Titel ───────────────────────────────────────────────────
              AnimatedEntrance(
                index: 0,
                child: TextFormField(
                  controller: _titleCtrl,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  validator: FormValidators.lengthBetween(3, 120),
                  style: AppTypography.body(size: 15, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'create.title'.tr(),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // ── Beschreibung ────────────────────────────────────────────
              AnimatedEntrance(
                index: 1,
                child: TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  validator: FormValidators.lengthBetween(10, 2000),
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'create.description'.tr(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Kategorie ───────────────────────────────────────────────
              DropdownButtonFormField<String>(
                value: _category,
                decoration:
                    InputDecoration(labelText: 'skills.create.category'.tr()),
                dropdownColor: AppColors.surface,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('skills.create.categoryNone'.tr(),
                        style: AppTypography.body(
                            size: 14, color: AppColors.inkSoft)),
                  ),
                  ..._categories.entries.map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value.tr()))),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 10),
              // ── Niveau ──────────────────────────────────────────────────
              DropdownButtonFormField<String>(
                value: _level,
                decoration:
                    InputDecoration(labelText: 'skills.create.level'.tr()),
                dropdownColor: AppColors.surface,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('skills.create.levelNone'.tr(),
                        style: AppTypography.body(
                            size: 14, color: AppColors.inkSoft)),
                  ),
                  ..._levels.entries.map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value.tr()))),
                ],
                onChanged: (v) => setState(() => _level = v),
              ),
              const SizedBox(height: 4),
              // ── Gratis-Toggle ───────────────────────────────────────────
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary500,
                value: _isFree,
                onChanged: (v) => setState(() => _isFree = v),
                title: Text('skills.create.isFree'.tr(),
                    style: AppTypography.body(size: 14, color: AppColors.ink)),
              ),
              if (!_isFree) ...[
                TextFormField(
                  controller: _rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: FormValidators.positiveNumberOptional,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'skills.create.hourlyRate'.tr(),
                    prefixIcon:
                        const Icon(LucideIcons.euro, size: 16),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              // ── Online-Toggle ───────────────────────────────────────────
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary500,
                value: _isOnline,
                onChanged: (v) => setState(() => _isOnline = v),
                title: Text('skills.create.isOnline'.tr(),
                    style: AppTypography.body(size: 14, color: AppColors.ink)),
                subtitle: Text('skills.create.isOnlineHint'.tr(),
                    style:
                        AppTypography.body(size: 12, color: AppColors.inkSoft)),
              ),
              const SizedBox(height: 4),
              // ── Standort ────────────────────────────────────────────────
              TextField(
                controller: _locationCtrl,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'create.location'.tr(),
                  suffixIcon: IconButton(
                    onPressed: _locating ? null : _useGps,
                    tooltip: 'marketplace.useGps'.tr(),
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary500),
                          )
                        : const Icon(LucideIcons.locate,
                            size: 18, color: AppColors.inkSoft),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: AppTypography.body(
                      size: 13, color: AppColors.herzrotWarm),
                ),
              ],
              const SizedBox(height: 20),
              AnimatedEntrance(
                index: 2,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: Text(_submitting
                      ? 'skills.create.saving'.tr()
                      : 'skills.create.submitButton'.tr()),
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
