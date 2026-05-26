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
import '../../../repositories/events_repository.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Komplette Event-Erstellungs-Maske: Cover, 10 Kategorien, Datum+Zeit,
/// Ganztaegig, Online, Standort+GPS, Max-Teilnehmer, Kosten, Mitbringen,
/// Kontakt, Wiederkehrend.
class EventCreateScreen extends ConsumerStatefulWidget {
  const EventCreateScreen({super.key});

  @override
  ConsumerState<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends ConsumerState<EventCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationNameCtrl = TextEditingController();
  final _locationAddressCtrl = TextEditingController();
  final _maxAttendeesCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _whatToBringCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _onlineUrlCtrl = TextEditingController();

  String _category = 'community';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isAllDay = false;
  bool _isOnline = false;
  bool _isFree = true;
  bool _isRecurring = false;
  String _recurringPattern = 'weekly';
  double? _lat;
  double? _lng;
  File? _coverImage;
  String? _uploadedImageUrl;
  bool _submitting = false;
  bool _uploading = false;
  String? _error;

  final ImagePicker _picker = ImagePicker();

  // Web-Spec: 10 Kategorien mit Emoji + Akzent-Farbe.
  static const List<
      ({String value, String emoji, String labelKey, Color color})>
      _categories = [
    (value: 'community', emoji: '🤝', labelKey: 'events.cat.community', color: Color(0xFF1EAAA6)),
    (value: 'sports', emoji: '⚽', labelKey: 'events.cat.sports', color: Color(0xFF3B82F6)),
    (value: 'culture', emoji: '🎭', labelKey: 'events.cat.culture', color: Color(0xFF8B5CF6)),
    (value: 'education', emoji: '📚', labelKey: 'events.cat.education', color: Color(0xFFF59E0B)),
    (value: 'nature', emoji: '🌳', labelKey: 'events.cat.nature', color: Color(0xFF10B981)),
    (value: 'food', emoji: '🍽️', labelKey: 'events.cat.food', color: Color(0xFFEF4444)),
    (value: 'music', emoji: '🎵', labelKey: 'events.cat.music', color: Color(0xFFEC4899)),
    (value: 'volunteer', emoji: '🙌', labelKey: 'events.cat.volunteer', color: Color(0xFF1EAAA6)),
    (value: 'kids', emoji: '🧒', labelKey: 'events.cat.kids', color: Color(0xFFF97316)),
    (value: 'other', emoji: '✨', labelKey: 'events.cat.other', color: Color(0xFF4F6D8A)),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationNameCtrl.dispose();
    _locationAddressCtrl.dispose();
    _maxAttendeesCtrl.dispose();
    _costCtrl.dispose();
    _whatToBringCtrl.dispose();
    _contactCtrl.dispose();
    _onlineUrlCtrl.dispose();
    super.dispose();
  }

  // ── Cover Image ────────────────────────────────────────────

