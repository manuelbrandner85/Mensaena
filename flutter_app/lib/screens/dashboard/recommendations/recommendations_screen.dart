library;

import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/recommendations_repository.dart';
import '../../../widgets/shared/skeleton_card.dart';

// ── Provider ────────────────────────────────────────────────────────────────

final _recommendationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _SearchParams>((ref, params) {
  return RecommendationsRepository.search(
    category: params.category.isEmpty ? null : params.category,
    postalPrefix:
        params.postalPrefix.isEmpty ? null : params.postalPrefix,
    limit: 60,
  );
});

class _SearchParams {
  final String category;
  final String postalPrefix;

  const _SearchParams({
    this.category = '',
    this.postalPrefix = '',
  });

  @override
  bool operator ==(Object other) =>
      other is _SearchParams &&
      other.category == category &&
      other.postalPrefix == postalPrefix;

  @override
  int get hashCode => Object.hash(category, postalPrefix);
}

// ── Kategorien ───────────────────────────────────────────────────────────────

const _categories = [
  ('', 'recommendations.categories.all'),
  ('craft', 'recommendations.categories.craft'),
  ('care', 'recommendations.categories.care'),
  ('education', 'recommendations.categories.education'),
  ('health', 'recommendations.categories.health'),
  ('auto', 'recommendations.categories.auto'),
  ('garden', 'recommendations.categories.garden'),
];

const _categoryIcons = {
  'craft': LucideIcons.hammer,
  'care': LucideIcons.heart,
  'education': LucideIcons.bookOpen,
  'health': LucideIcons.stethoscope,
  'auto': LucideIcons.car,
  'garden': LucideIcons.leaf,
};

