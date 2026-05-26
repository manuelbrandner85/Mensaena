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
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

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
  final List<String> _mediaUrls = [];

  static const _categories = <String>[
    'Bauernhof',
    'Imkerei',
    'Mosterei',
    'Metzgerei',
    'Käserei',
    'Mühle',
    'Bäckerei',
    'Brauerei',
    'Hofladen',
    'Sonstiges',
  ];

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

  Future<void> _pickPhoto() async {
    if (_mediaUrls.length >= 5) {
      _toast('Maximal 5 Fotos.');
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
        _toast('Foto zu groß (max 8 MB).');
        return;
      }
      final ext = res.path.split('.').last;
      final rand = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      final path = 'farm/$uid/${DateTime.now().millisecondsSinceEpoch}_$rand.$ext';
      await sb.storage.from('post-images').upload(path, file);
      final url = sb.storage.from('post-images').getPublicUrl(path);
      setState(() => _mediaUrls.add(url));
    } catch (_) {
      _toast('Foto-Upload fehlgeschlagen.');
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
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (slug == null) {
      _toast('Eintrag konnte nicht erstellt werden.');
      return;
    }
    _toast('Bauernhof eingetragen! Danke.');
    context.go('/dashboard/supply');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(msg,
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'create.farmCreateTitle'.tr(),
      currentRoute: '/dashboard/supply/farm/add',
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text('supply.farmCreateTitle'.tr(),
                  style: AppTypography.display(
                      size: 22, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                'Trage einen Bauernhof, Hofladen oder Direktvermarkter aus deiner Region ein.',
                style: AppTypography.body(
                    size: 13, color: AppColors.mute),
              ),
              const SizedBox(height: 20),
              _section('Grunddaten'),
              _field(
                _name,
                'Name *',
                'Hof zur Sonne',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 10),
              _dropdown(
                label: 'Kategorie',
                value: _category,
                items: _categories,
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 10),
              _field(_description, 'Beschreibung', 'Was macht euren Hof aus?',
                  maxLines: 3),
              const SizedBox(height: 18),
              _section('Standort'),
              _field(_address, 'Adresse', 'Straße + Nr.'),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: _field(_postalCode, 'PLZ', '12345'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _city,
                      'Stadt *',
                      'Berlin',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Pflichtfeld'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(_state, 'Bundesland', '')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdown(
                      label: 'Land',
                      value: _country,
                      items: _countries.keys.toList(),
                      itemLabel: (k) => _countries[k] ?? k,
                      onChanged: (v) => setState(() => _country = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _section('Kontakt'),
              _field(_phone, 'Telefon', '+43 …'),
              const SizedBox(height: 10),
              _field(_email, 'E-Mail', 'hof@…'),
              const SizedBox(height: 10),
              _field(_website, 'Website', 'https://…'),
              const SizedBox(height: 18),
              _section('Angebot'),
              _field(_productsRaw, 'Produkte (kommagetrennt)',
                  'Eier, Honig, Kartoffeln'),
              const SizedBox(height: 10),
              _field(_servicesRaw, 'Services (kommagetrennt)',
                  'Hofführung, Workshops'),
              const SizedBox(height: 10),
              _field(_deliveryRaw, 'Lieferoptionen (kommagetrennt)',
                  'Selbstabholung, Lieferung'),
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
              _section('Fotos (max 5)'),
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
                'Dein Eintrag wird vor Veröffentlichung von der Moderation geprüft.',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 10, color: AppColors.mute),
              ),
            ],
          ),
        ),
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
