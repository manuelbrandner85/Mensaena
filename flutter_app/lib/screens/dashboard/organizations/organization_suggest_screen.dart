import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/organization_categories.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../services/image_upload_service.dart';
import '../../../widgets/effects/bloom.dart';
import '../../../widgets/effects/glass_card.dart';
import '../../../widgets/effects/tilt_card.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';

/// SKILL: mensaena-features + mensaena-design
/// Phase O4 — Vorschlag-Screen mit korrekten Mensaena-Kategorien
/// (16 `kOrgCategories`), Bottom-Sheet-Grid-Picker, Country-Auswahl
/// DE/AT/CH und vollwertigem Success-State (CheckCircle + Bloom).
class OrganizationSuggestScreen extends ConsumerStatefulWidget {
  const OrganizationSuggestScreen({super.key});

  @override
  ConsumerState<OrganizationSuggestScreen> createState() =>
      _OrganizationSuggestScreenState();
}

class _OrganizationSuggestScreenState
    extends ConsumerState<OrganizationSuggestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  String? _category;
  String _country = 'DE';
  File? _logoFile;
  bool _logoUploading = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _address.dispose();
    _desc.dispose();
    _phone.dispose();
    _email.dispose();
    _website.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _name.clear();
    _city.clear();
    _address.clear();
    _desc.clear();
    _phone.clear();
    _email.clear();
    _website.clear();
    setState(() {
      _category = null;
      _country = 'DE';
      _logoFile = null;
      _submitted = false;
      _error = null;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _logoFile = File(picked.path));
    }
  }

  Future<void> _openCategoryPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'organizations.pickCategory'.tr(),
                    style: AppTypography.display(
                      size: 20,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GridView.count(
                      controller: scrollCtrl,
                      crossAxisCount: 2,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: kOrgCategories.map((cfg) {
                        final active = cfg.value == _category;
                        return _CategoryCell(
                          config: cfg,
                          active: active,
                          onTap: () => Navigator.pop(ctx, cfg.value),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _category = selected);
    }
  }

  bool _isValid() {
    if (_name.text.trim().length < 3) return false;
    if (_category == null) return false;
    if (_desc.text.trim().length < 20) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_isValid()) {
      setState(() {
        if (_name.text.trim().length < 3) {
          _error = 'organizations.nameRequired'.tr();
        } else if (_category == null) {
          _error = 'organizations.categoryRequired'.tr();
        } else {
          _error = 'organizations.descRequired'.tr();
        }
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    String? logoUrl;
    if (_logoFile != null) {
      setState(() => _logoUploading = true);
      final urls = await ImageUploadService.upload(
        [_logoFile!],
        bucket: 'post-images',
      );
      if (mounted) setState(() => _logoUploading = false);
      if (urls.isNotEmpty) logoUrl = urls.first;
    }
    final ok = await OrganizationsRepository.suggest(
      name: _name.text.trim(),
      category: _category!,
      city: _city.text.trim().isEmpty ? '' : _city.text.trim(),
      country: _country,
      description: _desc.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      website: _website.text.trim().isEmpty ? null : _website.text.trim(),
      logoUrl: logoUrl,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) {
        _submitted = true;
        _error = null;
      } else {
        _error = 'organizations.reviewError'.tr();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'organizations.suggestTitle'.tr(),
      currentRoute: '/dashboard/organizations',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditorialModuleHeader(
                metaIndex: '§ 14',
                metaCategory: 'organizations.organizationsTitle'.tr(),
                title: 'organizations.suggestTitle'.tr(),
                subtitle: 'organizations.suggestSubtitle'.tr(),
              ),
              if (_submitted) _buildSuccess() else _buildForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Bloom(
            color: AppColors.leben,
            radius: 60,
            intensity: 1.0,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.leben.withValues(alpha: 0.18),
              ),
              child: const Icon(
                LucideIcons.checkCircle,
                size: 56,
                color: AppColors.leben,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'organizations.suggestionSuccess'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: 22,
              color: AppColors.ink,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/dashboard/organizations');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('common.back'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _resetForm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'organizations.anotherSuggestion'.tr(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('${'organizations.name'.tr()} *'),
            TextFormField(
              controller: _name,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              decoration: _inputDeco(hint: 'Caritas, Tafel, ...'),
              validator: (v) {
                if ((v ?? '').trim().length < 3) {
                  return 'organizations.nameRequired'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('${'organizations.categoryField'.tr()} *'),
            _CategoryPickerButton(
              category: _category,
              onTap: _openCategoryPicker,
            ),
            const SizedBox(height: 16),
            _label('organizations.country'.tr()),
            _buildCountryDropdown(),
            const SizedBox(height: 16),
            _label('organizations.city'.tr()),
            TextFormField(
              controller: _city,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: _inputDeco(hint: 'Berlin, Wien, Zürich, ...'),
            ),
            const SizedBox(height: 16),
            _label('organizations.address'.tr()),
            TextFormField(
              controller: _address,
              minLines: 2,
              maxLines: 3,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: _inputDeco(hint: 'Straße, Hausnummer, PLZ'),
            ),
            const SizedBox(height: 16),
            _label('${'organizations.description'.tr()} *'),
            TextFormField(
              controller: _desc,
              minLines: 4,
              maxLines: 6,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: _inputDeco(hint: 'Was macht diese Organisation?'),
              validator: (v) {
                if ((v ?? '').trim().length < 20) {
                  return 'organizations.descRequired'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('organizations.logoLabel'.tr()),
            _LogoPicker(
              file: _logoFile,
              uploading: _logoUploading,
              onTap: _pickLogo,
            ),
            const SizedBox(height: 16),
            _label('organizations.phone'.tr()),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: _inputDeco(hint: '+49 30 ...'),
            ),
            const SizedBox(height: 16),
            _label('organizations.email'.tr()),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: _inputDeco(hint: 'kontakt@beispiel.org'),
            ),
            const SizedBox(height: 16),
            _label('organizations.website'.tr()),
            TextFormField(
              controller: _website,
              keyboardType: TextInputType.url,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: _inputDeco(hint: 'https://...'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.herzrot.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.herzrot.withValues(alpha: 0.30)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertCircle,
                        size: 16, color: AppColors.herzrotWarm),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.herzrotWarm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            TiltCard(
              intensity: 0.5,
              borderRadius: 14,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed:
                      (_submitting || !_isValid()) ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        AppColors.amber.withValues(alpha: 0.30),
                    disabledForegroundColor:
                        Colors.black.withValues(alpha: 0.50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(LucideIcons.send, size: 18),
                  label: Text(
                    'organizations.submitSuggestion'.tr(),
                    style: AppTypography.label(
                      size: 14,
                      color: Colors.black,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _country,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          icon: const Icon(LucideIcons.chevronDown,
              size: 16, color: AppColors.inkSoft),
          style: AppTypography.body(size: 14, color: AppColors.ink),
          items: kCountryFlags.keys.map((code) {
            final flag = kCountryFlags[code] ?? '';
            final label = kCountryLabels[code] ?? code;
            return DropdownMenuItem(
              value: code,
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text(label),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _country = v ?? _country),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.label(
          size: 11,
          color: AppColors.inkSoft,
          letterSpacing: 0.10,
        ),
      ),
    );
  }

  InputDecoration _inputDeco({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body(size: 13, color: AppColors.mute),
      filled: true,
      fillColor: AppColors.surface.withValues(alpha: 0.40),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: AppColors.amber.withValues(alpha: 0.60), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: AppColors.herzrot.withValues(alpha: 0.60)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: AppColors.herzrot.withValues(alpha: 0.80), width: 1.4),
      ),
      errorStyle: AppTypography.body(
        size: 12,
        color: AppColors.herzrotWarm,
      ),
    );
  }
}

class _CategoryPickerButton extends StatelessWidget {
  const _CategoryPickerButton({
    required this.category,
    required this.onTap,
  });

  final String? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cfg = category != null ? getCategoryConfig(category!) : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cfg != null
                  ? cfg.color.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (cfg?.bgColor ?? AppColors.line)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  cfg?.icon ?? LucideIcons.layoutGrid,
                  size: 18,
                  color: cfg?.color ?? AppColors.inkSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cfg?.label ?? 'organizations.pickCategory'.tr(),
                  style: AppTypography.body(
                    size: 14,
                    color: cfg != null ? AppColors.ink : AppColors.inkSoft,
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronDown,
                  size: 16, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.config,
    required this.active,
    required this.onTap,
  });

  final OrgCategoryConfig config;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: config.bgColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? config.color
                  : config.color.withValues(alpha: 0.20),
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(config.icon, size: 26, color: config.color),
              const SizedBox(height: 8),
              Text(
                config.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 12,
                  color: AppColors.ink,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.file,
    required this.uploading,
    required this.onTap,
  });

  final File? file;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null
                ? AppColors.amber.withValues(alpha: 0.50)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: uploading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.amber,
                  ),
                ),
              )
            : file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(file!, fit: BoxFit.cover),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.pencil,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.image,
                        size: 18,
                        color: AppColors.inkSoft,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'organizations.logoHint'.tr(),
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