  Future<void> _pickCover() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
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
              leading: const Icon(LucideIcons.image, color: AppColors.amber),
              title: Text('events.pickFromGallery'.tr(),
                  style: AppTypography.body(size: 14, color: AppColors.ink)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera, color: AppColors.amber),
              title: Text('events.pickFromCamera'.tr(),
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
      setState(() {
        _coverImage = File(picked.path);
        _uploadedImageUrl = null;
      });
    } catch (_) {
      // ignore
    }
  }

  void _removeCover() {
    setState(() {
      _coverImage = null;
      _uploadedImageUrl = null;
    });
  }

  // ── Datum + Zeit ──────────────────────────────────────────

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate ?? now.add(const Duration(hours: 24)))
        : (_endDate ?? _startDate ?? now.add(const Duration(hours: 24)));
    final firstAllowed = isStart
        ? now.subtract(const Duration(days: 1))
        : (_startDate ?? now);
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstAllowed) ? firstAllowed : initial,
      firstDate: firstAllowed,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    setState(() {
      final time = TimeOfDay.fromDateTime(initial);
      final next = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _startDate = next;
      } else {
        _endDate = next;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final base = isStart ? _startDate : _endDate;
    if (base == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    setState(() {
      final next = DateTime(base.year, base.month, base.day, time.hour, time.minute);
      if (isStart) {
        _startDate = next;
      } else {
        _endDate = next;
      }
    });
  }

  // ── GPS ───────────────────────────────────────────────────

  Future<void> _useGps() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (_locationAddressCtrl.text.trim().isEmpty) {
          _locationAddressCtrl.text =
              'GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'errors.locationFailed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink),
          ),
        ),
      );
    }
  }

  // ── Submit ────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'events.validationTitle'.tr());
      return;
    }
    if (_startDate == null) {
      setState(() => _error = 'events.validationStartDate'.tr());
      return;
    }
    if (_category.isEmpty) {
      setState(() => _error = 'events.validationCategory'.tr());
      return;
    }
    if (_endDate != null && !_endDate!.isAfter(_startDate!)) {
      setState(() => _error = 'events.validationEndAfterStart'.tr());
      return;
    }

    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      setState(() => _error = 'errors.notAuthenticated'.tr());
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    String? imageUrl = _uploadedImageUrl;
    if (_coverImage != null && imageUrl == null) {
      setState(() => _uploading = true);
      try {
        final bytes = await _coverImage!.readAsBytes();
        final ext = _coverImage!.path.split('.').last.toLowerCase();
        imageUrl = await EventsRepository.uploadEventImage(
          bytes: bytes,
          userId: uid,
          fileExt: ext,
        );
      } catch (_) {
        imageUrl = null;
      }
      if (mounted) setState(() => _uploading = false);
      if (imageUrl == null) {
        if (!mounted) return;
        setState(() {
          _error = 'events.imageUploadFailed'.tr();
          _submitting = false;
        });
        return;
      }
      _uploadedImageUrl = imageUrl;
    }

    final eventId = await EventsRepository.create(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      startDate: _startDate!,
      endDate: _endDate,
      isAllDay: _isAllDay,
      locationName: _isOnline ? null : _locationNameCtrl.text.trim(),
      locationAddress: _isOnline ? null : _locationAddressCtrl.text.trim(),
      latitude: _isOnline ? null : _lat,
      longitude: _isOnline ? null : _lng,
      imageUrl: imageUrl,
      maxAttendees: int.tryParse(_maxAttendeesCtrl.text.trim()),
      cost: _isFree ? 'kostenlos' : _costCtrl.text.trim(),
      whatToBring: _whatToBringCtrl.text.trim(),
      contactInfo: _contactCtrl.text.trim(),
      isRecurring: _isRecurring,
      recurringPattern: _isRecurring ? _recurringPattern : null,
      isOnline: _isOnline,
      onlineUrl: _isOnline ? _onlineUrlCtrl.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (eventId == null) {
      setState(() => _error = 'events.createFailed'.tr());
      return;
    }
    context.go('/dashboard/events/$eventId');
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'events.createTitle'.tr(),
      currentRoute: '/dashboard/events',
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _sectionCover(),
                _sectionTitleDesc(),
                _sectionCategory(),
                _sectionStartDateTime(),
                _sectionAllDayToggle(),
                _sectionEndDateTime(),
                _sectionOnlineToggle(),
                if (!_isOnline) _sectionLocation(),
                _sectionMaxAttendees(),
                _sectionCost(),
                _sectionWhatToBring(),
                _sectionContact(),
                _sectionRecurring(),
                if (_error != null) _errorBox(_error!),
                const SizedBox(height: 16),
                _submitButton(),
                const SizedBox(height: 16),
              ],
            ),
            if (_submitting || _uploading) _loadingOverlay(),
          ],
        ),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────

  Widget _sectionWrap({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }

  Widget _sectionCover() {
    return _sectionWrap(
      child: GestureDetector(
        onTap: _pickCover,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_coverImage != null)
                Image.file(_coverImage!,
                    fit: BoxFit.cover,
                    cacheWidth: 800,
                    cacheHeight: 600)
              else if (_uploadedImageUrl != null)
                CachedNetworkImage(
                  imageUrl: _uploadedImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const ColoredBox(color: AppColors.elevated),
                  errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.elevated),
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.imagePlus,
                          color: AppColors.amber, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'events.coverPicker'.tr(),
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_coverImage != null || _uploadedImageUrl != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: AppColors.voidColor.withValues(alpha: 0.6),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _removeCover,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(LucideIcons.x, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitleDesc() {
    return _sectionWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleCtrl,
            maxLength: 200,
            style: AppTypography.body(size: 15, color: AppColors.ink),
            decoration: InputDecoration(
              labelText: 'create.title'.tr(),
            ),
            onChanged: (_) => setState(() {/* triggert Submit-Button-State */}),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            maxLength: 5000,
            style: AppTypography.body(size: 14, color: AppColors.ink),
            decoration: InputDecoration(
              labelText: 'create.description'.tr(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCategory() {
    return _sectionWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('events.category'.tr(), style: AppTypography.label(size: 10)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 5,
            childAspectRatio: 1,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: _categories.map((c) {
              final selected = c.value == _category;
              return GestureDetector(
                onTap: () => setState(() => _category = c.value),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? c.color.withValues(alpha: 0.30)
                        : AppColors.elevated,
                    border: Border.all(
                      color: selected ? c.color : AppColors.line,
                      width: selected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(c.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          c.labelKey.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.label(
                            size: 9,
                            color: selected ? c.color : AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionStartDateTime() {
    return _sectionWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('events.startDate'.tr(), style: AppTypography.label(size: 10)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: true),
                  icon: const Icon(LucideIcons.calendar, size: 16),
                  label: Text(
                    _startDate == null
                        ? 'events.pickDate'.tr()
                        : DateFormat('EEE, dd.MM.yyyy', context.locale.toLanguageTag())
                            .format(_startDate!),
                  ),
                ),
              ),
              if (!_isAllDay) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startDate == null
                        ? null
                        : () => _pickTime(isStart: true),
                    icon: const Icon(LucideIcons.clock, size: 16),
                    label: Text(
                      _startDate == null
                          ? 'events.startTime'.tr()
                          : DateFormat('HH:mm').format(_startDate!),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionAllDayToggle() {
    return _sectionWrap(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.amber,
        value: _isAllDay,
        onChanged: (v) => setState(() => _isAllDay = v),
        title: Text(
          'events.allDay'.tr(),
          style: AppTypography.body(size: 14, color: AppColors.ink),
        ),
      ),
    );
  }

  Widget _sectionEndDateTime() {
    return _sectionWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('events.endDate'.tr(),
                    style: AppTypography.label(size: 10)),
              ),
              if (_endDate != null)
                TextButton(
                  onPressed: () => setState(() => _endDate = null),
                  child: Text('common.delete'.tr(),
                      style: AppTypography.label(
                          size: 10, color: AppColors.herzrotWarm)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: false),
                  icon: const Icon(LucideIcons.calendar, size: 16),
                  label: Text(
                    _endDate == null
                        ? 'events.pickDate'.tr()
                        : DateFormat('EEE, dd.MM.yyyy', context.locale.toLanguageTag())
                            .format(_endDate!),
                  ),
                ),
              ),
              if (!_isAllDay) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _endDate == null ? null : () => _pickTime(isStart: false),
                    icon: const Icon(LucideIcons.clock, size: 16),
                    label: Text(
                      _endDate == null
                          ? 'events.endTime'.tr()
                          : DateFormat('HH:mm').format(_endDate!),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionOnlineToggle() {
    return _sectionWrap(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.amber,
            value: _isOnline,
            onChanged: (v) => setState(() => _isOnline = v),
            title: Text(
              'events.online'.tr(),
              style: AppTypography.body(size: 14, color: AppColors.ink),
            ),
          ),
          if (_isOnline) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _onlineUrlCtrl,
              keyboardType: TextInputType.url,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'events.onlineUrl'.tr(),
                hintText: 'https://...',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLocation() {
    return _sectionWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _locationNameCtrl,
            style: AppTypography.body(size: 14, color: AppColors.ink),
            decoration: InputDecoration(
              labelText: 'events.locationName'.tr(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _locationAddressCtrl,
            style: AppTypography.body(size: 14, color: AppColors.ink),
            decoration: InputDecoration(
              labelText: 'events.locationAddress'.tr(),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _useGps,
            icon: const Icon(LucideIcons.locate, size: 16),
            label: Text('events.useGps'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.amber,
              side: const BorderSide(color: AppColors.amber),
            ),
          ),
          if (_lat != null && _lng != null) ...[
            const SizedBox(height: 6),
            Text(
              'GPS: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
              style: AppTypography.label(size: 10, color: AppColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionMaxAttendees() {
    return _sectionWrap(
      child: TextField(
        controller: _maxAttendeesCtrl,
        keyboardType: TextInputType.number,
        style: AppTypography.body(size: 14, color: AppColors.ink),
        decoration: InputDecoration(
          labelText: 'events.maxAttendees'.tr(),
        ),
      ),
    );
  }

  Widget _sectionCost() {
    return _sectionWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text('events.costFree'.tr()),
                  selected: _isFree,
                  onSelected: (_) => setState(() => _isFree = true),
                  selectedColor: AppColors.amber.withValues(alpha: 0.3),
                  backgroundColor: AppColors.elevated,
                  labelStyle: AppTypography.label(
                      size: 11,
                      color: _isFree ? AppColors.amber : AppColors.inkSoft),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text('events.costPaid'.tr()),
                  selected: !_isFree,
                  onSelected: (_) => setState(() => _isFree = false),
                  selectedColor: AppColors.amber.withValues(alpha: 0.3),
                  backgroundColor: AppColors.elevated,
                  labelStyle: AppTypography.label(
                      size: 11,
                      color: !_isFree ? AppColors.amber : AppColors.inkSoft),
                ),
              ),
            ],
          ),
          if (!_isFree) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _costCtrl,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'events.costDescription'.tr(),
                hintText: '5 EUR / Person',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionWhatToBring() {
    return _sectionWrap(
      child: TextField(
        controller: _whatToBringCtrl,
        maxLines: 2,
        style: AppTypography.body(size: 14, color: AppColors.ink),
        decoration: InputDecoration(
          labelText: 'events.whatToBring'.tr(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _sectionContact() {
    return _sectionWrap(
      child: TextField(
        controller: _contactCtrl,
        style: AppTypography.body(size: 14, color: AppColors.ink),
        decoration: InputDecoration(
          labelText: 'events.contactInfo'.tr(),
        ),
      ),
    );
  }

  Widget _sectionRecurring() {
    return _sectionWrap(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.amber,
            value: _isRecurring,
            onChanged: (v) => setState(() => _isRecurring = v),
            title: Text(
              'events.recurring'.tr(),
              style: AppTypography.body(size: 14, color: AppColors.ink),
            ),
          ),
          if (_isRecurring) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _recurringChip('daily', 'events.recurringDaily'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _recurringChip('weekly', 'events.recurringWeekly'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _recurringChip('monthly', 'events.recurringMonthly'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _recurringChip(String value, String labelKey) {
    final selected = _recurringPattern == value;
    return ChoiceChip(
      label: Text(labelKey.tr()),
      selected: selected,
      onSelected: (_) => setState(() => _recurringPattern = value),
      selectedColor: AppColors.amber.withValues(alpha: 0.3),
      backgroundColor: AppColors.elevated,
      labelStyle: AppTypography.label(
          size: 11, color: selected ? AppColors.amber : AppColors.inkSoft),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.herzrotWarm.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.herzrotWarm.withValues(alpha: 0.4)),
      ),
      child: Text(
        msg,
        style: AppTypography.body(size: 13, color: AppColors.herzrotWarm),
      ),
    );
  }

  Widget _submitButton() {
    final canSubmit = !_submitting && _titleCtrl.text.trim().isNotEmpty;
    return SizedBox(
      height: 60,
      child: FilledButton.icon(
        onPressed: canSubmit ? _submit : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.voidColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(LucideIcons.send, size: 18),
        label: Text(
          'events.publish'.tr(),
          style: AppTypography.body(size: 15, color: AppColors.voidColor),
        ),
      ),
    );
  }

  Widget _loadingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.voidColor.withValues(alpha: 0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.amber),
              const SizedBox(height: 10),
              Text(
                _uploading
                    ? 'events.uploadingImage'.tr()
                    : 'events.creating'.tr(),
                style: AppTypography.body(size: 14, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
