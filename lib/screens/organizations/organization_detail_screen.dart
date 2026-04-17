import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/organization_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/models/organization.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/section_header.dart';
import 'package:mensaena/widgets/badge_widget.dart';

class OrganizationDetailScreen extends ConsumerStatefulWidget {
  final String orgId;
  const OrganizationDetailScreen({super.key, required this.orgId});

  @override
  ConsumerState<OrganizationDetailScreen> createState() =>
      _OrganizationDetailScreenState();
}

class _OrganizationDetailScreenState
    extends ConsumerState<OrganizationDetailScreen> {
  // Review-Formular
  bool _showReviewForm = false;
  int _reviewRating = 0;
  final _reviewController = TextEditingController();
  bool _submittingReview = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte zuerst anmelden')),
        );
      }
      return;
    }
    if (_reviewRating == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte eine Bewertung auswaehlen')),
        );
      }
      return;
    }

    setState(() => _submittingReview = true);
    try {
      final service = ref.read(organizationServiceProvider);
      await service.createReview(
        orgId: widget.orgId,
        userId: userId,
        rating: _reviewRating,
        comment: _reviewController.text.trim().isNotEmpty
            ? _reviewController.text.trim()
            : null,
      );
      setState(() {
        _showReviewForm = false;
        _reviewRating = 0;
        _reviewController.clear();
      });
      ref.invalidate(organizationReviewsProvider(widget.orgId));
      ref.invalidate(organizationDetailProvider(widget.orgId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bewertung abgeschickt!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(organizationDetailProvider(widget.orgId));
    final reviewsAsync =
        ref.watch(organizationReviewsProvider(widget.orgId));

    return Scaffold(
      body: orgAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Fehler: $e',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
        data: (org) {
          if (org == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.business_outlined,
                        size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text('Organisation nicht gefunden',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // -- AppBar --
              SliverAppBar(
                pinned: true,
                title: Text(org.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  if (org.website != null)
                    IconButton(
                      icon: const Icon(Icons.language),
                      tooltip: 'Webseite oeffnen',
                      onPressed: () =>
                          launchUrl(Uri.parse(org.website!)),
                    ),
                ],
              ),

              // -- Content --
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // -- Header mit Emoji + Name + Kategorie --
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.primary50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.border),
                            ),
                            child: Center(
                              child: Text(
                                org.orgCategory.emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  org.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    AppBadge(
                                      label: org.orgCategory.label,
                                      color: AppColors.primary500,
                                      small: true,
                                    ),
                                    if (org.isVerified) ...[
                                      const SizedBox(width: 6),
                                      const AppBadge(
                                        label: '✓ Verifiziert',
                                        color: AppColors.success,
                                        small: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // -- Bewertung --
                      _RatingSummary(
                        averageRating: org.averageRating ?? 0,
                        reviewCount: org.reviewCount ?? 0,
                      ),
                      const SizedBox(height: 20),

                      // -- Beschreibung --
                      if (org.description != null &&
                          org.description!.isNotEmpty) ...[
                        const SectionHeader(
                          title: 'Beschreibung',
                          icon: Icons.description_outlined,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            org.description!,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // -- Kontaktinformationen --
                      const SectionHeader(
                        title: 'Kontakt',
                        icon: Icons.contact_phone_outlined,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            // Adresse
                            if (org.fullAddress.isNotEmpty)
                              _ContactTile(
                                icon: Icons.location_on_outlined,
                                iconColor: AppColors.emergency,
                                title: 'Adresse',
                                subtitle: org.fullAddress,
                                trailing: org.country != null
                                    ? Text(org.countryFlag,
                                        style: const TextStyle(
                                            fontSize: 20))
                                    : null,
                              ),
                            // Telefon
                            if (org.phone != null)
                              _ContactTile(
                                icon: Icons.phone_outlined,
                                iconColor: AppColors.success,
                                title: 'Telefon',
                                subtitle: org.phone!,
                                onTap: () => launchUrl(
                                    Uri.parse('tel:${org.phone}')),
                              ),
                            // E-Mail
                            if (org.email != null)
                              _ContactTile(
                                icon: Icons.email_outlined,
                                iconColor: AppColors.info,
                                title: 'E-Mail',
                                subtitle: org.email!,
                                onTap: () => launchUrl(Uri.parse(
                                    'mailto:${org.email}')),
                              ),
                            // Webseite
                            if (org.website != null)
                              _ContactTile(
                                icon: Icons.language,
                                iconColor: AppColors.primary500,
                                title: 'Webseite',
                                subtitle: org.website!,
                                onTap: () => launchUrl(
                                    Uri.parse(org.website!)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // -- Angebote / Services --
                      if (org.services.isNotEmpty) ...[
                        const SectionHeader(
                          title: 'Angebote',
                          icon: Icons.volunteer_activism_outlined,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: org.services.map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary50,
                                borderRadius:
                                    BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary500
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary700,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // -- Tags --
                      if (org.tags.isNotEmpty) ...[
                        const SectionHeader(
                          title: 'Stichworte',
                          icon: Icons.tag,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: org.tags.map((t) {
                            return Chip(
                              label: Text(t,
                                  style: const TextStyle(
                                      fontSize: 12)),
                              backgroundColor:
                                  AppColors.surfaceVariant,
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // -- Bewertungen --
                      SectionHeader(
                        title: 'Bewertungen',
                        icon: Icons.rate_review_outlined,
                        actionLabel: _showReviewForm
                            ? 'Abbrechen'
                            : 'Bewertung schreiben',
                        onAction: () {
                          setState(() {
                            _showReviewForm = !_showReviewForm;
                            if (!_showReviewForm) {
                              _reviewRating = 0;
                              _reviewController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // Bewertungs-Formular
                      if (_showReviewForm) ...[
                        _ReviewForm(
                          rating: _reviewRating,
                          controller: _reviewController,
                          isSubmitting: _submittingReview,
                          onRatingChanged: (r) =>
                              setState(() => _reviewRating = r),
                          onSubmit: _submitReview,
                          onCancel: () {
                            setState(() {
                              _showReviewForm = false;
                              _reviewRating = 0;
                              _reviewController.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Bewertungsliste
                      reviewsAsync.when(
                        data: (reviews) {
                          if (reviews.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius:
                                    BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.border),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.rate_review_outlined,
                                      size: 40,
                                      color: AppColors.textMuted),
                                  SizedBox(height: 8),
                                  Text(
                                    'Noch keine Bewertungen',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Sei der Erste und teile deine Erfahrung!',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: reviews.map((review) {
                              return _ReviewCard(review: review);
                            }).toList(),
                          );
                        },
                        loading: () => Column(
                          children: List.generate(
                            2,
                            (_) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8),
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        error: (e, _) => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.border),
                          ),
                          child: Text(
                            'Bewertungen konnten nicht geladen werden: $e',
                            style: const TextStyle(
                                color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -- Bewertungs-Zusammenfassung --
class _RatingSummary extends StatelessWidget {
  final double averageRating;
  final int reviewCount;

  const _RatingSummary({
    required this.averageRating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Durchschnittsnote
          Column(
            children: [
              Text(
                averageRating > 0
                    ? averageRating.toStringAsFixed(1)
                    : '–',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              _StarRow(rating: averageRating, size: 16),
              const SizedBox(height: 4),
              Text(
                '$reviewCount ${reviewCount == 1 ? 'Bewertung' : 'Bewertungen'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Sterne-Verteilung
          Expanded(
            child: Column(
              children: List.generate(5, (index) {
                final starNum = 5 - index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Text(
                        '$starNum',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star,
                          size: 12, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: reviewCount > 0 ? 0 : 0,
                            backgroundColor: AppColors.border,
                            color: const Color(0xFFFBBF24),
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Sterne-Reihe --
class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  final bool interactive;
  final ValueChanged<int>? onRatingChanged;

  const _StarRow({
    required this.rating,
    this.size = 20,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isFilled = starIndex <= rating;
        final isHalf =
            starIndex > rating && starIndex - 0.5 <= rating;

        return GestureDetector(
          onTap: interactive
              ? () => onRatingChanged?.call(starIndex)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              isFilled
                  ? Icons.star
                  : isHalf
                      ? Icons.star_half
                      : Icons.star_border,
              size: size,
              color: isFilled || isHalf
                  ? const Color(0xFFFBBF24)
                  : AppColors.textMuted.withValues(alpha: 0.4),
            ),
          ),
        );
      }),
    );
  }
}

// -- Kontakt-Kachel --
class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ContactTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: onTap != null
                          ? AppColors.primary500
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// -- Bewertungs-Formular --
class _ReviewForm extends StatelessWidget {
  final int rating;
  final TextEditingController controller;
  final bool isSubmitting;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _ReviewForm({
    required this.rating,
    required this.controller,
    required this.isSubmitting,
    required this.onRatingChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary500.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deine Bewertung',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Sterne
          Center(
            child: _StarRow(
              rating: rating.toDouble(),
              size: 36,
              interactive: true,
              onRatingChanged: onRatingChanged,
            ),
          ),
          if (rating > 0) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                _ratingLabel(rating),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Kommentar
          TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Beschreibe deine Erfahrung (optional)...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSubmitting ? null : onCancel,
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isSubmitting || rating == 0
                      ? null
                      : onSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Absenden'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Mangelhaft';
      case 2:
        return 'Ausreichend';
      case 3:
        return 'Befriedigend';
      case 4:
        return 'Gut';
      case 5:
        return 'Sehr gut';
      default:
        return '';
    }
  }
}

// -- Bewertungs-Karte --
class _ReviewCard extends StatelessWidget {
  final OrganizationReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    const name = 'Nutzer';
    const String? avatar = null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kopfzeile
          Row(
            children: [
              AvatarWidget(
                imageUrl: avatar,
                name: name,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      timeago.format(review.createdAt, locale: 'de'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StarRow(
                rating: review.rating.toDouble(),
                size: 14,
              ),
            ],
          ),
          // Kommentar
          if (review.comment != null &&
              review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}