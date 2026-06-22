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
import '../../../widgets/forms/create_post_scaffold.dart';
import '../../../widgets/forms/location_picker_field.dart';
import '../../shared/barcode_scanner_screen.dart';
import '../../../utils/form_validators.dart';

class MarketplaceCreateScreen extends ConsumerStatefulWidget {
  const MarketplaceCreateScreen({super.key});

  @override
  ConsumerState<MarketplaceCreateScreen> createState() =>
      _MarketplaceCreateScreenState();
}

class _MarketplaceCreateScreenState
    extends ConsumerState<MarketplaceCreateScreen> {
  final _formKey = GlobalKey<FormState>();
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
  bool _uploading = false;
  String? _error;
  final List<File> _images = [];
  static const int _maxImages = 5;
  final ImagePicker _picker = ImagePicker();
  // Mehrwert-Felder (Batch B): Menge, Versand, Abhol-/Lieferradius, Auto-Ablauf.
  final _quantity = TextEditingController();
  bool _shipping = false;
  double _radiusKm = 0; // 0 = egal
  DateTime? _expiresAt;

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
    _quantity.dispose();
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      Haptics.error();
      setState(() => _error = null);
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
      // Teil-/Totalausfall des Uploads sichtbar machen statt stillschweigend
      // ein Inserat ohne Bilder zu erstellen.
      if (imageUrls.length < _images.length) {
        AppSnackBar.error(context, 'marketplace.create.uploadFailed'.tr());
      }
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
      quantity: int.tryParse(_quantity.text.trim()),
      shippingAvailable: _shipping,
      radiusKm: _radiusKm <= 0 ? null : _radiusKm.round(),
      expiresAt: _expiresAt,
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
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: CreatePostScaffold(
        title: 'create.marketplaceTitle'.tr(),
        subtitle: 'marketplace.createSubtitle'.tr(),
        accent: AppColors.amber,
        icon: Icons.storefront,
        returnRoute: '/dashboard/marketplace',
        sections: [
          // ── Live-Vorschau: zeigt, wie die Anzeige in der Liste aussieht ──
          CreateCard(
            title: 'create.preview'.tr(),
            icon: LucideIcons.eye,
            child: ListenableBuilder(
              listenable: Listenable.merge([_title, _price]),
              builder: (context, _) {
                final title = _title.text.trim();
                final typeOpt = _types.firstWhere(
                    (t) => t.value == _listingType,
                    orElse: () => _types.first);
                final isSell = _listingType == 'verkaufen';
                final priceTxt = _price.text.trim().isEmpty
                    ? '—'
                    : '${_price.text.trim()} €';
                return Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _images.isNotEmpty
                          ? Image.file(_images.first,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              cacheWidth: 128,
                              cacheHeight: 128,
                              errorBuilder: (_, __, ___) => Container(
                                    width: 64,
                                    height: 64,
                                    color: AppColors.surface,
                                    alignment: Alignment.center,
                                    child: const Icon(LucideIcons.imageOff,
                                        color: AppColors.herzrot, size: 24),
                                  ))
                          : Container(
                              width: 64,
                              height: 64,
                              color: AppColors.surface,
                              alignment: Alignment.center,
                              child: const Icon(Icons.storefront,
                                  color: AppColors.mute, size: 26),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title.isEmpty ? 'create.title'.tr() : title,
                            style: AppTypography.display(
                                size: 15, color: AppColors.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.amber.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${typeOpt.emoji} ${typeOpt.i18n.tr()}',
                                  style: AppTypography.label(
                                      size: 10, color: AppColors.amber),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                isSell ? priceTxt : '🎁',
                                style: AppTypography.body(
                                    size: 14,
                                    color: AppColors.ink,
                                    weight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Art + Barcode-Scan ──────────────────────────────────────
          CreateCard(
            title: 'marketplace.type'.tr(),
            icon: LucideIcons.layoutGrid,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
                            Text(t.emoji,
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              t.i18n.tr(),
                              style: AppTypography.label(
                                size: 10,
                                color:
                                    active ? AppColors.amber : AppColors.inkSoft,
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
              ],
            ),
          ),

          // ── Titel & Beschreibung ────────────────────────────────────
          CreateCard(
            title: 'create.sectionDetails'.tr(),
            icon: LucideIcons.fileText,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  validator: FormValidators.lengthBetween(3, 120),
                  style: AppTypography.body(size: 15, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'create.title'.tr(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _desc,
                  maxLines: 4,
                  validator: FormValidators.lengthBetween(10, 2000),
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'create.description'.tr(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),

          // ── Bilder (max 5) ──────────────────────────────────────────
          CreateCard(
            title: 'create.sectionImages'.tr(),
            icon: LucideIcons.image,
            child: Wrap(
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
                          onTap: () => setState(() => _images.removeAt(i)),
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
          ),

          // ── Kategorie, Zustand & Preis ──────────────────────────────
          CreateCard(
            title: 'create.categoryLabel'.tr(),
            icon: LucideIcons.tag,
            child: Column(
              children: [
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
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 10),
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
                if (_listingType == 'verkaufen') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: FormValidators.positiveNumberOptional,
                    style: AppTypography.body(size: 14, color: AppColors.ink),
                    decoration:
                        InputDecoration(labelText: 'create.priceEuro'.tr()),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.amber,
                    value: _negotiable,
                    onChanged: (v) => setState(() => _negotiable = v),
                    title: Text('marketplace.priceNegotiable'.tr(),
                        style: AppTypography.body(
                            size: 14, color: AppColors.ink)),
                  ),
                ],
              ],
            ),
          ),

          // ── Mehr Details: Menge, Versand, Radius, Ablauf ───────────
          CreateCard(
            title: 'marketplace.moreDetails'.tr(),
            icon: LucideIcons.sliders,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'marketplace.quantity'.tr(),
                    hintText: '1',
                    prefixIcon: const Icon(LucideIcons.hash, size: 18),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.amber,
                  value: _shipping,
                  onChanged: (v) => setState(() => _shipping = v),
                  secondary: const Icon(LucideIcons.truck,
                      size: 18, color: AppColors.bronze),
                  title: Text('marketplace.shippingAvailable'.tr(),
                      style:
                          AppTypography.body(size: 14, color: AppColors.ink)),
                ),
                const SizedBox(height: 4),
                Text(
                  _radiusKm <= 0
                      ? 'marketplace.deliveryRadiusAny'.tr()
                      : 'marketplace.deliveryRadiusKm'.tr(
                          namedArgs: {'km': _radiusKm.round().toString()}),
                  style:
                      AppTypography.label(size: 11, color: AppColors.inkSoft),
                ),
                Slider(
                  value: _radiusKm,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: AppColors.amber,
                  label: _radiusKm <= 0 ? '∞' : '${_radiusKm.round()} km',
                  onChanged: (v) => setState(() => _radiusKm = v),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _expiresAt ?? now.add(const Duration(days: 30)),
                      firstDate: now.add(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _expiresAt = picked);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.calendarClock,
                            size: 18, color: AppColors.bronze),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _expiresAt == null
                                ? 'marketplace.autoExpireNone'.tr()
                                : 'marketplace.autoExpireOn'.tr(namedArgs: {
                                    'date':
                                        '${_expiresAt!.day}.${_expiresAt!.month}.${_expiresAt!.year}'
                                  }),
                            style: AppTypography.body(
                                size: 13, color: AppColors.ink),
                          ),
                        ),
                        if (_expiresAt != null)
                          GestureDetector(
                            onTap: () => setState(() => _expiresAt = null),
                            child: const Icon(LucideIcons.x,
                                size: 16, color: AppColors.mute),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tags ────────────────────────────────────────────────────
          CreateCard(
            title: 'create.sectionTags'.tr(),
            icon: LucideIcons.tag,
            child: TextField(
              controller: _tags,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'marketplace.tags'.tr(),
                hintText: 'marketplace.tagsHint'.tr(),
                prefixIcon: const Icon(LucideIcons.tag, size: 18),
              ),
            ),
          ),

          // ── Standort ────────────────────────────────────────────────
          CreateCard(
            title: 'create.sectionLocation'.tr(),
            icon: LucideIcons.mapPin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocationPickerField(
                  initialLat: _lat,
                  initialLng: _lng,
                  onChanged: (la, lo) => setState(() {
                    _lat = la;
                    _lng = lo;
                  }),
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
              ],
            ),
          ),

          if (_error != null)
            Text(
              _error!,
              style: AppTypography.body(size: 13, color: AppColors.herzrotWarm),
            ),
          if (_uploading)
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.amber),
                ),
                const SizedBox(width: 10),
                Text('marketplace.create.uploading'.tr(),
                    style:
                        AppTypography.body(size: 13, color: AppColors.inkSoft)),
              ],
            ),
        ],
        footer: Column(
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.voidColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.voidColor),
                    )
                  : const Icon(LucideIcons.plus, size: 16),
              label: Text(_submitting
                  ? 'marketplace.saving'.tr()
                  : 'marketplace.createButton'.tr()),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
                side: const BorderSide(color: AppColors.line),
              ),
              onPressed: () => context.go('/dashboard/marketplace'),
              child: Text('common.cancel'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
