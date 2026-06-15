import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/mini_confetti.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../widgets/shared/readable_width.dart';

/// Vereinfachter Create-Flow für 'giveaway' und 'swap' — kein Preis-Feld.
class SharingCreateScreen extends ConsumerStatefulWidget {
  const SharingCreateScreen({super.key});

  @override
  ConsumerState<SharingCreateScreen> createState() =>
      _SharingCreateScreenState();
}

class _SharingCreateScreenState
    extends ConsumerState<SharingCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _tags = TextEditingController();

  String _listingType = 'giveaway';
  String _category = 'haushalt';
  String _condition = 'gut';
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _submitting = false;
  bool _uploading = false;
  bool _titleError = false;
  bool _descError = false;
  String? _error;
  final List<File> _images = [];
  static const int _maxImages = 5;
  final ImagePicker _picker = ImagePicker();

  static const Map<String, String> _categories = {
    'haushalt': 'marketplace.catHaushalt',
    'kleidung': 'marketplace.catKleidung',
    'kinder': 'marketplace.catKinder',
    'moebel': 'marketplace.catMoebel',
    'elektronik': 'marketplace.catElektronik',
    'sport': 'marketplace.catSport',
    'buecher': 'marketplace.catBuecher',
    'garten': 'marketplace.catGarten',
    'werkzeug': 'marketplace.catWerkzeug',
    'sonstiges': 'marketplace.catSonstiges',
  };

  static const Map<String, String> _conditions = {
    'neu': 'marketplace.condNeu',
    'sehr_gut': 'marketplace.condSehrGut',
    'gut': 'marketplace.condGut',
    'gebraucht': 'marketplace.condGebraucht',
    'defekt': 'marketplace.condDefekt',
  };

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (_location.text.trim().isEmpty) {
          _location.text =
              '${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
        }
      });
    } catch (_) {
      // Standort optional.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<String> _parseTags() => _tags.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .take(8)
      .toList();

  Future<void> _pickImage() async {
    if (_images.length >= _maxImages) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.image, color: AppColors.primary500),
              title: Text('marketplace.create.pickGallery'.tr(),
                  style: AppTypography.body(size: 14, color: AppColors.ink)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera, color: AppColors.primary500),
              title: Text('marketplace.create.pickCamera'.tr(),
                  style: AppTypography.body(size: 14, color: AppColors.ink)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      setState(() => _images.add(File(picked.path)));
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, 'marketplace.create.uploadFailed'.tr());
    }
  }

  Future<void> _submit() async {
    final titleEmpty = _title.text.trim().isEmpty;
    final descEmpty = _desc.text.trim().isEmpty;
    if (titleEmpty || descEmpty) {
      setState(() {
        _titleError = titleEmpty;
        _descError = descEmpty;
        _error = 'create.fillTitleAndDesc'.tr();
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final imageUrls = <String>[];
    final uid = SupabaseService.currentUser?.id;
    if (_images.isNotEmpty && uid != null) {
      setState(() => _uploading = true);
      for (final file in _images) {
        try {
          final bytes = await file.readAsBytes();
          final ext = file.path.split('.').last.toLowerCase();
          final url = await MarketplaceRepository.uploadListingImage(
            bytes: bytes,
            userId: uid,
            fileExt: ext,
          );
          if (url != null) imageUrls.add(url);
        } catch (_) {
          // skip failed uploads
        }
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }

    final id = await MarketplaceRepository.create(
      title: _title.text.trim(),
      description: _desc.text.trim(),
      category: _category,
      listingType: _listingType,
      conditionState: _condition,
      locationText:
          _location.text.trim().isEmpty ? null : _location.text.trim(),
      latitude: _lat,
      longitude: _lng,
      tags: _parseTags(),
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

    if (imageUrls.isNotEmpty) {
      await MarketplaceRepository.updateImages(id, imageUrls);
    }

    if (!mounted) return;
    Haptics.success();
    MiniConfetti.show(context);
    AppSnackBar.success(context, 'common.created'.tr());
    context.push('/dashboard/marketplace/$id');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'sharing.createTitle'.tr(),
      currentRoute: '/dashboard/sharing',
      body: SafeArea(
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Typ-Toggle: Giveaway / Swap ──────────────────────────
              Text('sharing.typeLabel'.tr(),
                  style: AppTypography.label(size: 10)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeButton(
                    emoji: '🎁',
                    label: 'sharing.typeGiveaway'.tr(),
                    active: _listingType == 'giveaway',
                    color: AppColors.leben,
                    onTap: () => setState(() => _listingType = 'giveaway'),
                  ),
                  const SizedBox(width: 8),
                  _TypeButton(
                    emoji: '🔄',
                    label: 'sharing.typeSwap'.tr(),
                    active: _listingType == 'swap',
                    color: AppColors.teal,
                    onTap: () => setState(() => _listingType = 'swap'),
                  ),
                ],
              ),
              // Info-Hint je Typ
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  _listingType == 'giveaway'
                      ? 'sharing.hintGiveaway'.tr()
                      : 'sharing.hintSwap'.tr(),
                  style: AppTypography.body(
                      size: 12, color: AppColors.inkSoft),
                ),
              ),
              const SizedBox(height: 10),
              // ── Titel ────────────────────────────────────────────────
              TextField(
                controller: _title,
                maxLength: 120,
                style: AppTypography.body(size: 15, color: AppColors.ink),
                onChanged: _titleError
                    ? (_) => setState(() => _titleError = false)
                    : null,
                decoration: InputDecoration(
                  labelText: 'create.title'.tr(),
                  errorText: _titleError ? 'create.titleRequired'.tr() : null,
                ),
              ),
              const SizedBox(height: 10),
              // ── Beschreibung ─────────────────────────────────────────
              TextField(
                controller: _desc,
                maxLines: 4,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                onChanged: _descError
                    ? (_) => setState(() => _descError = false)
                    : null,
                decoration: InputDecoration(
                  labelText: 'create.description'.tr(),
                  alignLabelWithHint: true,
                  errorText: _descError ? 'create.descRequired'.tr() : null,
                ),
              ),
              const SizedBox(height: 12),
              // ── Bilder ───────────────────────────────────────────────
              Text('marketplace.create.images'.tr(),
                  style: AppTypography.label(size: 10)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._images.asMap().entries.map((e) {
                    final i = e.key;
                    final f = e.value;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(f,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              cacheWidth: 160,
                              cacheHeight: 160),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _images.removeAt(i)),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.herzrot,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.surface, width: 2),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(LucideIcons.x,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (_images.length < _maxImages)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.plus,
                                size: 20, color: AppColors.primary500),
                            const SizedBox(height: 2),
                            Text(
                              'marketplace.create.addImage'.tr(),
                              style: AppTypography.label(
                                  size: 8, color: AppColors.inkSoft),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Kategorie ────────────────────────────────────────────
              DropdownButtonFormField<String>(
                value: _category,
                decoration:
                    InputDecoration(labelText: 'create.categoryLabel'.tr()),
                dropdownColor: AppColors.surface,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                items: _categories.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value.tr())))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 10),
              // ── Zustand ──────────────────────────────────────────────
              DropdownButtonFormField<String>(
                value: _condition,
                decoration:
                    InputDecoration(labelText: 'create.condition'.tr()),
                dropdownColor: AppColors.surface,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                items: _conditions.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value.tr())))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _condition = v ?? _condition),
              ),
              const SizedBox(height: 10),
              // ── Schlagwörter ─────────────────────────────────────────
              TextField(
                controller: _tags,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'marketplace.tags'.tr(),
                  hintText: 'marketplace.tagsHint'.tr(),
                  prefixIcon: const Icon(LucideIcons.tag, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              // ── Standort ─────────────────────────────────────────────
              TextField(
                controller: _location,
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
                                strokeWidth: 2,
                                color: AppColors.primary500),
                          )
                        : Icon(
                            _lat != null
                                ? LucideIcons.mapPin
                                : LucideIcons.locate,
                            size: 18,
                            color: _lat != null
                                ? AppColors.primary500
                                : AppColors.inkSoft,
                          ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: AppTypography.body(
                        size: 13, color: AppColors.herzrotWarm)),
              ],
              if (_uploading) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary500),
                    ),
                    const SizedBox(width: 10),
                    Text('marketplace.create.uploading'.tr(),
                        style: AppTypography.body(
                            size: 13, color: AppColors.inkSoft)),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
                label: Text(_submitting
                    ? 'marketplace.saving'.tr()
                    : 'sharing.submitButton'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.emoji,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : AppColors.elevated,
          border: Border.all(color: active ? color : AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.body(
                size: 13,
                color: active ? color : AppColors.inkSoft,
                weight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
