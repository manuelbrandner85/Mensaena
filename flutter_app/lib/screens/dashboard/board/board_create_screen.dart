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
import '../../../services/haptics.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/effects/mini_confetti.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../widgets/shared/form_error_box.dart';
import '../../../widgets/shared/readable_width.dart';
import '../../../widgets/effects/animated_entrance.dart';
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
  File? _image;
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
  void dispose() {
    _content.dispose();
    _contactInfo.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 80,
    );
    if (result == null) return;
    setState(() => _image = File(result.path));
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
    if (_image != null) {
      String? uploadErr;
      final urls = await ImageUploadService.upload(
        [_image!],
        onError: (_, e) => uploadErr = e,
      );
      if (urls.isEmpty) {
        // Bild war gewählt, Upload schlug fehl → NICHT stillschweigend ohne
        // Bild posten, sondern Fehler zeigen.
        Haptics.error();
        setState(() {
          _submitting = false;
          _error = 'create.imageUploadFailed'.tr();
        });
        debugPrint('board image upload failed: $uploadErr');
        return;
      }
      imageUrl = urls.first;
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
    return DashboardScaffold(
      title: 'create.pinTitle'.tr(),
      currentRoute: '/dashboard/board',
      body: SafeArea(
        child: ReadableWidth(
            child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('board.categoryLabel'.tr(), style: AppTypography.label(size: 10)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories.map((c) {
                final active = c.value == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = c.value),
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
                        Text(c.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          c.i18n.tr(),
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
            const SizedBox(height: 14),
            Text('board.colorLabel'.tr(), style: AppTypography.label(size: 10)),
            const SizedBox(height: 6),
            Row(
              children: _colors.entries.map((e) {
                final active = e.key == _color;
                // 36dp-Kreis bleibt das Visual, die Tap-Fläche ist 48dp
                // (A11y-Minimum für Touch-Targets).
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
            const SizedBox(height: 14),
            AnimatedEntrance(
              index: 0,
              child: TextFormField(
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
            const SizedBox(height: 16),
            // Bild (optional) — z.B. Foto des gefundenen Schlüssels.
            Text('board.image'.tr(), style: AppTypography.label(size: 10)),
            const SizedBox(height: 8),
            if (_image != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_image!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _image = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xCC000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.x,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.camera,
                          color: AppColors.bronze, size: 20),
                      const SizedBox(width: 8),
                      Text('board.addImage'.tr(),
                          style: AppTypography.caption()),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Ablaufdatum (optional) — Notiz verschwindet automatisch.
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
            // Standort (optional) — z.B. Fundort.
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
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              FormErrorBox(_error!),
            ],
            const SizedBox(height: 18),
            AnimatedEntrance(
              index: 1,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(LucideIcons.stickyNote, size: 16),
                label: Text(_submitting
                    ? 'board.saving'.tr()
                    : 'board.createButton'.tr()),
              ),
            ),
          ],
        ))),
      ),
    );
  }
}
