import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/profile.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Profile-Edit — Web-Pendant: ProfileEditModal.tsx.
/// Avatar/Cover-Upload + alle Profil-Felder editierbar.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  Future<Profile?>? _future;
  Profile? _profile;
  bool _saving = false;
  // BUG-FIX #15: Form-Key fuer inline Validation
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _homepageCtrl = TextEditingController();

  File? _newAvatar;

  @override
  void initState() {
    super.initState();
    _future = ProfilesRepository.getMine().then((p) {
      if (p != null) {
        _profile = p;
        _nameCtrl.text = p.name ?? '';
        _displayNameCtrl.text = p.displayName ?? '';
        _nicknameCtrl.text = p.nickname ?? '';
        _bioCtrl.text = p.bio ?? '';
        _locationCtrl.text = p.location ?? '';
        _phoneCtrl.text = p.phone ?? '';
        _homepageCtrl.text = p.homepage ?? '';
      }
      return p;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _displayNameCtrl.dispose();
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _homepageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _newAvatar = File(picked.path));
  }

  Future<String?> _uploadAvatar() async {
    final file = _newAvatar;
    final uid = SupabaseService.currentUser?.id;
    if (file == null || uid == null) return null;
    try {
      final ext = file.path.split('.').last;
      final path = '$uid/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await sb.storage.from('avatars').upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      return sb.storage.from('avatars').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    // BUG-FIX #15: Form-Validation vor Submit
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final patch = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'display_name': _displayNameCtrl.text.trim(),
      'nickname': _nicknameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'homepage': _homepageCtrl.text.trim(),
    };
    if (_newAvatar != null) {
      final url = await _uploadAvatar();
      if (!mounted) return; // BUG-FIX #2: Schutz vor disposed widget
      if (url == null) {
        // BUG-FIX #5: Avatar-Upload silent fail behoben → klare Error-UI
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'Avatar-Upload fehlgeschlagen — Profil wurde NICHT gespeichert.',
            style: AppTypography.body(size: 13, color: AppColors.herzrotWarm),
          ),
        ));
        return;
      }
      patch['avatar_url'] = url;
    }
    try {
      await ProfilesRepository.update(uid, patch);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Profil gespeichert.',
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Speichern fehlgeschlagen: $e',
            style: AppTypography.body(size: 13, color: AppColors.herzrotWarm)),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Profil bearbeiten',
      currentRoute: '/dashboard/profile',
      body: SafeArea(
        child: FutureBuilder<Profile?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.amber),
              );
            }
            final p = _profile ?? snap.data;
            final avatarUrl = _newAvatar != null
                ? null
                : (p?.avatarUrl ?? '').isEmpty
                    ? null
                    : p!.avatarUrl;
            return Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Avatar-Picker
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.elevated,
                            border: Border.all(
                                color: AppColors.bronze
                                    .withValues(alpha: 0.5),
                                width: 2),
                            shape: BoxShape.circle,
                            image: _newAvatar != null
                                ? DecorationImage(
                                    image: FileImage(_newAvatar!),
                                    fit: BoxFit.cover,
                                  )
                                : avatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(avatarUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: (avatarUrl == null && _newAvatar == null)
                              ? const Icon(LucideIcons.user,
                                  size: 48, color: AppColors.mute)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.bronze,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.voidColor, width: 3),
                            ),
                            child: const Icon(LucideIcons.camera,
                                size: 14, color: AppColors.voidColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('Tippe für neues Avatar',
                      style: AppTypography.label(
                          size: 10, color: AppColors.mute)),
                ),
                const SizedBox(height: 24),
                // Felder mit Validation
                _Field(
                  label: 'Name',
                  controller: _nameCtrl,
                  hint: 'Dein voller Name',
                  required: true,
                  minLength: 2,
                  maxLength: 80,
                ),
                _Field(
                  label: 'Anzeigename',
                  controller: _displayNameCtrl,
                  hint: 'Wie du angezeigt wirst',
                  maxLength: 40,
                ),
                _Field(
                  label: 'Spitzname',
                  controller: _nicknameCtrl,
                  hint: '@spitzname',
                  maxLength: 30,
                ),
                _Field(
                  label: 'Bio',
                  controller: _bioCtrl,
                  hint: 'Erzähl ein wenig über dich…',
                  multiline: true,
                  maxLength: 300,
                ),
                _Field(
                  label: 'Standort',
                  controller: _locationCtrl,
                  hint: 'Stadt, Land',
                ),
                _Field(
                  label: 'Telefon (optional)',
                  controller: _phoneCtrl,
                  hint: '+49…',
                  keyboardType: TextInputType.phone,
                ),
                _Field(
                  label: 'Homepage / Webseite',
                  controller: _homepageCtrl,
                  hint: 'https://…',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.voidColor),
                          )
                        : const Icon(LucideIcons.save, size: 16),
                    label: Text(_saving ? 'Speichere…' : 'Speichern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bronze,
                      foregroundColor: AppColors.voidColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
            );
          },
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.multiline = false,
    this.keyboardType,
    this.required = false,
    this.minLength,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool multiline;
  final TextInputType? keyboardType;
  final bool required;
  final int? minLength;
  final int? maxLength;

  String? _defaultValidator(String? v) {
    final s = v?.trim() ?? '';
    if (required && s.isEmpty) return '$label ist erforderlich';
    if (minLength != null && s.isNotEmpty && s.length < minLength!) {
      return 'Mindestens $minLength Zeichen';
    }
    if (maxLength != null && s.length > maxLength!) {
      return 'Maximal $maxLength Zeichen';
    }
    if (keyboardType == TextInputType.url &&
        s.isNotEmpty &&
        !RegExp(r'^https?://').hasMatch(s)) {
      return 'URL muss mit https:// beginnen';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label.toUpperCase(),
                  style: AppTypography.label(size: 9, color: AppColors.mute)),
              if (required) ...[
                const SizedBox(width: 4),
                Text('*',
                    style: AppTypography.label(
                        size: 9, color: AppColors.herzrotWarm)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // BUG-FIX #15: TextFormField mit inline-validator
          TextFormField(
            controller: controller,
            maxLines: multiline ? 4 : 1,
            minLines: multiline ? 3 : 1,
            keyboardType: keyboardType,
            validator: _defaultValidator,
            style: AppTypography.body(size: 14, color: AppColors.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.elevated,
              hintText: hint,
              hintStyle:
                  AppTypography.body(size: 13, color: AppColors.mute),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.bronze),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.herzrot),
              ),
              errorStyle: AppTypography.label(
                  size: 10, color: AppColors.herzrotWarm),
            ),
          ),
        ],
      ),
    );
  }
}
