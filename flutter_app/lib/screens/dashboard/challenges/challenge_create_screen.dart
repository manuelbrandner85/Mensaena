/// SKILL: mensaena-features
/// Challenge-Create-Screen — 1:1 zu Web /dashboard/challenges/create.
/// Felder: Titel, Beschreibung, Kategorie, Schwierigkeit, Punkte, Dauer.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/challenges_repository.dart';
import '../../../services/haptics.dart';
import '../../../widgets/effects/mini_confetti.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/app_snackbar.dart';

class ChallengeCreateScreen extends ConsumerStatefulWidget {
  const ChallengeCreateScreen({super.key});

  @override
  ConsumerState<ChallengeCreateScreen> createState() =>
      _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState
    extends ConsumerState<ChallengeCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'umwelt';
  String _difficulty = 'mittel';
  int _points = 50;
  int _days = 7;
  int _maxParticipants = 0;
  bool _isWeekly = false;
  bool _busy = false;

  Map<String, String> get _categories => {
        'umwelt': 'challenges.catUmwelt'.tr(),
        'sozial': 'challenges.catSozial'.tr(),
        'fitness': 'challenges.catFitness'.tr(),
        'bildung': 'challenges.catBildung'.tr(),
        'kreativ': 'challenges.catKreativ'.tr(),
        'ernaehrung': 'challenges.catErnaehrung'.tr(),
        'gemeinschaft': 'challenges.catGemeinschaft'.tr(),
      };

  Map<String, String> get _difficulties => {
        'leicht': 'challenges.diffEasy'.tr(),
        'mittel': 'challenges.diffMedium'.tr(),
        'schwer': 'challenges.diffHard'.tr(),
      };

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final id = await ChallengesRepository.create(
      title: _title.text,
      description: _desc.text,
      category: _category,
      difficulty: _difficulty,
      points: _points,
      durationDays: _days,
      maxParticipants: _maxParticipants > 0 ? _maxParticipants : null,
      isWeekly: _isWeekly,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (id == null) {
      Haptics.error();
      AppSnackBar.error(context, 'challenges.createFailed'.tr());
      return;
    }
    Haptics.success();
    MiniConfetti.show(context);
    AppSnackBar.success(context, 'challenges.createSuccess'.tr());
    context.go('/dashboard/challenges');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'challenges.create'.tr(),
      currentRoute: '/dashboard/challenges/create',
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text('challenges.newChallenge'.tr(),
                  style: AppTypography.display(
                      size: 22, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text('challenges.motivate'.tr(),
                  style: AppTypography.body(
                      size: 13, color: AppColors.mute)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                maxLength: 80,
                decoration: _input(
                    'challenges.fieldTitle'.tr(), 'challenges.titleHint'.tr()),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 5) return 'challenges.minChars'.tr();
                  if (t.length > 80) return 'challenges.maxChars'.tr();
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                maxLength: 500,
                maxLines: 4,
                decoration: _input('challenges.fieldDescOpt'.tr(),
                    'challenges.descHint'.tr()),
              ),
              const SizedBox(height: 18),
              Text('challenges.fieldCategory'.tr(),
                  style: AppTypography.label(
                      size: 10, color: AppColors.mute)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.entries
                    .map((e) => _ChoiceChip(
                          label: e.value,
                          selected: _category == e.key,
                          onTap: () => setState(() => _category = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text('challenges.fieldDifficulty'.tr(),
                  style: AppTypography.label(
                      size: 10, color: AppColors.mute)),
              const SizedBox(height: 8),
              Row(
                children: _difficulties.entries
                    .map((e) => Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: _ChoiceChip(
                              label: e.value,
                              selected: _difficulty == e.key,
                              onTap: () =>
                                  setState(() => _difficulty = e.key),
                              expanded: true,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              _slider(
                label: 'challenges.pointsLabel'.tr(),
                value: _points.toDouble(),
                min: 10,
                max: 500,
                divisions: 49,
                suffix: 'challenges.pointsSuffix'.tr(),
                onChanged: (v) => setState(() => _points = v.round()),
              ),
              const SizedBox(height: 12),
              _slider(
                label: 'challenges.durationLabel'.tr(),
                value: _days.toDouble(),
                min: 1,
                max: 90,
                divisions: 89,
                suffix: 'challenges.daysSuffix'.tr(),
                onChanged: (v) => setState(() => _days = v.round()),
              ),
              const SizedBox(height: 12),
              // Maximale Teilnehmer (0 = unbegrenzt).
              Row(
                children: [
                  Expanded(
                    child: Text('challenges.maxParticipants'.tr(),
                        style: AppTypography.label(
                            size: 10, color: AppColors.mute)),
                  ),
                  Text(
                    _maxParticipants == 0
                        ? 'challenges.unlimited'.tr()
                        : '$_maxParticipants',
                    style:
                        AppTypography.mono(size: 13, color: AppColors.bronze),
                  ),
                ],
              ),
              Slider(
                value: _maxParticipants.toDouble(),
                min: 0,
                max: 500,
                divisions: 50,
                activeColor: AppColors.bronze,
                inactiveColor: AppColors.line,
                onChanged: (v) =>
                    setState(() => _maxParticipants = v.round()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.amber,
                value: _isWeekly,
                onChanged: (v) => setState(() => _isWeekly = v),
                title: Text('challenges.weeklyChallenge'.tr(),
                    style:
                        AppTypography.body(size: 14, color: AppColors.ink)),
                subtitle: Text('challenges.weeklyHint'.tr(),
                    style: AppTypography.caption()),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.voidColor),
                      )
                    : const Icon(LucideIcons.trophy, size: 16),
                label: Text('challenges.start'.tr()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.voidColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTypography.body(size: 13, color: AppColors.mute),
      hintStyle: AppTypography.body(size: 12, color: AppColors.mute),
      filled: true,
      fillColor: AppColors.elevated,
      counterStyle: AppTypography.label(size: 9, color: AppColors.mute),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.bronze),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTypography.label(
                      size: 10, color: AppColors.mute)),
            ),
            Text('${value.round()}$suffix',
                style:
                    AppTypography.mono(size: 13, color: AppColors.bronze)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.bronze,
          inactiveColor: AppColors.line,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.bronze : AppColors.line;
    final bg = selected
        ? AppColors.bronze.withValues(alpha: 0.18)
        : AppColors.elevated;
    final fg = selected ? AppColors.bronze : AppColors.inkSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: expanded ? Alignment.center : null,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color),
        ),
        child: Text(label,
            style: AppTypography.body(
                size: 12,
                color: fg,
                weight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}