// ── Haupt-Screen ─────────────────────────────────────────────────────────────

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState
    extends ConsumerState<RecommendationsScreen> {
  String _category = '';
  String _postalPrefix = '';
  final _postalCtrl = TextEditingController();

  @override
  void dispose() {
    _postalCtrl.dispose();
    super.dispose();
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateSheet(
        onCreated: () {
          ref.invalidate(_recommendationsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = _SearchParams(
      category: _category,
      postalPrefix: _postalPrefix,
    );
    final async = ref.watch(_recommendationsProvider(params));

    return Scaffold(
      backgroundColor: AppColors.voidColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: AppColors.teal,
        foregroundColor: AppColors.ink,
        icon: const Icon(LucideIcons.plus, size: 18),
        label: Text(
          'recommendations.create'.tr(),
          style: AppTypography.body(size: 13, weight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // ── Filter-Leiste ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PLZ-Suche
                TextField(
                  controller: _postalCtrl,
                  keyboardType: TextInputType.number,
                  style: AppTypography.body(size: 13),
                  decoration: InputDecoration(
                    hintText:
                        'recommendations.postalCodePlaceholder'.tr(),
                    hintStyle: AppTypography.body(
                        size: 13, color: AppColors.mute),
                    prefixIcon: const Icon(LucideIcons.mapPin,
                        size: 16, color: AppColors.mute),
                    filled: true,
                    fillColor: AppColors.elevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                  ),
                  onChanged: (v) =>
                      setState(() => _postalPrefix = v.trim()),
                ),
                const SizedBox(height: 8),
                // Kategorie-Chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final (key, label) = _categories[i];
                      final selected = _category == key;
                      return _CategoryChip(
                        label: label.tr(),
                        icon: key.isEmpty
                            ? LucideIcons.layoutGrid
                            : (_categoryIcons[key] ??
                                LucideIcons.tag),
                        selected: selected,
                        onTap: () =>
                            setState(() => _category = key),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // ── Liste ─────────────────────────────────────────────────
          Expanded(
            child: async.when(
              loading: () =>
                  const SkeletonList(count: 5, itemHeight: 110),
              error: (_, __) => Center(
                child: Text(
                  'errors.generic'.tr(),
                  style: AppTypography.body(
                      size: 14, color: AppColors.mute),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.thumbsUp,
                            size: 36, color: AppColors.mute),
                        const SizedBox(height: 10),
                        Text(
                          'recommendations.noResults'.tr(),
                          style: AppTypography.body(
                              size: 14, color: AppColors.mute),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.teal,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async =>
                      ref.invalidate(_recommendationsProvider),
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(12, 10, 12, 100),
                    itemCount: list.length,
                    itemBuilder: (_, i) =>
                        _RecommendationTile(row: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kategorie-Chip ───────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.teal.withValues(alpha: 0.25)
              : AppColors.elevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.teal
                : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? AppColors.tealSoft : AppColors.mute,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.body(
                size: 12,
                color:
                    selected ? AppColors.tealSoft : AppColors.inkSoft,
                weight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empfehlungs-Tile ─────────────────────────────────────────────────────────

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final stars = (row['stars'] as num?)?.toInt() ?? 0;
    final type = (row['type'] as String?) ?? 'person';
    final name = (row['name'] as String?) ?? '';
    final category = (row['category'] as String?) ?? '';
    final text = (row['text'] as String?) ?? '';
    final photoUrl = row['photo_url'] as String?;
    final postalCode = row['postal_code'] as String?;
    final trustCount = (row['trust_count'] as num?)?.toInt() ?? 1;
    final profile = row['profiles'] as Map<String, dynamic>?;
    final authorName = (profile?['display_name'] as String?) ??
        (profile?['name'] as String?) ??
        'Nachbar:in';
    final createdAt = DateTime.tryParse(
            (row['created_at'] as String?) ?? '') ??
        DateTime.now();

    final categoryLabel = category.isNotEmpty
        ? 'recommendations.categories.$category'.tr()
        : '';
    final typeLabel = type == 'business'
        ? 'recommendations.typeBusiness'.tr()
        : 'recommendations.typePerson'.tr();

    final score = RecommendationsRepository.trustScore(
      avgStars: stars.toDouble(),
      neighborhoodCount: trustCount,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Foto ──────────────────────────────────────────────────
          if (photoUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: Image.network(
                photoUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Kopfzeile ─────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color:
                                AppColors.teal.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        categoryLabel.isNotEmpty
                            ? categoryLabel
                            : typeLabel,
                        style: AppTypography.body(
                          size: 10,
                          color: AppColors.tealSoft,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        typeLabel,
                        style: AppTypography.body(
                          size: 10,
                          color: AppColors.mute,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _StarsRow(stars: stars, size: 13),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Name ──────────────────────────────────────────
                Text(
                  name,
                  style: AppTypography.body(
                    size: 15,
                    color: AppColors.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.inkSoft,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // ── Trust-Score + Meta ────────────────────────────
                Row(
                  children: [
                    // Trust-Score
                    _TrustBadge(score: score, count: trustCount),
                    const Spacer(),
                    // PLZ
                    if (postalCode != null) ...[
                      const Icon(LucideIcons.mapPin,
                          size: 11, color: AppColors.mute),
                      const SizedBox(width: 3),
                      Text(
                        postalCode,
                        style: AppTypography.caption(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Autor + Datum
                    Text(
                      '$authorName · ${DateFormat('dd.MM.yy').format(createdAt)}',
                      style: AppTypography.caption(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stars Row ────────────────────────────────────────────────────────────────

class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.stars, this.size = 14});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < stars;
        return Icon(
          LucideIcons.star,
          size: size,
          color: filled ? AppColors.amber : AppColors.line,
        );
      }),
    );
  }
}

// ── Trust Badge ──────────────────────────────────────────────────────────────

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.score, required this.count});
  final double score;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? AppColors.leben
        : score >= 45
            ? AppColors.amber
            : AppColors.mute;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.shieldCheck, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          '${score.round()}%',
          style: AppTypography.body(
              size: 11, color: color, weight: FontWeight.w700),
        ),
        if (count > 1) ...[
          const SizedBox(width: 4),
          Text(
            'recommendations.trustNeighborhood'
                .tr(namedArgs: {'count': '$count'}),
            style:
                AppTypography.body(size: 10, color: AppColors.mute),
          ),
        ],
      ],
    );
  }
}

// ── Create Sheet ─────────────────────────────────────────────────────────────

class _CreateSheet extends ConsumerStatefulWidget {
  const _CreateSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends ConsumerState<_CreateSheet> {
  final _nameCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  String _type = 'person';
  String _category = 'craft';
  int _stars = 5;
  bool _submitting = false;
  Uint8List? _photoBytes;
  String? _photoExt;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _textCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 75,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();
    setState(() {
      _photoBytes = bytes;
      _photoExt = ext;
    });
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final text = _textCtrl.text.trim();
    if (name.isEmpty || text.isEmpty) return;

    setState(() => _submitting = true);

    String? photoUrl;
    if (_photoBytes != null && _photoExt != null) {
      photoUrl = await RecommendationsRepository.uploadPhoto(
          _photoBytes!, _photoExt!);
    }

    final ok = await RecommendationsRepository.create(
      type: _type,
      name: name,
      category: _category,
      stars: _stars,
      text: text,
      postalCode: _postalCtrl.text.trim().isEmpty
          ? null
          : _postalCtrl.text.trim(),
      photoUrl: photoUrl,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      widget.onCreated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('recommendations.submitSuccess'.tr()),
          backgroundColor: AppColors.teal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('recommendations.submitError'.tr()),
          backgroundColor: AppColors.herzrot,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Titel ────────────────────────────────────────────
            Row(
              children: [
                Text(
                  'recommendations.create'.tr(),
                  style: AppTypography.display(size: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x,
                      size: 18, color: AppColors.mute),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Typ-Toggle ───────────────────────────────────────
            Row(
              children: [
                _TypeButton(
                  label: 'recommendations.typePerson'.tr(),
                  icon: LucideIcons.user,
                  selected: _type == 'person',
                  onTap: () => setState(() => _type = 'person'),
                ),
                const SizedBox(width: 8),
                _TypeButton(
                  label: 'recommendations.typeBusiness'.tr(),
                  icon: LucideIcons.building2,
                  selected: _type == 'business',
                  onTap: () => setState(() => _type = 'business'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Kategorie ────────────────────────────────────────
            Text(
              'recommendations.category'.tr(),
              style:
                  AppTypography.body(size: 12, color: AppColors.mute),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories.skip(1).map((c) {
                final (key, label) = c;
                final sel = _category == key;
                return _CategoryChip(
                  label: label.tr(),
                  icon: _categoryIcons[key] ?? LucideIcons.tag,
                  selected: sel,
                  onTap: () => setState(() => _category = key),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // ── Name ─────────────────────────────────────────────
            _Label('recommendations.nameLabel'.tr()),
            const SizedBox(height: 4),
            _Input(
              controller: _nameCtrl,
              hint: 'recommendations.namePlaceholder'.tr(),
            ),
            const SizedBox(height: 12),

            // ── PLZ ──────────────────────────────────────────────
            _Label('recommendations.postalCodeLabel'.tr()),
            const SizedBox(height: 4),
            _Input(
              controller: _postalCtrl,
              hint: 'recommendations.postalCodePlaceholder'.tr(),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            // ── Sterne ───────────────────────────────────────────
            _Label('recommendations.stars'.tr()),
            const SizedBox(height: 6),
            Row(
              children: List.generate(5, (i) {
                final filled = i < _stars;
                return GestureDetector(
                  onTap: () => setState(() => _stars = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      LucideIcons.star,
                      size: 28,
                      color: filled ? AppColors.amber : AppColors.line,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // ── Text ─────────────────────────────────────────────
            _Label('recommendations.textHint'.tr()),
            const SizedBox(height: 4),
            TextField(
              controller: _textCtrl,
              maxLines: 4,
              style: AppTypography.body(size: 13),
              decoration: InputDecoration(
                hintText: 'recommendations.textHint'.tr(),
                hintStyle:
                    AppTypography.body(size: 13, color: AppColors.mute),
                filled: true,
                fillColor: AppColors.elevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),

            // ── Foto ─────────────────────────────────────────────
            if (_photoBytes == null)
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.line,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.image,
                          size: 16, color: AppColors.mute),
                      const SizedBox(width: 8),
                      Text(
                        'recommendations.photoOptional'.tr(),
                        style: AppTypography.body(
                            size: 13, color: AppColors.mute),
                      ),
                    ],
                  ),
                ),
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _photoBytes!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _photoBytes = null;
                        _photoExt = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.deep.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.x,
                            size: 14, color: AppColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // ── Submit ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.ink,
                        ),
                      )
                    : Text(
                        'recommendations.submit'.tr(),
                        style: AppTypography.body(
                            size: 14, weight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hilfwidgets ──────────────────────────────────────────────────────────────

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.teal.withValues(alpha: 0.2)
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected
                      ? AppColors.tealSoft
                      : AppColors.mute),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.body(
                  size: 13,
                  color: selected
                      ? AppColors.tealSoft
                      : AppColors.inkSoft,
                  weight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.body(
          size: 12, color: AppColors.mute, weight: FontWeight.w600),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTypography.body(size: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            AppTypography.body(size: 13, color: AppColors.mute),
        filled: true,
        fillColor: AppColors.elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }
}
