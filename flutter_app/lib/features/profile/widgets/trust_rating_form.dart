import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/cinema_input.dart';
import '../../../core/widgets/cinema_toast.dart';
import '../../../core/widgets/glow_button.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/supabase/database_service.dart';

/// Sheet-Inhalt zum Abgeben einer Trust-Bewertung fuer ein anderes Profil.
/// 1..5 Sterne (klickbar) + optionaler Kommentar.
class TrustRatingForm extends ConsumerStatefulWidget {
  final String ratedUserId;
  final String? ratedUserName;
  final VoidCallback? onSubmitted;

  const TrustRatingForm({
    super.key,
    required this.ratedUserId,
    this.ratedUserName,
    this.onSubmitted,
  });

  @override
  ConsumerState<TrustRatingForm> createState() => _TrustRatingFormState();
}

class _TrustRatingFormState extends ConsumerState<TrustRatingForm> {
  int _rating = 0;
  bool _submitting = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    if (_rating < 1) {
      CinemaToast.show(
        context,
        variant: ToastVariant.warning,
        message: 'Bitte mindestens 1 Stern vergeben.',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await db.submitTrustRating(
        raterId: me.id,
        ratedUserId: widget.ratedUserId,
        rating: _rating,
        comment: _commentController.text,
      );
      // Refresh provider that drives the Bewertungen-Tab.
      ref.invalidate(userRatingsProvider(widget.ratedUserId));
      if (!mounted) return;
      Navigator.of(context).pop();
      CinemaToast.show(
        context,
        variant: ToastVariant.success,
        message: 'Bewertung gespeichert.',
      );
      widget.onSubmitted?.call();
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: 'Fehler: $e',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.ratedUserName == null || widget.ratedUserName!.isEmpty
        ? 'Bewerten'
        : '${widget.ratedUserName} bewerten';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: MnTypography.display(size: 22)),
        const SizedBox(height: 6),
        Text(
          'Wie war deine Erfahrung? Deine Bewertung hilft anderen Nachbar*innen.',
          style: MnTypography.body(color: MnColors.inkSoft, size: 13),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < _rating;
            return GestureDetector(
              onTap: () => setState(() => _rating = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  LucideIcons.star,
                  size: 40,
                  color: filled ? MnColors.trust : MnColors.ghost,
                  shadows: filled
                      ? [
                          Shadow(
                            color: MnColors.trust.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        CinemaInput(
          controller: _commentController,
          label: 'Kommentar (optional)',
          placeholder: 'Was moechtest du teilen?',
          variant: CinemaInputVariant.multiline,
          maxLines: 4,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GlowButton(
                label: 'Abbrechen',
                variant: GlowVariant.ghost,
                fullWidth: true,
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlowButton(
                label: _submitting ? 'Sende...' : 'Bewerten',
                variant: GlowVariant.primary,
                fullWidth: true,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Provider fuer die Bewertungs-Liste eines Users (genutzt im Bewertungen-Tab).
/// Hier definiert, damit der Submit-Pfad ihn invalidieren kann.
final userRatingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return db.listUserRatings(userId);
});
