import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/trust_ratings_repository.dart';

/// SKILL: mensaena-features
/// Trust-Rating-Modal — Bewertungs-Sheet nach abgeschlossener Interaktion.
/// 1:1 zu Web RatingModal.tsx.
///
/// Usage:
/// ```dart
/// TrustRatingModal.show(
///   context,
///   ratedUserId: 'xxx',
///   ratedUserName: 'Anna',
///   interactionId: 'yyy',
/// );
/// ```
class TrustRatingModal extends StatefulWidget {
  const TrustRatingModal({
    required this.ratedUserId,
    required this.ratedUserName,
    this.interactionId,
    super.key,
  });

  final String ratedUserId;
  final String ratedUserName;
  final String? interactionId;

  static Future<bool?> show(
    BuildContext context, {
    required String ratedUserId,
    required String ratedUserName,
    String? interactionId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TrustRatingModal(
        ratedUserId: ratedUserId,
        ratedUserName: ratedUserName,
        interactionId: interactionId,
      ),
    );
  }

  @override
  State<TrustRatingModal> createState() => _TrustRatingModalState();
}

class _TrustRatingModalState extends State<TrustRatingModal> {
  int _score = 0;
  bool _helpful = true;
  bool _wouldRecommend = true;
  final _commentCtrl = TextEditingController();
  final Set<String> _categories = {};
  bool _submitting = false;

  // Stable IDs persisted in DB; UI label via _categoryLabel().
  static const _categoryOptions = [
    'friendly',
    'punctual',
    'helpful',
    'reliable',
    'communicative',
    'empathic',
  ];

  String _categoryLabel(String k) {
    switch (k) {
      case 'friendly':
        return 'trust.catFriendly'.tr();
      case 'punctual':
        return 'trust.catPunctual'.tr();
      case 'helpful':
        return 'trust.catHelpful'.tr();
      case 'reliable':
        return 'trust.catReliable'.tr();
      case 'communicative':
        return 'trust.catCommunicative'.tr();
      case 'empathic':
        return 'trust.catEmpathic'.tr();
      default:
        return k;
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score == 0) return;
    setState(() => _submitting = true);
    final ok = await TrustRatingsRepository.rate(
      ratedUserId: widget.ratedUserId,
      score: _score,
      comment: _commentCtrl.text.trim().isEmpty
          ? null
          : _commentCtrl.text.trim(),
      interactionId: widget.interactionId,
      categories: _categories.toList(),
      helpful: _helpful,
      wouldRecommend: _wouldRecommend,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'trust.thanks'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'trust.failed'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.herzrotWarm),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 14),
          Text('trust.rate'.tr(namedArgs: {'name': widget.ratedUserName}),
              style: AppTypography.display(
                  size: 22, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text('trust.howWasInteraction'.tr(),
              style: AppTypography.body(
                  size: 13, color: AppColors.inkSoft)),
          const SizedBox(height: 20),
          // 5 Sterne, tap to set score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _score;
              return GestureDetector(
                onTap: () => setState(() => _score = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled ? LucideIcons.star : LucideIcons.star,
                    size: 42,
                    color: filled ? AppColors.amber : AppColors.elevated,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Categories (multi-select chips)
          Text('trust.whatWasGreat'.tr(),
              style: AppTypography.label(
                  size: 10, color: AppColors.mute)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _categoryOptions.map((c) {
              final active = _categories.contains(c);
              return FilterChip(
                label: Text(_categoryLabel(c)),
                selected: active,
                onSelected: (_) => setState(() {
                  if (active) {
                    _categories.remove(c);
                  } else {
                    _categories.add(c);
                  }
                }),
                backgroundColor: AppColors.elevated,
                selectedColor: AppColors.bronze.withValues(alpha: 0.3),
                labelStyle: AppTypography.body(
                  size: 12,
                  color: active ? AppColors.bronze : AppColors.inkSoft,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          // Comment (optional)
          Text('trust.commentOptional'.tr(),
              style: AppTypography.label(
                  size: 10, color: AppColors.mute)),
          const SizedBox(height: 6),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: 500,
            style: AppTypography.body(size: 13, color: AppColors.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.elevated,
              hintText: 'trust.whatShare'.tr(),
              hintStyle:
                  AppTypography.body(size: 12, color: AppColors.mute),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Helpful + Recommend toggles
          SwitchListTile(
            value: _helpful,
            onChanged: (v) => setState(() => _helpful = v),
            title: Text('trust.helpful'.tr(),
                style:
                    AppTypography.body(size: 13, color: AppColors.ink)),
            activeColor: AppColors.lebenSoft,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _wouldRecommend,
            onChanged: (v) => setState(() => _wouldRecommend = v),
            title: Text('trust.wouldRecommend'.tr(),
                style:
                    AppTypography.body(size: 13, color: AppColors.ink)),
            activeColor: AppColors.lebenSoft,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),
          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_score == 0 || _submitting) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.voidColor),
                    )
                  : const Icon(LucideIcons.send, size: 16),
              label: Text(_submitting ? 'trust.sending'.tr() : 'trust.submit'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bronze,
                foregroundColor: AppColors.voidColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                disabledBackgroundColor:
                    AppColors.elevated,
                disabledForegroundColor: AppColors.mute,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('trust.later'.tr(),
                style: AppTypography.body(
                    size: 13, color: AppColors.mute)),
          ),
        ],
      ),
    );
  }
}
