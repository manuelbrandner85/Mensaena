import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_features_repository.dart';
import '../../../repositories/posts_repository.dart';
import '../../../repositories/profiles_repository.dart';
import '../../../services/geocoding_service.dart';
import '../../../services/location_service.dart';
import '../../../services/post_draft_service.dart';
import '../../../services/rate_limit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../services/supabase_service.dart';
import '../../../widgets/effects/celebrate_burst.dart';
import '../../../widgets/shared/address_autocomplete_field.dart';
import '../../../widgets/shared/tag_suggestion_field.dart';
import '../../../widgets/forms/create_post_scaffold.dart';
import 'module_create_config.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../widgets/shared/form_error_box.dart';
import '../../../utils/form_validators.dart';

/// SKILL: mensaena-features
/// 1:1-Pendant zu Web `src/components/shared/CreatePostPage.tsx`.
/// Modul-spezifische Create-Page mit:
///   - Modul-eigenem Editorial-Header (Title + Icon + Accent-Color)
///   - Whitelist auf createTypes (nur erlaubte Post-Typen)
///   - Whitelist auf categories (nur erlaubte Kategorien)
///   - Auto-Lock der Kategorie wenn createType.category gesetzt
///   - Return-Route nach Submit zur ursprünglichen Modul-Seite
///   - Volle Funktionalitaet: Titel, Beschreibung, Bilder, Adresse-AC,
///     GPS, Telefon/Email/WhatsApp, Privacy-Toggles, Anonym, Draft-Save
class ModuleCreatePostScreen extends ConsumerStatefulWidget {
  const ModuleCreatePostScreen({required this.config, super.key});
  final ModuleCreateConfig config;

  @override
  ConsumerState<ModuleCreatePostScreen> createState() =>
      _ModuleCreatePostScreenState();
}

