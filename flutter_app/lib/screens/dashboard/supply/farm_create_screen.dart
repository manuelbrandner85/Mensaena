/// SKILL: mensaena-features
/// Farm-Create-Screen — 1:1 zu Web /dashboard/supply/farm/add.
/// Felder: Name, Stadt, Kategorie, Beschreibung, Adresse, Kontakt,
/// Produkte/Services/Lieferoptionen, Bio/Saisonal-Flags, Fotos (max 5).
library;

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/location_service.dart';
import '../../../widgets/effects/mini_confetti.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/readable_width.dart';
import '../../../widgets/shared/app_snackbar.dart';

class FarmCreateScreen extends ConsumerStatefulWidget {
  const FarmCreateScreen({super.key});

  @override
  ConsumerState<FarmCreateScreen> createState() => _FarmCreateScreenState();
}

class _FarmCreateScreenState extends ConsumerState<FarmCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _productsRaw = TextEditingController();
  final _servicesRaw = TextEditingController();
  final _deliveryRaw = TextEditingController();

  String _category = 'Bauernhof';
  String _country = 'AT';
  bool _isBio = false;
  bool _isSeasonal = false;
  bool _busy = false;
  bool _uploading = false;
  bool _locating = false;
  double? _lat;
  double? _lng;
  final List<String> _mediaUrls = [];

  // Wert = stabiler DB-/Web-Parität-Schlüssel (Deutsch), i18n = Anzeige-Label.
  static const Map<String, String> _categories = {
    'Bauernhof': 'supply.farmCreate.catBauernhof',
    'Imkerei': 'supply.farmCreate.catImkerei',
    'Mosterei': 'supply.farmCreate.catMosterei',
    'Metzgerei': 'supply.farmCreate.catMetzgerei',
    'Käserei': 'supply.farmCreate.catKaeserei',
    'Mühle': 'supply.farmCreate.catMuehle',
    'Bäckerei': 'supply.farmCreate.catBaeckerei',
    'Brauerei': 'supply.farmCreate.catBrauerei',
    'Hofladen': 'supply.farmCreate.catHofladen',
    'Sonstiges': 'supply.farmCreate.catSonstiges',
  };

  static const _countries = <String, String>{
    'AT': '🇦🇹 Österreich',
    'DE': '🇩🇪 Deutschland',
    'CH': '🇨🇭 Schweiz',
  };

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _address,
      _postalCode,
      _city,
      _state,
      _phone,
      _email,
      _website,
      _productsRaw,
      _servicesRaw,
      _deliveryRaw,
    ]) {
      c.dispose();
    }
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
      });
      _toast('supply.farmCreate.gpsSet'.tr());
    } catch (_) {
      // Standort bleibt optional.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_mediaUrls.length >= 5) {
      _toast('supply.farmCreate.maxPhotos'.tr());
      return;
    }
    final picker = ImagePicker();
    final res = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (res == null) return;
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    setState(() => _uploading = true);
    try {
      final file = File(res.path);
      final size = await file.length();
      if (size > 8 * 1024 * 1024) {
        _toast('supply.farmCreate.photoTooLarge'.tr());
        return;
      }
      final raw = res.path.split('.').last.toLowerCase();
      final ext = (raw.length <= 4 && raw.isNotEmpty) ? raw : 'jpg';
      final contentType = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' || 'heif' => 'image/heic',
        _ => 'image/jpeg',
      };
      final rand = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      // BUG-FIX: 'farm/$uid' begann mit "farm/" → storage.foldername(name)[1]
      // = uid kommt erst NACH "farm/" → RLS-Policy verglich falsche Position
      // → Upload schlug fehl. Pfad muss mit uid/ starten damit RLS matched.
      final path = '$uid/farm-${DateTime.now().millisecondsSinceEpoch}_$rand.$ext';
      await sb.storage.from('post-images').upload(
            path,
            file,
            fileOptions:
                FileOptions(upsert: false, contentType: contentType),
          );
      final url = sb.storage.from('post-images').getPublicUrl(path);
      setState(() => _mediaUrls.add(url));
    } catch (e) {
      debugPrint('farm photo upload failed: $e');
      _toast('supply.farmCreate.uploadFailed'.tr());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removePhoto(int i) {
    setState(() => _mediaUrls.removeAt(i));
  }

  List<String> _csv(String raw) => raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final slug = await FarmsRepository.create(
      name: _name.text,
      city: _city.text,
      category: _category,
      country: _country,
      description: _description.text,
      address: _address.text,
      postalCode: _postalCode.text,
      state: _state.text,
      phone: _phone.text,
      email: _email.text,
      website: _website.text,
      products: _csv(_productsRaw.text),
      services: _csv(_servicesRaw.text),
      deliveryOptions: _csv(_deliveryRaw.text),
      isBio: _isBio,
      isSeasonal: _isSeasonal,
      mediaUrls: _mediaUrls,
      region: _state.text,
      latitude: _lat,
      longitude: _lng,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (slug == null) {
      Haptics.error();
      _toast('supply.farmCreate.createFailed'.tr());
      return;
    }
    Haptics.success();
    MiniConfetti.show(context);
    _toast('supply.farmCreate.createSuccess'.tr());
    context.go('/dashboard/supply');
  }

  void _toast(String msg) {
    AppSnackBar.info(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'create.farmCreateTitle'.tr(),
      currentRoute: '/dashboard/supply/farm/add',
      body: SafeArea(
        child: ReadableWidth(
            child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text('supply.farmCreateTitle'.tr(),
                  style: AppTypography.display(
                      size: 22, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                'supply.farmCreate.intro'.tr(),
                style: AppTypography.body(
                    size: 13, color: AppColors.mute),
              ),
              const SizedBox(height: 20),
              _section('supply.farmCreate.secBasics'.tr()),
              _field(
                _name,
                'supply.farmCreate.fName'.tr(),
                'supply.farmCreate.fNameHint'.tr(),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'supply.farmCreate.required'.tr()
                    : null,
              ),
              const SizedBox(height: 10),
              _dropdown(
                label: 'supply.farmCreate.fCategory'.tr(),
                value: _category,
                items: _categories.keys.toList(),
                itemLabel: (k) => (_categories[k] ?? k).tr(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 10),
              _field(_description, 'supply.farmCreate.fDescription'.tr(),
                  'supply.farmCreate.fDescHint'.tr(),
                  maxLines: 3),
              const SizedBox(height: 18),
              _section('supply.farmCreate.secLocation'.tr()),
              _field(_address, 'supply.farmCreate.fAddress'.tr(),
                  'supply.farmCreate.fAddressHint'.tr()),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: _field(_postalCode, 'supply.farmCreate.fPostal'.tr(),
                        '12345'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _city,
                      'supply.farmCreate.fCity'.tr(),
                      'supply.farmCreate.fCityHint'.tr(),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'supply.farmCreate.required'.tr()
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _field(
                          _state, 'supply.farmCreate.fState'.tr(), '')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdown(
                      label: 'supply.farmCreate.fCountry'.tr(),
                      value: _country,
                      items: _countries.keys.toList(),
                      itemLabel: (k) => _countries[k] ?? k,
                      onChanged: (v) => setState(() => _country = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Standort per GPS (optional) — für korrekte Karten-Platzierung.
              OutlinedButton.icon(
                onPressed: _locating ? null : _useGps,
                icon: _locating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.bronze),
                      )
                    : Icon(
                        _lat != null
                            ? LucideIcons.mapPin
                            : LucideIcons.locate,
                        size: 16,
                        color: _lat != null
                            ? AppColors.bronze
                            : AppColors.inkSoft,
                      ),
                label: Text(_lat != null
                    ? '${_lat!.toStringAsFixed(3)}, ${_lng!.toStringAsFixed(3)}'
                    : 'supply.farmCreate.useGps'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _lat != null ? AppColors.bronze : AppColors.inkSoft,
                  side: BorderSide(
                      color: _lat != null
                          ? AppColors.bronze.withValues(alpha: 0.5)
                          : AppColors.line),
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
              const SizedBox(height: 18),
              _section('supply.farmCreate.secContact'.tr()),
              _field(_phone, 'supply.farmCreate.fPhone'.tr(), '+43 …'),
              const SizedBox(height: 10),
              _field(_email, 'supply.farmCreate.fEmail'.tr(), 'hof@…'),
              const SizedBox(height: 10),
              _field(_website, 'supply.farmCreate.fWebsite'.tr(), 'https://…'),
              const SizedBox(height: 18),
              _section('supply.farmCreate.secOffer'.tr()),
              _field(_productsRaw, 'supply.farmCreate.fProducts'.tr(),
                  'supply.farmCreate.fProductsHint'.tr()),
              const SizedBox(height: 10),
              _field(_servicesRaw, 'supply.farmCreate.fServices'.tr(),
                  'supply.farmCreate.fServicesHint'.tr()),
              const SizedBox(height: 10),
              _field(_deliveryRaw, 'supply.farmCreate.fDelivery'.tr(),
                  'supply.farmCreate.fDeliveryHint'.tr()),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                value: _isBio,
                onChanged: (v) => setState(() => _isBio = v),
                title: Text('supply.farmIsBio'.tr(),
                    style: AppTypography.body(
                        size: 14, color: AppColors.ink)),
                activeColor: AppColors.leben,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _isSeasonal,
                onChanged: (v) => setState(() => _isSeasonal = v),
                title: Text('supply.farmIsSeasonal'.tr(),
                    style: AppTypography.body(
                        size: 14, color: AppColors.ink)),
                activeColor: AppColors.amber,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 18),
              _section('supply.farmCreate.secPhotos'.tr()),
              _photoGrid(),
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
                    : const Icon(LucideIcons.send, size: 16),
                label: Text('supply.farmSubmit'.tr()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'supply.farmCreate.moderationNote'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 10, color: AppColors.mute),
              ),
            ],
          ),
        )),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
        child: Text(label.toUpperCase(),
            style: AppTypography.label(size: 10, color: AppColors.bronze)),
      );

  Widget _field(
    TextEditingController c,
    String label,
    String hint, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      style: AppTypography.body(size: 14, color: AppColors.ink),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTypography.body(size: 13, color: AppColors.mute),
        hintStyle: AppTypography.body(size: 12, color: AppColors.mute),
        filled: true,
        fillColor: AppColors.elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.bronze),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? itemLabel,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.body(size: 13, color: AppColors.mute),
        filled: true,
        fillColor: AppColors.elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: AppColors.surface,
      items: items
          .map((i) => DropdownMenuItem(
                value: i,
                child: Text(itemLabel?.call(i) ?? i,
                    style: AppTypography.body(
                        size: 13, color: AppColors.ink)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _photoGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _mediaUrls.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: _mediaUrls[i],
                  fadeInDuration: const Duration(milliseconds: 200),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const ShimmerBox(
                    width: 80,
                    height: 80,
                    borderRadius: 8,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: AppColors.elevated,
                    alignment: Alignment.center,
                    child: const Icon(LucideIcons.imageOff,
                        size: 18, color: AppColors.mute),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => _removePhoto(i),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.herzrot,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.x,
                        size: 14, color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
        if (_mediaUrls.length < 5)
          InkWell(
            onTap: _uploading ? null : _pickPhoto,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.bronze.withValues(alpha: 0.5)),
              ),
              alignment: Alignment.center,
              child: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.bronze),
                    )
                  : const Icon(LucideIcons.plus,
                      size: 22, color: AppColors.bronze),
            ),
          ),
      ],
    );
  }
}
