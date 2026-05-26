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

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/ai_post_assist_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/intent_classifier_service.dart';
import '../../services/location_service.dart';
import '../../services/post_draft_service.dart';
import '../../services/rate_limit_service.dart';
import '../../services/supabase_service.dart';
import '../../models/post_intent.dart';
import '../../widgets/effects/glass_card.dart';
import '../../models/post_contact_preference.dart';
import '../../repositories/post_contact_repository.dart';
import '../../widgets/effects/celebrate_burst.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/post/contact_preference_selector.dart';
import '../../widgets/post/post_intent_selector.dart';
import '../../widgets/shared/address_autocomplete_field.dart';

/// SKILL: flutter-build-responsive-layout + mensaena-features
/// 3-Step Create-Post-Wizard (matched zur Web /dashboard/create):
///   Step 1 — Art: Post-Typ-Auswahl (13 Typen, Cinema-Farbe + Emoji)
///   Step 2 — Inhalt: Titel + Beschreibung + Bilder + Tags + Intent-Hint
///   Step 3 — Kontakt: Standort + Telefon/Email/WhatsApp + Privacy-Toggles
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({this.initialType, super.key});

  /// Vorgewaehlter Typ via Query-Param (?type=animal, etc.).
  final String? initialType;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  int _step = 0;
  String? _type;
  // Mega-Contact-System: Intent + Contact-Preferences
  PostIntent _intent = PostIntent.general;
  PostContactPreference? _contactPref;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _privacyPhone = false;
  bool _privacyEmail = false;
  int _urgency = 2;
  bool _isAnonymous = false;
  final List<File> _images = [];
  double? _lat;
  double? _lng;
  bool _submitting = false;
  String? _error;
  DateTime? _scheduledAt;
  DateTime? _expiresAt;

  static List<_PostType> get _types => [
        _PostType('help_request', 'create.typeHelpRequest'.tr(), '🆘',
            AppColors.herzrot),
        _PostType('help_offered', 'create.typeHelpOffered'.tr(), '💚',
            AppColors.leben),
        _PostType('animal', 'create.typeAnimal'.tr(), '🐾',
            const Color(0xFFEC4899)),
        _PostType('housing', 'create.typeHousing'.tr(), '🏡',
            const Color(0xFF60A5FA)),
        _PostType('supply', 'create.typeSupply'.tr(), '🌾',
            const Color(0xFFFACC15)),
        _PostType('mobility', 'create.typeMobility'.tr(), '🚗',
            const Color(0xFF818CF8)),
        _PostType('sharing', 'create.typeSharing'.tr(), '🔄', AppColors.teal),
        _PostType('community', 'create.typeCommunity'.tr(), '🗳️',
            const Color(0xFFC084FC)),
        _PostType('crisis', 'create.typeCrisis'.tr(), '🚨', AppColors.herzrot),
        _PostType('rescue', 'create.typeRescue'.tr(), '🧡',
            const Color(0xFFFB923C)),
        _PostType('skill', 'create.typeSkill'.tr(), '🎯',
            const Color(0xFFA78BFA)),
        _PostType('knowledge', 'create.typeKnowledge'.tr(), '📚',
            AppColors.amber),
        _PostType(
            'mental', 'create.typeMental'.tr(), '🧠', AppColors.tealSoft),
      ];

  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (_type != null) _step = 1;
    _loadDraft();
    // Auto-save alle 3s wenn was im Titel/Beschreibung steht.
    _titleCtrl.addListener(_scheduleDraftSave);
    _descCtrl.addListener(_scheduleDraftSave);
    _locationCtrl.addListener(_scheduleDraftSave);
    _tagsCtrl.addListener(_scheduleDraftSave);
  }

  Future<void> _loadDraft() async {
    final draft = await PostDraftService.load();
    if (!mounted || draft == null || draft.isEmpty) return;
    // Erst beim User-Consent uebernehmen — Snackbar mit "Wiederherstellen"
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      duration: const Duration(seconds: 6),
      content: Text(
        'create.draftFoundRestore'.tr(),
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
      action: SnackBarAction(
        label: 'create.restoreYes'.tr(),
        textColor: AppColors.amber,
        onPressed: () {
          setState(() {
            _type = draft.type ?? _type;
            _titleCtrl.text = draft.title;
            _descCtrl.text = draft.description;
            _locationCtrl.text = draft.location;
            _tagsCtrl.text = draft.tags;
            if (_type != null && _step == 0) _step = 1;
          });
        },
      ),
    ));
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
    _titleCtrl.removeListener(_scheduleDraftSave);
    _descCtrl.removeListener(_scheduleDraftSave);
    _locationCtrl.removeListener(_scheduleDraftSave);
    _tagsCtrl.removeListener(_scheduleDraftSave);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
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
        _locationCtrl.text =
            'GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('create.locationUnavailable'.tr())),
      );
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('create.maxImages'.tr())),
      );
      return;
    }
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
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
      final ext = file.path.split('.').last;
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}-$i.$ext';
      try {
        await sb.storage.from('post-images').upload(path, file);
        urls.add(sb.storage.from('post-images').getPublicUrl(path));
      } catch (_) {
        // Skip einzelnes Bild bei Upload-Fehler.
      }
    }
    return urls;
  }

  Future<void> _submit() async {
    if (_type == null || _titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'create.pleaseFillTypeAndTitle'.tr());
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

    final urls = await _uploadImages();
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    try {
      final inserted = await sb
          .from('posts')
          .insert({
            'user_id': uid,
            'type': _type,
            'title': _titleCtrl.text.trim(),
            'description':
                _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            'location_text': _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            'latitude': _lat,
            'longitude': _lng,
            'contact_phone':
                _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            'contact_email':
                _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
            'contact_whatsapp': _whatsappCtrl.text.trim().isEmpty
                ? null
                : _whatsappCtrl.text.trim(),
            // DB-Spalte ist TEXT mit Enum 'low'|'medium'|'high'|'critical'.
            // 5er-UI-Slider (Niedrig/Normal/Mittel/Hoch/Sehr hoch) wird auf
            // die 4 DB-Werte gemappt — 'normal' und 'low' beide → 'low',
            // 'sehr hoch' → 'critical'. Falls 0 (kein Urgency) → NULL.
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
            'status':
                _scheduledAt != null && _scheduledAt!.isAfter(DateTime.now())
                    ? 'scheduled'
                    : 'active',
            'post_intent': _intent.value,
            'scheduled_at': _scheduledAt?.toIso8601String(),
            'expires_at': _expiresAt?.toIso8601String(),
          })
          .select()
          .maybeSingle();

      if (!mounted) return;
      if (inserted == null) {
        // RLS-Block oder leerer Result → werfen damit catch greift
        // und User klare Fehler-Snackbar sieht.
        throw StateError('insert_blocked');
      }
      final id = inserted['id'] as String;
      // Mega-Contact-System: Kontaktpraeferenzen upsert (wenn Intent Kontakt verlangt)
      if (_intent.requiresContact && _contactPref != null) {
        final fixed = _contactPref!.copyWith().toJson()
          ..['post_id'] = id;
        // Re-build mit korrekter post_id (Selector hat 'pending' placeholder)
        await const PostContactRepository().upsertPreferences(
          PostContactPreference.fromJson({
            ...fixed,
            'user_id': uid,
          }),
        );
      }
      await PostDraftService.clear();
      if (!mounted) return;
      // F4 Micro-Interaction: kurzer Konfetti-Burst zum Feiern.
      CelebrateBurst.fire(context);
      context.go('/dashboard/posts/$id');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'create.savingFailed'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'create.newPost'.tr(),
      currentRoute: '/dashboard/create',
      body: SafeArea(
        child: Column(
          children: [
            _StepIndicator(current: _step),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildStep(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.herzrotWarm,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _submitting ? null : () => setState(() => _step--),
                        child: Text('common.back'.tr()),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              if (_step < 2) {
                                if (_step == 0 && _type == null) {
                                  setState(
                                    () => _error =
                                        'create.pleaseChooseType'.tr(),
                                  );
                                  return;
                                }
                                setState(() {
                                  _step++;
                                  _error = null;
                                });
                              } else {
                                _submit();
                              }
                            },
                      child: Text(
                        _step < 2
                            ? 'common.next'.tr()
                            : (_submitting
                                ? 'create.publishing'.tr()
                                : 'create.publish'.tr()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepArt(
          selected: _type,
          onSelect: (t) {
            setState(() {
              _type = t;
              _intent = PostIntent.fromPostType(t);
              _error = null;
            });
          },
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mega-Contact-System: PostIntentSelector am Anfang von Step 2
            PostIntentSelector(
              onIntentSelected: (i) => setState(() => _intent = i),
              initialPostType: _type,
              selectedIntent: _intent,
            ),
            const SizedBox(height: 18),
            _StepInhalt(
              titleCtrl: _titleCtrl,
              descCtrl: _descCtrl,
              tagsCtrl: _tagsCtrl,
              images: _images,
              onPickImage: _pickImage,
              onRemoveImage: (i) => setState(() => _images.removeAt(i)),
              intentHint: _intentHint(),
              onApplyIntent: (t) {
                setState(() {
                    _type = t;
                    _intent = PostIntent.fromPostType(t);
                  });
              },
              isAnonymous: _isAnonymous,
              onToggleAnonymous: (v) => setState(() => _isAnonymous = v),
              postType: _type,
            ),
          ],
        );
      case 2:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mega-Contact-System: ContactPreferenceSelector (nur wenn Intent es verlangt)
            if (_intent.requiresContact) ...[
              ContactPreferenceSelector(
                userId: SupabaseService.currentUser?.id ?? '',
                postId: 'pending', // wird beim Insert auf echte ID gemapped
                initial: _contactPref,
                onChanged: (p) => setState(() => _contactPref = p),
              ),
              const SizedBox(height: 18),
            ],
            _StepKontakt(
          locationCtrl: _locationCtrl,
          phoneCtrl: _phoneCtrl,
          emailCtrl: _emailCtrl,
          whatsappCtrl: _whatsappCtrl,
          privacyPhone: _privacyPhone,
          privacyEmail: _privacyEmail,
          onTogglePhone: (v) => setState(() => _privacyPhone = v),
          onToggleEmail: (v) => setState(() => _privacyEmail = v),
          urgency: _urgency,
          onUrgency: (u) => setState(() => _urgency = u),
          onUseGps: _useGps,
          onAddressSelected: (s) {
            setState(() {
              _lat = s.lat;
              _lng = s.lng;
            });
          },
        ),
            const SizedBox(height: 18),
            _SchedulingSection(
              scheduledAt: _scheduledAt,
              expiresAt: _expiresAt,
              onPickScheduled: (dt) => setState(() => _scheduledAt = dt),
              onPickExpires: (dt) => setState(() => _expiresAt = dt),
            ),
          ],
        );
    }
  }

  ({String type, double confidence})? _intentHint() {
    if (_titleCtrl.text.trim().length < 5) return null;
    final result = IntentClassifierService.classify(
      title: _titleCtrl.text,
      description: _descCtrl.text,
    );
    if (result == null) return null;
    if (result.type == _type) return null;
    if (result.confidence < IntentClassifierService.suggestThreshold) {
      return null;
    }
    return result;
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────
class _PostType {
  const _PostType(this.value, this.label, this.emoji, this.color);
  final String value;
  final String label;
  final String emoji;
  final Color color;
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;

  static List<String> get _labels => [
        'create.stepArt'.tr(),
        'create.stepInhalt'.tr(),
        'create.stepKontakt'.tr(),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = i <= current;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? AppColors.amber : AppColors.surface,
                    border: Border.all(
                      color: active ? AppColors.amber : AppColors.line,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppTypography.mono(
                      size: 11,
                      color: active ? AppColors.voidColor : AppColors.mute,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labels[i],
                    style: AppTypography.label(
                      size: 10,
                      color: active ? AppColors.amber : AppColors.mute,
                    ),
                  ),
                ),
                if (i < _labels.length - 1)
                  Container(
                    width: 16,
                    height: 1,
                    color: AppColors.line,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Step 1: Art ──────────────────────────────────────────────────────────
class _StepArt extends StatelessWidget {
  const _StepArt({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'create.whatShare'.tr(),
          style: AppTypography.display(size: 22, color: AppColors.ink),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final cross = c.maxWidth < 500 ? 2 : 3;
            return GridView.count(
              crossAxisCount: cross,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: _CreatePostScreenState._types.map((t) {
                final isActive = t.value == selected;
                return InkWell(
                  onTap: () => onSelect(t.value),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? t.color.withValues(alpha: 0.15)
                          : AppColors.surface.withValues(alpha: 0.5),
                      border: Border.all(
                        color: isActive ? t.color : AppColors.line,
                        width: isActive ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        Text(
                          t.label,
                          style: AppTypography.body(
                            size: 13,
                            color: isActive ? t.color : AppColors.ink,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Step 2: Inhalt ───────────────────────────────────────────────────────
class _StepInhalt extends StatelessWidget {
  const _StepInhalt({
    required this.titleCtrl,
    required this.descCtrl,
    required this.tagsCtrl,
    required this.images,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.intentHint,
    required this.onApplyIntent,
    required this.isAnonymous,
    required this.onToggleAnonymous,
    required this.postType,
  });

  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController tagsCtrl;
  final List<File> images;
  final VoidCallback onPickImage;
  final ValueChanged<int> onRemoveImage;
  final ({String type, double confidence})? intentHint;
  final ValueChanged<String> onApplyIntent;
  final bool isAnonymous;
  final ValueChanged<bool> onToggleAnonymous;
  final String? postType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'create.whatAbout'.tr(),
          style: AppTypography.display(size: 22, color: AppColors.ink),
        ),
        const SizedBox(height: 14),
        _AiAssistantCard(
          titleCtrl: titleCtrl,
          descCtrl: descCtrl,
          postType: postType,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: titleCtrl,
          maxLength: 120,
          style: AppTypography.body(size: 15, color: AppColors.ink),
          decoration: InputDecoration(
            labelText: 'create.title'.tr(),
            counterText: '',
          ),
        ),
        if (intentHint != null) ...[
          const SizedBox(height: 10),
          _IntentHint(
            hint: intentHint!,
            onApply: () => onApplyIntent(intentHint!.type),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: descCtrl,
          maxLines: 5,
          maxLength: 2000,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: InputDecoration(
            labelText: 'create.description'.tr(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: tagsCtrl,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          inputFormatters: [
            FilteringTextInputFormatter.deny(
                RegExp(r'[^a-zA-Z0-9äöüÄÖÜß ,_-]')),
          ],
          decoration: InputDecoration(
            labelText: 'create.tagsCommaSeparated'.tr(),
            hintText: 'create.tagsHint'.tr(),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'create.imagesOptional'.tr(),
          style: AppTypography.label(size: 10),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < images.length; i++)
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: FileImage(images[i]),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => onRemoveImage(i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.voidColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.x,
                            size: 14,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (images.length < 5)
                InkWell(
                  onTap: onPickImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.plus,
                      color: AppColors.amber,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: isAnonymous,
          onChanged: onToggleAnonymous,
          activeColor: AppColors.amber,
          title: Text(
            'create.postAnonymously'.tr(),
            style: AppTypography.body(
              size: 14,
              color: AppColors.ink,
              weight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'create.anonymousSubtitle'.tr(),
            style: AppTypography.caption(),
          ),
        ),
      ],
    );
  }
}

class _IntentHint extends StatelessWidget {
  const _IntentHint({required this.hint, required this.onApply});
  final ({String type, double confidence}) hint;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.sparkles,
            size: 14,
            color: AppColors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'create.maybeMean'.tr(namedArgs: {'type': hint.type}),
              style: AppTypography.body(
                size: 12,
                color: AppColors.amber,
              ),
            ),
          ),
          TextButton(
            onPressed: onApply,
            child: Text('create.apply'.tr()),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Kontakt ──────────────────────────────────────────────────────
class _StepKontakt extends StatelessWidget {
  const _StepKontakt({
    required this.locationCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.whatsappCtrl,
    required this.privacyPhone,
    required this.privacyEmail,
    required this.onTogglePhone,
    required this.onToggleEmail,
    required this.urgency,
    required this.onUrgency,
    required this.onUseGps,
    required this.onAddressSelected,
  });

  final TextEditingController locationCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController whatsappCtrl;
  final bool privacyPhone;
  final bool privacyEmail;
  final ValueChanged<bool> onTogglePhone;
  final ValueChanged<bool> onToggleEmail;
  final int urgency;
  final ValueChanged<int> onUrgency;
  final VoidCallback onUseGps;
  final void Function(AddressSuggestion) onAddressSelected;

  static List<String> get _urgencyLabels => [
        'create.urgencyLow'.tr(),
        'create.urgencyNormal'.tr(),
        'create.urgencyMedium'.tr(),
        'create.urgencyHigh'.tr(),
        'create.urgencyVeryHigh'.tr(),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'create.howReach'.tr(),
          style: AppTypography.display(size: 22, color: AppColors.ink),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AddressAutocompleteField(
                controller: locationCtrl,
                label: 'create.addressLabel'.tr(),
                hint: 'create.addressHint'.tr(),
                onSelected: onAddressSelected,
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                onPressed: onUseGps,
                icon: const Icon(LucideIcons.locate, size: 16),
                label: Text('create.gps'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: InputDecoration(labelText: 'create.phoneOptional'.tr()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: privacyPhone,
          onChanged: onTogglePhone,
          activeColor: AppColors.amber,
          title: Text(
            'create.phoneShowLoggedIn'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.inkSoft),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: InputDecoration(labelText: 'create.emailOptional'.tr()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: privacyEmail,
          onChanged: onToggleEmail,
          activeColor: AppColors.amber,
          title: Text(
            'create.emailShowLoggedIn'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.inkSoft),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: whatsappCtrl,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: InputDecoration(labelText: 'create.whatsappOptional'.tr()),
        ),
        const SizedBox(height: 18),
        Text('create.urgency'.tr(), style: AppTypography.label(size: 10)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: List.generate(5, (i) {
            final active = urgency == i;
            return GestureDetector(
              onTap: () => onUrgency(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.amber.withValues(alpha: 0.2)
                      : AppColors.surface.withValues(alpha: 0.5),
                  border: Border.all(
                    color: active ? AppColors.amber : AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _urgencyLabels[i],
                  style: AppTypography.label(
                    size: 10,
                    color: active ? AppColors.amber : AppColors.inkSoft,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── KI-Beitrags-Assistent ─────────────────────────────────────────────
class _AiAssistantCard extends StatefulWidget {
  const _AiAssistantCard({
    required this.titleCtrl,
    required this.descCtrl,
    required this.postType,
  });

  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final String? postType;

  @override
  State<_AiAssistantCard> createState() => _AiAssistantCardState();
}

class _AiAssistantCardState extends State<_AiAssistantCard> {
  final _promptCtrl = TextEditingController();
  bool _loading = false;
  AiPostSuggestions? _suggestions;
  String? _error;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final input = _promptCtrl.text.trim().isNotEmpty
        ? _promptCtrl.text.trim()
        : widget.titleCtrl.text.trim().isNotEmpty
            ? widget.titleCtrl.text.trim()
            : widget.descCtrl.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'create.aiNeedInput'.tr());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = null;
    });
    final result = await AiPostAssistService.suggest(
      input: input,
      type: widget.postType,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _suggestions = result;
      if (result == null || result.isEmpty) {
        _error = 'create.aiUnavailable'.tr();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.bronze.withValues(alpha: 0.12),
            AppColors.amber.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.wand,
                  size: 14, color: AppColors.bronze),
              const SizedBox(width: 6),
              Text('create.aiAssistant'.tr(),
                  style: AppTypography.label(
                      size: 10, color: AppColors.bronzeSoft)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promptCtrl,
                  style: AppTypography.body(
                      size: 13, color: AppColors.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.elevated,
                    hintText: 'create.aiPromptHint'.tr(),
                    hintStyle: AppTypography.body(
                        size: 12, color: AppColors.mute),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                onPressed: _loading ? null : _generate,
                child: _loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.voidColor,
                        ),
                      )
                    : const Icon(LucideIcons.sparkles, size: 14),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: AppTypography.caption()
                    .copyWith(color: AppColors.herzrotWarm)),
          ],
          if (_suggestions != null && _suggestions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (_suggestions!.titles.isNotEmpty) ...[
              Text('create.aiTitleSuggestions'.tr(),
                  style: AppTypography.label(size: 9)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _suggestions!.titles)
                    GestureDetector(
                      onTap: () {
                        widget.titleCtrl.text = t;
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(t,
                            style: AppTypography.body(
                                size: 12,
                                color: AppColors.ink)),
                      ),
                    ),
                ],
              ),
            ],
            if (_suggestions!.description != null &&
                _suggestions!.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('create.aiDescriptionSuggestion'.tr(),
                  style: AppTypography.label(size: 9)),
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  widget.descCtrl.text = _suggestions!.description!;
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_suggestions!.description!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                              size: 12,
                              color: AppColors.inkSoft,
                              height: 1.45)),
                      const SizedBox(height: 4),
                      Text('create.aiTapToApply'.tr(),
                          style: AppTypography.label(
                              size: 8, color: AppColors.bronze)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SchedulingSection extends StatelessWidget {
  const _SchedulingSection({
    required this.scheduledAt,
    required this.expiresAt,
    required this.onPickScheduled,
    required this.onPickExpires,
  });

  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final ValueChanged<DateTime?> onPickScheduled;
  final ValueChanged<DateTime?> onPickExpires;

  Future<DateTime?> _pick(BuildContext context, DateTime? initial) async {
    final base = initial ?? DateTime.now().add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return null;
    if (!context.mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}, '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.calendarClock,
                size: 18, color: AppColors.bronze),
            const SizedBox(width: 8),
            Text('create.scheduling'.tr(),
                style: AppTypography.display(size: 16, color: AppColors.ink)),
          ]),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.clock,
                size: 18, color: AppColors.inkSoft),
            title: Text('create.scheduled_at'.tr(),
                style: AppTypography.body(size: 14, color: AppColors.ink)),
            subtitle: Text(
              scheduledAt == null
                  ? 'create.publish_now'.tr()
                  : _fmt(scheduledAt!),
              style: AppTypography.caption(),
            ),
            trailing: scheduledAt != null
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () => onPickScheduled(null),
                  )
                : const Icon(LucideIcons.chevronRight, size: 16),
            onTap: () async {
              final picked = await _pick(context, scheduledAt);
              if (picked != null) onPickScheduled(picked);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.hourglass,
                size: 18, color: AppColors.inkSoft),
            title: Text('create.expires_at'.tr(),
                style: AppTypography.body(size: 14, color: AppColors.ink)),
            subtitle: Text(
              expiresAt == null ? 'create.never'.tr() : _fmt(expiresAt!),
              style: AppTypography.caption(),
            ),
            trailing: expiresAt != null
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () => onPickExpires(null),
                  )
                : const Icon(LucideIcons.chevronRight, size: 16),
            onTap: () async {
              final picked = await _pick(context, expiresAt);
              if (picked != null) onPickExpires(picked);
            },
          ),
        ],
      ),
    );
  }
}