class _ModuleCreatePostScreenState
    extends ConsumerState<ModuleCreatePostScreen> {
  String? _type;
  String? _category;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _meetingCtrl = TextEditingController();
  final _timeHoursCtrl = TextEditingController();
  // Verfügbarkeits-Zeitfenster (optional) → posts.availability_start/end.
  TimeOfDay? _availStart;
  TimeOfDay? _availEnd;

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Widget _availTile({
    required String label,
    required TimeOfDay? value,
    required ValueChanged<TimeOfDay?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.clock, size: 14, color: AppColors.bronze),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value == null ? label : value.format(context),
                style: AppTypography.body(size: 12, color: AppColors.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(LucideIcons.x,
                    size: 14, color: AppColors.mute),
              ),
          ],
        ),
      ),
    );
  }
  final _tagsCtrl = TextEditingController();
  bool _privacyPhone = false;
  bool _privacyEmail = false;
  bool _isAnonymous = false;
  bool _shareExactLocation = false;
  bool _noTradeConfirmed = false;
  int _urgency = 2;
  final List<File> _images = [];
  double? _lat;
  double? _lng;
  bool _submitting = false;
  bool _aiImproving = false;
  String? _error;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    // Defaults: 1. Type aus erster Whitelist-Entry
    if (widget.config.createTypes.isNotEmpty) {
      _type = widget.config.createTypes.first.value;
      _category = widget.config.createTypes.first.category ??
          (widget.config.categories.isNotEmpty
              ? widget.config.categories.first.value
              : null);
    }
    _titleCtrl.addListener(_scheduleDraftSave);
    _descCtrl.addListener(_scheduleDraftSave);
    // Fallback-Geo aus dem Profil vorbelegen. Ohne diesen Schritt blieben
    // Posts auf der Karte unsichtbar, sobald der User den GPS-Button nicht
    // explizit antippt — der Map-Filter braucht lat/lng auf DB-Seite.
    _seedProfileLocation();
  }

  Future<void> _seedProfileLocation() async {
    // Exakte Koordinaten werden nur gespeichert wenn der User explizit zustimmt.
    // Daher kein automatisches Vorbelegen aus dem Profil.
  }

  /// Koordinaten-Auflösung beim Absenden — NUR wenn der User der Weitergabe
  /// des genauen Standorts zugestimmt hat (_shareExactLocation).
  Future<void> _resolveCoordinates() async {
    if (!_shareExactLocation) {
      _lat = null;
      _lng = null;
      return;
    }
    if (_lat != null && _lng != null) return;

    // 2. Freitext-Standort des Beitrags geocodieren (außer GPS-Platzhalter).
    final txt = _locationCtrl.text.trim();
    if (txt.isNotEmpty && !txt.startsWith('GPS:')) {
      final hits = await GeocodingService.search(query: txt, limit: 1);
      if (hits.isNotEmpty) {
        _lat = hits.first.lat;
        _lng = hits.first.lng;
        return;
      }
    }

    try {
      final p = await ref.read(myProfileProvider.future);
      // 3. Profil-Koordinaten.
      if (p?.latitude != null && p?.longitude != null) {
        _lat = p!.latitude;
        _lng = p.longitude;
        return;
      }
      // 4. Profil-Heimatstadt bzw. Profil-Standort geocodieren.
      final cityQuery = (p?.homeCity?.trim().isNotEmpty ?? false)
          ? p!.homeCity!.trim()
          : (p?.location?.trim().isNotEmpty ?? false)
              ? p!.location!.trim()
              : null;
      if (cityQuery != null) {
        final hits = await GeocodingService.search(query: cityQuery, limit: 1);
        if (hits.isNotEmpty) {
          _lat = hits.first.lat;
          _lng = hits.first.lng;
        }
      }
    } catch (_) {/* letzter Fallback fehlgeschlagen → Post ohne Geo */}
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(seconds: 3), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_titleCtrl.text.isEmpty && _descCtrl.text.isEmpty) return;
    await PostDraftService.save(PostDraft(
      type: _type,
      title: _titleCtrl.text,
      description: _descCtrl.text,
      location: _locationCtrl.text,
      tags: _tagsCtrl.text,
      savedAt: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    _meetingCtrl.dispose();
    _timeHoursCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    try {
      final pos = await LocationService.getCurrentPosition(
        accuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _shareExactLocation = true; // GPS-Nutzung = implizite Zustimmung
        _locationCtrl.text =
            'GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, 'create.locationUnavailable'.tr());
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= 5) {
      AppSnackBar.info(context, 'create.maxImages'.tr());
      return;
    }
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (result == null) return;
    setState(() => _images.add(File(result.path)));
  }

  Future<List<String>> _uploadImages() async {
    final urls = <String>[];
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return urls;
    for (var i = 0; i < _images.length; i++) {
      final file = _images[i];
      final raw = file.path.split('.').last.toLowerCase();
      final ext = (raw.length <= 4 && raw.isNotEmpty) ? raw : 'jpg';
      final contentType = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' || 'heif' => 'image/heic',
        _ => 'image/jpeg',
      };
      final path =
          '$uid/${DateTime.now().millisecondsSinceEpoch}-$i.$ext';
      try {
        await sb.storage.from('post-images').upload(
              path,
              file,
              fileOptions:
                  FileOptions(upsert: false, contentType: contentType),
            );
        urls.add(sb.storage.from('post-images').getPublicUrl(path));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('uploads.imageFailed'.tr(
                namedArgs: {'n': '${i + 1}', 'e': '$e'})),
          ));
        }
      }
    }
    return urls;
  }

  // A) KI-Texthilfe: Stichworte/Beschreibung -> klarer Beitrag.
  Future<void> _improveWithAi() async {
    final raw = _descCtrl.text.trim().isNotEmpty
        ? _descCtrl.text.trim()
        : _titleCtrl.text.trim();
    if (raw.isEmpty) {
      AppSnackBar.info(context, 'assistant.improve_empty'.tr());
      return;
    }
    setState(() => _aiImproving = true);
    String? improved;
    try {
      improved = await AiFeaturesRepository()
          .improvePost(raw, context.locale.languageCode);
    } catch (_) {/* unten als Fehler behandelt */}
    if (!mounted) return;
    setState(() => _aiImproving = false);
    if (improved == null || improved.trim().isEmpty) {
      AppSnackBar.error(context, 'assistant.error'.tr());
      return;
    }
    final suggestion = improved;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('assistant.improve_title'.tr(),
            style: AppTypography.display(size: 16, color: AppColors.ink)),
        content: SingleChildScrollView(
          child: Text(suggestion,
              style: AppTypography.body(size: 14, color: AppColors.ink)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('assistant.improve_apply'.tr()),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      setState(() => _descCtrl.text = suggestion);
    }
  }

  Future<void> _submit() async {
    // Doppel-Submit-Schutz: schneller Doppel-Tap könnte zwei identische
    // Posts erzeugen, bevor das _submitting-Flag den Button disabled.
    if (_submitting) return;
    if (_type == null) {
      setState(() => _error = 'create.fillTypeAndTitle'.tr());
      return;
    }
    // Pflicht-Bestätigung „Kein Handel/Geldgeschäft" (§4 AGB) — Web-Parität.
    if (!_noTradeConfirmed) {
      HapticFeedback.mediumImpact();
      setState(() => _error = 'create.noTradeRequired'.tr());
      return;
    }
    // Echte Form-Validierung (Titel-Länge, E-Mail-/Telefon-Format, Zahlen).
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.mediumImpact();
      setState(() => _error = null);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final ok = await RateLimitService.check(
      action: 'create_post',
      maxPerMinute: 2,
      maxPerHour: 10,
    );
    if (!ok) {
      setState(() {
        _submitting = false;
        _error = 'create.rateLimited'.tr();
      });
      return;
    }

    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      setState(() {
        _submitting = false;
        _error = 'create.notLoggedIn'.tr();
      });
      return;
    }

    // Geo sicherstellen: JEDER Beitrag soll auf der Karte erscheinen.
    await _resolveCoordinates();

    final urls = await _uploadImages();
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    try {
      final newId = await PostsRepository.create({
            'type': _type,
            'category': _category,
            'title': _titleCtrl.text.trim(),
            'description': _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            'location_text': _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            'latitude': _lat,
            'longitude': _lng,
            'contact_phone': _phoneCtrl.text.trim().isEmpty
                ? null
                : _phoneCtrl.text.trim(),
            'contact_email': _emailCtrl.text.trim().isEmpty
                ? null
                : _emailCtrl.text.trim(),
            'contact_whatsapp': _whatsappCtrl.text.trim().isEmpty
                ? null
                : _whatsappCtrl.text.trim(),
            'meeting_point': _meetingCtrl.text.trim().isEmpty
                ? null
                : _meetingCtrl.text.trim(),
            'time_hours':
                double.tryParse(_timeHoursCtrl.text.replaceAll(',', '.').trim()),
            if (_availStart != null) 'availability_start': _fmtTime(_availStart!),
            if (_availEnd != null) 'availability_end': _fmtTime(_availEnd!),
            // DB-Spalte ist TEXT (Enum 'low'|'medium'|'high'|'critical').
            'urgency': _urgency <= 1
                ? 'low'
                : _urgency == 2
                    ? 'medium'
                    : _urgency == 3
                        ? 'high'
                        : 'critical',
            'privacy_phone': _privacyPhone,
            'privacy_email': _privacyEmail,
            'is_anonymous': _isAnonymous,
            'media_urls': urls,
            'tags': tags,
            'status': 'active',
            'module_key': widget.config.moduleKey,
          });
      if (newId == null) throw StateError('insert_blocked');

      await PostDraftService.clear();
      if (!mounted) return;
      // Premium: kleiner Feier-Moment beim erfolgreichen Erstellen.
      CelebrateBurst.fire(context, ref: ref);
      AppSnackBar.success(context, 'common.created'.tr());
      // 1:1 Web: navigiere zur Modul-Detail-Page, nicht zum Post-Detail
      // (Web macht beides — wir nehmen Modul-Route für bessere UX-Continuity).
      context.go('${widget.config.returnRoute}/$newId');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'create.saveFailed'.tr();
      });
    }
  }

  /// Index des aktuell gewählten Typs (für CreateTypeGrid). -1 wenn keiner.
  int _selectedTypeIndex() {
    final types = widget.config.createTypes;
    for (var i = 0; i < types.length; i++) {
      final t = types[i];
      if (t.value == _type && (t.category == null || t.category == _category)) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final selIdx = _selectedTypeIndex();
    final activeType = selIdx >= 0 ? c.createTypes[selIdx] : null;
    // Kategorie-Auswahl nur zeigen, wenn der gewählte Typ sie nicht sperrt
    // (Web verbirgt die Kategorie bei festem Typ).
    final showCategory =
        c.categories.length > 1 && (activeType?.category == null);

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: CreatePostScaffold(
        title: c.title.tr(),
        subtitle: c.description.tr(),
        accent: c.accentColor,
        icon: c.icon,
        returnRoute: c.returnRoute,
        sections: [
          // ── Art & Kategorie ─────────────────────────────────────────
          CreateCard(
            title: 'create.sectionType'.tr(),
            icon: LucideIcons.layoutGrid,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CreateTypeGrid(
                  options: [
                    for (var i = 0; i < c.createTypes.length; i++)
                      CreateTypeOption(
                        value: '$i',
                        label:
                            '${c.createTypes[i].emoji} ${c.createTypes[i].label.tr()}',
                      ),
                  ],
                  selected: selIdx >= 0 ? '$selIdx' : null,
                  accent: c.accentColor,
                  onSelect: (s) {
                    final t = c.createTypes[int.parse(s)];
                    setState(() {
                      _type = t.value;
                      if (t.category != null) _category = t.category;
                    });
                  },
                ),
                if (showCategory) ...[
                  const SizedBox(height: 14),
                  Text('create.category'.tr(),
                      style: AppTypography.label(size: 10)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final cat in c.categories)
                        ChoiceChip(
                          label: Text(cat.label.tr(),
                              style: AppTypography.label(size: 10)),
                          selected: _category == cat.value,
                          onSelected: (_) =>
                              setState(() => _category = cat.value),
                          selectedColor: c.accentColor.withValues(alpha: 0.3),
                          backgroundColor: AppColors.elevated,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Dringlichkeit ───────────────────────────────────────────
          CreateCard(
            title: 'create.urgency'.tr(),
            icon: LucideIcons.alertTriangle,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 1; i <= 5; i++)
                  ChoiceChip(
                    label: Text(
                      [
                        'create.urgencyLow'.tr(),
                        'create.urgencyNormal'.tr(),
                        'create.urgencyMedium'.tr(),
                        'create.urgencyHigh'.tr(),
                        'create.urgencyCritical'.tr(),
                      ][i - 1],
                      style: AppTypography.label(size: 9),
                    ),
                    selected: _urgency == i,
                    onSelected: (_) => setState(() => _urgency = i),
                    selectedColor: c.accentColor.withValues(alpha: 0.3),
                    backgroundColor: AppColors.elevated,
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
                  controller: _titleCtrl,
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
                  controller: _descCtrl,
                  maxLines: 6,
                  minLines: 3,
                  maxLength: 2000,
                  validator: FormValidators.lengthBetween(0, 2000,
                      requiredField: false),
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'create.descriptionOptional'.tr(),
                    alignLabelWithHint: true,
                  ),
                ),
                // KI-Texthilfe: Stichworte -> klarer Beitrag (Nutzer übernimmt/verwirft).
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _aiImproving ? null : _improveWithAi,
                    icon: _aiImproving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.bronze),
                          )
                        : const Icon(Icons.auto_awesome,
                            size: 16, color: AppColors.bronze),
                    label: Text('assistant.improve_button'.tr(),
                        style: AppTypography.label(
                            size: 12, color: AppColors.bronze)),
                  ),
                ),
              ],
            ),
          ),

          // ── Bilder ──────────────────────────────────────────────────
          CreateCard(
            title: 'create.sectionImages'.tr(),
            icon: LucideIcons.image,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('create.imagesMax5'.tr(),
                        style: AppTypography.label(size: 10)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'events.add_photo'.tr(),
                      onPressed: _pickImage,
                      icon: Icon(LucideIcons.imagePlus,
                          size: 18, color: c.accentColor),
                    ),
                  ],
                ),
                if (_images.isNotEmpty)
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_images[i],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                cacheWidth: 160,
                                cacheHeight: 160),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _images.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.x,
                                    size: 11, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Standort ────────────────────────────────────────────────
          CreateCard(
            title: 'create.sectionLocation'.tr(),
            icon: LucideIcons.mapPin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AddressAutocompleteField(
                        controller: _locationCtrl,
                        label: 'create.place'.tr(),
                        onSelected: (s) => setState(() {
                          _lat = s.lat;
                          _lng = s.lng;
                          _shareExactLocation = true;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: _useGps,
                        icon: const Icon(LucideIcons.locate, size: 14),
                        label: const Text('GPS'),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => setState(
                      () => _shareExactLocation = !_shareExactLocation),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _shareExactLocation,
                          onChanged: (v) => setState(
                              () => _shareExactLocation = v ?? false),
                          activeColor: AppColors.teal,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'create.shareExactLocation'.tr(),
                            style: AppTypography.body(
                                size: 12, color: AppColors.inkSoft),
                          ),
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
            child: TagSuggestionField(
              controller: _tagsCtrl,
              label: 'create.tagsCommaSeparated'.tr(),
              suggestions: const [
                'dringend',
                'lokal',
                'kostenlos',
                'hilfe',
                'nachbarschaft',
                'vegan',
                'familie',
                'tiere',
              ],
            ),
          ),

          // ── Kontakt (optional) ──────────────────────────────────────
          CreateCard(
            title: 'create.contactOptional'.tr(),
            icon: LucideIcons.phone,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: FormValidators.phoneOptional,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'create.phone'.tr(),
                    isDense: true,
                  ),
                ),
                SwitchListTile(
                  value: _privacyPhone,
                  onChanged: (v) => setState(() => _privacyPhone = v),
                  activeColor: c.accentColor,
                  contentPadding: EdgeInsets.zero,
                  title: Text('create.phoneOnlyInterested'.tr(),
                      style: AppTypography.caption()),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: FormValidators.emailOptional,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'create.emailOptional'.tr(),
                    isDense: true,
                  ),
                ),
                SwitchListTile(
                  value: _privacyEmail,
                  onChanged: (v) => setState(() => _privacyEmail = v),
                  activeColor: c.accentColor,
                  contentPadding: EdgeInsets.zero,
                  title: Text('create.emailOnlyInterested'.tr(),
                      style: AppTypography.caption()),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _whatsappCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: FormValidators.phoneOptional,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    hintText: '+49 …',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _meetingCtrl,
                  textInputAction: TextInputAction.next,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'create.meetingPoint'.tr(),
                    isDense: true,
                  ),
                ),
                // Verfügbarkeits-Zeitfenster (optional): wann erreichbar.
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _availTile(
                        label: 'create.availFrom'.tr(),
                        value: _availStart,
                        onChanged: (t) => setState(() => _availStart = t),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _availTile(
                        label: 'create.availTo'.tr(),
                        value: _availEnd,
                        onChanged: (t) => setState(() => _availEnd = t),
                      ),
                    ),
                  ],
                ),
                // Zeitbank-Bezug: nur sinnvoll bei Hilfe-Posts.
                if (_type == 'sharing' ||
                    _type == 'rescue' ||
                    _type == 'community') ...[
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _timeHoursCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    validator: FormValidators.positiveNumberOptional,
                    style: AppTypography.body(size: 14, color: AppColors.ink),
                    decoration: InputDecoration(
                      labelText: 'create.timebankHours'.tr(),
                      hintText: 'create.timebankHoursHint'.tr(),
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Optionen ────────────────────────────────────────────────
          CreateCard(
            title: 'create.sectionOptions'.tr(),
            icon: LucideIcons.settings2,
            child: SwitchListTile(
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              activeColor: c.accentColor,
              contentPadding: EdgeInsets.zero,
              title: Text('create.postAnonymously'.tr(),
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.inkSoft,
                      weight: FontWeight.w600)),
              subtitle: Text('create.noProfileVisible'.tr(),
                  style: AppTypography.caption()),
            ),
          ),

          // Pflicht-Bestätigung „Kein Handel/Geldgeschäft" (§4 AGB)
          NoTradeConfirmCard(
            value: _noTradeConfirmed,
            onChanged: (v) => setState(() => _noTradeConfirmed = v),
          ),

          if (_error != null) FormErrorBox(_error!),
        ],
        footer: Column(
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.accentColor,
                foregroundColor: AppColors.voidColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.voidColor,
                      ),
                    )
                  : const Icon(LucideIcons.send, size: 16),
              label: Text('create.publish'.tr()),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
                side: const BorderSide(color: AppColors.line),
              ),
              onPressed: () => context.go(c.returnRoute),
              child: Text('common.cancel'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
