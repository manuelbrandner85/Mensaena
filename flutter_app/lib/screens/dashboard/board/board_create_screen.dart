import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/board_repository.dart';
import '../../../repositories/profiles_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/effects/mini_confetti.dart';
import '../../../widgets/forms/create_post_scaffold.dart';
import '../../../widgets/forms/location_picker_field.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../widgets/shared/form_error_box.dart';
import '../../../utils/form_validators.dart';

class BoardCreateScreen extends ConsumerStatefulWidget {
  const BoardCreateScreen({super.key});

  @override
  ConsumerState<BoardCreateScreen> createState() => _BoardCreateScreenState();
}

class _BoardCreateScreenState extends ConsumerState<BoardCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _content = TextEditingController();
  final _contactInfo = TextEditingController();
  String _category = 'general';
  String _color = 'yellow';
  final List<File> _images = [];
  static const int _maxImages = 4;
  DateTime? _expiresAt;
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _submitting = false;
  String? _error;

  static const List<({String value, String i18n, String emoji})> _categories = [
    (value: 'general', i18n: 'board.catGeneral', emoji: '💬'),
    (value: 'gesucht', i18n: 'board.catGesucht', emoji: '🔍'),
    (value: 'biete', i18n: 'board.catBiete', emoji: '🎁'),
    (value: 'event', i18n: 'board.catEvent', emoji: '📅'),
    (value: 'info', i18n: 'board.catInfo', emoji: 'ℹ️'),
    (value: 'warnung', i18n: 'board.catWarnung', emoji: '⚠️'),
    (value: 'verloren', i18n: 'board.catVerloren', emoji: '😢'),
    (value: 'fundbuero', i18n: 'board.catFundbuero', emoji: '🔑'),
  ];

  @override
  void initState() {
    super.initState();
    // Smart-Default: Standort aus dem Profil-Heimatort vorbelegen (kein
    // GPS-Prompt, editierbar über GPS-Button/Picker). Pinnwand-Notizen
    // betreffen meist die eigene Nachbarschaft → sinnvoller Default-Pin.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _prefillLocationFromProfile());
  }

  Future<void> _prefillLocationFromProfile() async {
    if (_lat != null || _lng != null) return;
    try {
      final p = await ref.read(myProfileProvider.future);
      final hLat = p?.homeLat ?? p?.latitude;
      final hLng = p?.homeLng ?? p?.longitude;
      if (hLat == null || hLng == null || !mounted) return;
      setState(() {
        _lat = hLat;
        _lng = hLng;
      });
    } catch (_) {
      // Standort bleibt optional.
    }
  }

  @override
  void dispose() {
    _content.dispose();
    _contactInfo.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= _maxImages) return;
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 80,
    );
    if (result == null) return;
    setState(() => _images.add(File(result.path)));
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
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
    } catch (_) {
      // still — Standort bleibt optional.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  static const Map<String, Color> _colors = {
    'yellow': Color(0xFFFEF08A),
    'green': Color(0xFFBBF7D0),
    'blue': Color(0xFFBFDBFE),
    'pink': Color(0xFFFBCFE8),
    'orange': Color(0xFFFED7AA),
    'purple': Color(0xFFE9D5FF),
  };

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
    String? imageUrl;
    List<String> mediaUrls = const [];
    if (_images.isNotEmpty) {
      String? uploadErr;
      final urls = await ImageUploadService.upload(
        _images,
        onError: (_, e) => uploadErr = e,
      );
      if (urls.isEmpty) {
        // Bilder gewählt, Upload schlug fehl → NICHT stillschweigend ohne
        // Bild posten, sondern Fehler zeigen.
        Haptics.error();
        setState(() {
          _submitting = false;
          _error = 'create.imageUploadFailed'.tr();
        });
        debugPrint('board image upload failed: $uploadErr');
        return;
      }
      mediaUrls = urls;
      imageUrl = urls.first; // Rückwärtskompatibel: erstes Bild als image_url.
    }
    final id = await BoardRepository.create(
      content: _content.text.trim(),
      category: _category,
      color: _color,
      contactInfo: _contactInfo.text.trim().isEmpty
          ? null
          : _contactInfo.text.trim(),
      expiresAt: _expiresAt,
      imageUrl: imageUrl,
      mediaUrls: mediaUrls,
      latitude: _lat,
      longitude: _lng,
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
    Haptics.success();
    MiniConfetti.show(context);
    AppSnackBar.success(context, 'common.created'.tr());
    context.go('/dashboard/board/$id');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: CreatePostScaffold(
        title: 'create.pinTitle'.tr(),
        subtitle: 'board.createSubtitle'.tr(),
        accent: AppColors.amber,
        icon: LucideIcons.stickyNote,
        returnRoute: '/dashboard/board',
        sections: [
          // ── Live-Vorschau: farbiger Notizzettel, aktualisiert beim Tippen ─
          CreateCard(
            title: 'create.preview'.tr(),
            icon: LucideIcons.eye,
            child: ListenableBuilder(
              listenable: _content,
              builder: (context, _) {
                final cat = _categories.firstWhere(
                    (c) => c.value == _category,
                    orElse: () => _categories.first);
                final text = _content.text.trim();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _colors[_color] ?? _colors.values.first,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(cat.emoji,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            cat.i18n.tr(),
                            style: AppTypography.label(
                                size: 10, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        text.isEmpty ? '…' : text,
                        style: AppTypography.body(
                            size: 14, color: Colors.black87, height: 1.4),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Kategorie ───────────────────────────────────────────────
          CreateCard(
            title: 'board.categoryLabel'.tr(),
            icon: LucideIcons.layoutGrid,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories.map((c) {
                final active = c.value == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = c.value),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        Text(c.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          c.i18n.tr(),
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
          ),

          // ── Farbe ───────────────────────────────────────────────────
          CreateCard(
            title: 'board.colorLabel'.tr(),
            icon: Icons.palette,
            child: Wrap(
              children: _colors.entries.map((e) {
                final active = e.key == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = e.key),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: e.value,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active ? AppColors.amber : AppColors.line,
                            width: active ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Notiz & Kontakt ─────────────────────────────────────────
          CreateCard(
            title: 'create.sectionDetails'.tr(),
            icon: LucideIcons.fileText,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _content,
                  maxLines: 6,
                  maxLength: 1000,
                  validator: FormValidators.lengthBetween(3, 1000),
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'create.pinNote'.tr(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contactInfo,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    labelText: 'create.contactOptional'.tr(),
                    hintText: 'create.pinContactHint'.tr(),
                  ),
                ),
              ],
            ),
          ),

          // ── Bilder (optional, bis zu 4) ─────────────────────────────
          CreateCard(
            title: 'board.image'.tr(),
            icon: LucideIcons.image,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_images[i],
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            cacheWidth: 168,
                            cacheHeight: 168),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.herzrot,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.surface, width: 2),
                            ),
                            child: const Icon(LucideIcons.x,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_images.length < _maxImages)
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.5),
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.camera,
                              color: AppColors.bronze, size: 20),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Optionen (Ablauf, Standort) ─────────────────────────────
          CreateCard(
            title: 'create.sectionOptions'.tr(),
            icon: LucideIcons.settings2,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickExpiry,
                        icon: const Icon(LucideIcons.calendarClock, size: 16),
                        label: Text(
                          _expiresAt == null
                              ? 'board.setExpiry'.tr()
                              : 'board.expiresOn'.tr(namedArgs: {
                                  'date':
                                      '${_expiresAt!.day}.${_expiresAt!.month}.${_expiresAt!.year}'
                                }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.inkSoft,
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_expiresAt != null)
                      IconButton(
                        onPressed: () => setState(() => _expiresAt = null),
                        icon: const Icon(LucideIcons.x, size: 16),
                        color: AppColors.mute,
                        tooltip: 'board.noExpiry'.tr(),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                LocationPickerField(
                  initialLat: _lat,
                  initialLng: _lng,
                  onChanged: (la, lo) => setState(() {
                    _lat = la;
                    _lng = lo;
                  }),
                ),
                const SizedBox(height: 10),
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
                  label: Text(
                    _lat != null
                        ? '${_lat!.toStringAsFixed(3)}, ${_lng!.toStringAsFixed(3)}'
                        : 'board.location'.tr(),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _lat != null ? AppColors.bronze : AppColors.inkSoft,
                    side: BorderSide(
                        color: _lat != null
                            ? AppColors.bronze.withValues(alpha: 0.5)
                            : AppColors.line),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) FormErrorBox(_error!),
        ],
        footer: FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.amber,
            foregroundColor: AppColors.voidColor,
            minimumSize: const Size(double.infinity, 50),
          ),
          icon: const Icon(LucideIcons.stickyNote, size: 16),
          label: Text(_submitting
              ? 'board.saving'.tr()
              : 'board.createButton'.tr()),
        ),
      ),
    );
  }
}
