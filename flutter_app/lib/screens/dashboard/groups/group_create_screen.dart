import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/groups_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/image_upload_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/address_autocomplete_field.dart';

class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  String _category = 'nachbarschaft';
  bool _isPrivate = false;
  File? _cover;
  double? _lat;
  double? _lng;
  int _radiusKm = 0;
  int _maxMembers = 0;
  bool _submitting = false;
  bool _nameError = false;
  String? _error;

  // Wert = stabil (DB + Web-Parität), Label übersetzt, Emoji als Akzent.
  static const List<({String value, String i18n, String emoji})> _categories = [
    (value: 'nachbarschaft', i18n: 'groups.catNachbarschaft', emoji: '🏘️'),
    (value: 'hobby', i18n: 'groups.catHobby', emoji: '🎨'),
    (value: 'sport', i18n: 'groups.catSport', emoji: '⚽'),
    (value: 'eltern', i18n: 'groups.catEltern', emoji: '👶'),
    (value: 'senioren', i18n: 'groups.catSenioren', emoji: '🧓'),
    (value: 'umwelt', i18n: 'groups.catUmwelt', emoji: '🌿'),
    (value: 'bildung', i18n: 'groups.catBildung', emoji: '📚'),
    (value: 'tiere', i18n: 'groups.catTiere', emoji: '🐾'),
    (value: 'handwerk', i18n: 'groups.catHandwerk', emoji: '🔧'),
    (value: 'sonstiges', i18n: 'groups.catSonstiges', emoji: '💬'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _location.dispose();
    super.dispose();
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[äÄ]'), 'ae')
        .replaceAll(RegExp(r'[öÖ]'), 'oe')
        .replaceAll(RegExp(r'[üÜ]'), 'ue')
        .replaceAll(RegExp(r'[ß]'), 'ss')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 900,
      imageQuality: 82,
    );
    if (result == null) return;
    setState(() => _cover = File(result.path));
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() {
        _nameError = true;
        _error = 'create.nameRequired'.tr();
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    String? coverUrl;
    if (_cover != null) {
      final urls = await ImageUploadService.upload([_cover!]);
      coverUrl = urls.isNotEmpty ? urls.first : null;
    }
    final id = await GroupsRepository.create(
      name: _name.text.trim(),
      slug: _slugify(_name.text.trim()),
      category: _category,
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      isPrivate: _isPrivate,
      coverImageUrl: coverUrl,
      maxMembers: _maxMembers > 0 ? _maxMembers : null,
      latitude: _lat,
      longitude: _lng,
      radiusKm: _lat != null && _radiusKm > 0 ? _radiusKm : null,
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
    context.push('/dashboard/groups/$id');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'create.groupCreateTitle'.tr(),
      currentRoute: '/dashboard/groups',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Titelbild — gibt der Gruppe sofort Charakter.
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 132,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.5),
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(14),
                  image: _cover != null
                      ? DecorationImage(
                          image: FileImage(_cover!), fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: _cover != null
                    ? Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: GestureDetector(
                            onTap: () => setState(() => _cover = null),
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
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.image,
                              color: AppColors.bronze, size: 26),
                          const SizedBox(height: 6),
                          Text('groups.addCover'.tr(),
                              style: AppTypography.caption()),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 60,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              onChanged: _nameError
                  ? (_) => setState(() => _nameError = false)
                  : null,
              decoration: InputDecoration(
                labelText: 'create.groupName'.tr(),
                errorText: _nameError ? 'create.nameRequired'.tr() : null,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              maxLines: 4,
              maxLength: 500,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'create.description'.tr(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            Text('groups.categoryLabel'.tr(),
                style: AppTypography.label(size: 10)),
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
            const SizedBox(height: 16),
            // Standort (optional) — lokale Gruppen besser auffindbar machen.
            Text('groups.location'.tr(), style: AppTypography.label(size: 10)),
            const SizedBox(height: 8),
            AddressAutocompleteField(
              controller: _location,
              label: 'groups.location'.tr(),
              hint: 'groups.locationHint'.tr(),
              onSelected: (s) => setState(() {
                _lat = s.lat;
                _lng = s.lng;
              }),
            ),
            if (_lat != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('groups.radius'.tr(),
                      style: AppTypography.label(size: 10)),
                  const Spacer(),
                  Text(_radiusKm == 0 ? '–' : '$_radiusKm km',
                      style: AppTypography.mono(
                          size: 12, color: AppColors.bronze)),
                ],
              ),
              Slider(
                value: _radiusKm.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: AppColors.bronze,
                onChanged: (v) => setState(() => _radiusKm = v.round()),
              ),
            ],
            const SizedBox(height: 6),
            // Maximale Mitglieder (optional).
            Row(
              children: [
                Text('groups.maxMembers'.tr(),
                    style: AppTypography.label(size: 10)),
                const SizedBox(width: 8),
                Text('groups.maxMembersHint'.tr(),
                    style: AppTypography.caption()),
                const Spacer(),
                Text(_maxMembers == 0 ? '∞' : '$_maxMembers',
                    style: AppTypography.mono(
                        size: 13, color: AppColors.ink)),
              ],
            ),
            Slider(
              value: _maxMembers.toDouble(),
              min: 0,
              max: 200,
              divisions: 40,
              activeColor: AppColors.amber,
              onChanged: (v) => setState(() => _maxMembers = v.round()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.amber,
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
              title: Text(
                'groups.privateTitle'.tr(),
                style: AppTypography.body(size: 14, color: AppColors.ink),
              ),
              subtitle: Text(
                'groups.privateHint'.tr(),
                style: AppTypography.caption(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.herzrotWarm,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(_submitting
                  ? 'groups.saving'.tr()
                  : 'groups.createButton'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
