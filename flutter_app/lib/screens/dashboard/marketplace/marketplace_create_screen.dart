import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/location_service.dart';
import '../../../widgets/effects/mini_confetti.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../services/open_food_facts_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../shared/barcode_scanner_screen.dart';
import '../../../widgets/shared/readable_width.dart';

class MarketplaceCreateScreen extends ConsumerStatefulWidget {
  const MarketplaceCreateScreen({super.key});

  @override
  ConsumerState<MarketplaceCreateScreen> createState() =>
      _MarketplaceCreateScreenState();
}

class _MarketplaceCreateScreenState
    extends ConsumerState<MarketplaceCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _price = TextEditingController();
  final _tags = TextEditingController();
  String _listingType = 'verschenken';
  String _category = 'haushalt';
  String _condition = 'gut';
  bool _negotiable = false;
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _submitting = false;
  bool _titleError = false;
  bool _descError = false;
  bool _uploading = false;
  String? _error;
  final List<File> _images = [];
  static const int _maxImages = 5;
  final ImagePicker _picker = ImagePicker();

  static const List<({String value, String i18n, String emoji})> _types = [
    (value: 'verschenken', i18n: 'marketplace.typeVerschenken', emoji: '🎁'),
    (value: 'tauschen', i18n: 'marketplace.typeTauschen', emoji: '🔄'),
    (value: 'verkaufen', i18n: 'marketplace.typeVerkaufen', emoji: '💶'),
    (value: 'leihen', i18n: 'marketplace.typeLeihen', emoji: '📅'),
  ];

  // value = stabil (DB/Web-Parität), i18n = übersetztes Label.
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
    _price.dispose();
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
      // Standort bleibt optional.
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

  /// Öffnet Barcode-Scanner → Open Food Facts Lookup → füllt Titel +
  /// Beschreibung. Snackbar bei Erfolg/Fehler.
  Future<void> _scanAndFillFromFood() async {
    final code = await BarcodeScannerScreen.open(context,
        title: 'create.scanFood'.tr());
    if (code == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.elevated,
      duration: const Duration(seconds: 1),
      content: Text('marketplace.searching'.tr(namedArgs: {'code': code}),
          style: AppTypography.body(size: 12, color: AppColors.inkSoft)),
    ));
    // Sprache mitgeben → OFF liefert wo möglich lokalisierte
    // product_name_<lang>, ingredients_text_<lang>, categories_<lang>.
    final p = await OpenFoodFactsService.lookup(
      code,
      lang: context.locale.languageCode,
    );
    if (!mounted) return;
    if (p == null) {
      AppSnackBar.info(context, 'marketplace.productNotFound'.tr(namedArgs: {'code': code}));
      return;
    }
    setState(() {
      _title.text = p.displayTitle ?? p.name;
      final parts = <String>[
        if (p.quantity != null && p.quantity!.isNotEmpty) 'Menge: ${p.quantity}',
        if (p.ingredients != null && p.ingredients!.isNotEmpty)
          'Zutaten: ${p.ingredients}',
        if (p.categories != null && p.categories!.isNotEmpty)
          'Kategorie: ${p.categories!.split(",").take(2).join(", ")}',
      ];
      if (parts.isNotEmpty) _desc.text = parts.join('\n\n');
    });

    // Foto vom OFF-Server auto-anhängen, falls noch Platz im _images-Array
    // ist. Failsafe — wenn der Download scheitert, kein UI-Fehler (der User
    // hat ja Titel + Beschreibung schon).
    if (p.imageUrl != null && _images.length < _maxImages) {
      try {
        final res = await http
            .get(Uri.parse(p.imageUrl!))
            .timeout(const Duration(seconds: 6));
        if (mounted && res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final tmpDir = await getTemporaryDirectory();
          final file = File(
              '${tmpDir.path}/off_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(res.bodyBytes);
          if (mounted) setState(() => _images.add(file));
        }
      } catch (_) {/* still title+desc gefüllt — kein Snackbar nötig */}
    }
    if (!mounted) return;

    AppSnackBar.success(context, '✓ ${'marketplace.inserted'.tr(namedArgs: {'name': p.name})}');
  }

  /// Bottom-Sheet mit Gallery/Camera-Optionen. Picked Image → _images.
  Future<void> _pickImage() async {
    if (_images.length >= _maxImages) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
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
              leading: const Icon(LucideIcons.image,
                  color: AppColors.amber),
              title: Text('marketplace.create.pickGallery'.tr(),
                  style:
                      AppTypography.body(size: 14, color: AppColors.ink)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera,
                  color: AppColors.amber),
              title: Text('marketplace.create.pickCamera'.tr(),
                  style:
                      AppTypography.body(size: 14, color: AppColors.ink)),
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

    // Upload images first (if any).
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
          // skip failed individual uploads; continue with the rest.
        }
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }

    // Create listing.
    final id = await MarketplaceRepository.create(
      title: _title.text.trim(),
      description: _desc.text.trim(),
      category: _category,
      listingType: _listingType,
      conditionState: _condition,
      price: _listingType == 'verkaufen'
          ? double.tryParse(_price.text.trim().replaceAll(',', '.'))
          : null,
      priceType: _negotiable ? 'negotiable' : 'fixed',
      locationText: _location.text.trim().isEmpty
          ? null
          : _location.text.trim(),
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

    // Patch images into the row (separated from create() to keep its API
    // stable). Failure here is non-fatal — the listing exists either way.
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
      title: 'create.marketplaceTitle'.tr(),
      currentRoute: '/dashboard/marketplace',
      body: SafeArea(
        child: ReadableWidth(
            child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('marketplace.type'.tr(), style: AppTypography.label(size: 10)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: _types.map((t) {
                final active = t.value == _listingType;
                return GestureDetector(
                  onTap: () => setState(() => _listingType = t.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.amber.withValues(alpha: 0.2)
                          : AppColors.surface.withValues(alpha: 0.5),
                      border: Border.all(
                        color: active ? AppColors.amber : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          t.i18n.tr(),
                          style: AppTypography.label(
                            size: 10,
                            color: active
                                ? AppColors.amber
                                : AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scanAndFillFromFood,
              icon: const Icon(LucideIcons.scanLine, size: 16),
              label: Text('marketplace.scanBarcode'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bronze,
                side: BorderSide(
                    color: AppColors.bronze.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: 10),
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
            // ── Bilder (max 5) ──────────────────────────────────────────
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
                        child: Image.file(
                          f,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          cacheHeight: 160,
                        ),
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
                            child: const Icon(
                              LucideIcons.x,
                              size: 12,
                              color: Colors.white,
                            ),
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
                        border: Border.all(
                          color: AppColors.line,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.plus,
                              size: 20, color: AppColors.amber),
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
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(labelText: 'create.categoryLabel'.tr()),
              dropdownColor: AppColors.surface,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              items: _categories.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value.tr())))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _condition,
              decoration: InputDecoration(labelText: 'create.condition'.tr()),
              dropdownColor: AppColors.surface,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              items: _conditions.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value.tr())))
                  .toList(),
              onChanged: (v) => setState(() => _condition = v ?? _condition),
            ),
            if (_listingType == 'verkaufen') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(labelText: 'create.priceEuro'.tr()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.amber,
                value: _negotiable,
                onChanged: (v) => setState(() => _negotiable = v),
                title: Text('marketplace.priceNegotiable'.tr(),
                    style:
                        AppTypography.body(size: 14, color: AppColors.ink)),
              ),
            ],
            const SizedBox(height: 10),
            // Schlagwörter — bessere Auffindbarkeit über die Suche.
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
                              strokeWidth: 2, color: AppColors.bronze),
                        )
                      : Icon(
                          _lat != null
                              ? LucideIcons.mapPin
                              : LucideIcons.locate,
                          size: 18,
                          color: _lat != null
                              ? AppColors.bronze
                              : AppColors.inkSoft,
                        ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.herzrotWarm,
                ),
              ),
            ],
            if (_uploading) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('marketplace.create.uploading'.tr(),
                      style: AppTypography.body(
                          size: 13, color: AppColors.inkSoft)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(_submitting
                  ? 'marketplace.saving'.tr()
                  : 'marketplace.createButton'.tr()),
            ),
          ],
        )),
      ),
    );
  }
}
