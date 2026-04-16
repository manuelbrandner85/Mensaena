import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _homepageCtrl = TextEditingController();

  bool _profilePublic = true;
  bool _loading = false;
  bool _loadingProfile = true;
  bool _uploadingAvatar = false;

  String? _avatarUrl;
  Uint8List? _pickedImageBytes;

  static final _nicknameRegex = RegExp(r'^[a-z0-9_.\-]*$');
  static final _urlRegex = RegExp(
    r'^https?:\/\/([\w\-]+\.)+[\w\-]+(\/[\w\-._~:/?#\[\]@!$&()*+,;=]*)?$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _homepageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final p = await ref.read(profileServiceProvider).getMyProfile();
    if (p != null && mounted) {
      setState(() {
        _nameCtrl.text = p.name ?? '';
        _nicknameCtrl.text = p.nickname ?? '';
        _bioCtrl.text = p.bio ?? '';
        _locationCtrl.text = p.location ?? '';
        _phoneCtrl.text = p.phone ?? '';
        _homepageCtrl.text = p.homepage ?? '';
        _profilePublic = p.profilePublic ?? true;
        _avatarUrl = p.avatarUrl;
        _loadingProfile = false;
      });
    } else if (mounted) {
      setState(() => _loadingProfile = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final validExts = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
      final fileExt = validExts.contains(ext) ? ext : 'jpg';

      setState(() {
        _pickedImageBytes = bytes;
        _uploadingAvatar = true;
      });

      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final url = await ref
          .read(profileServiceProvider)
          .uploadAvatar(userId, bytes, fileExt);

      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _uploadingAvatar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Hochladen: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(profileServiceProvider).updateProfile(userId, {
        'name': _nameCtrl.text.trim(),
        'nickname': _nicknameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'homepage': _homepageCtrl.text.trim(),
        'profile_public': _profilePublic,
      });
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil gespeichert'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil bearbeiten'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _loading ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Speichern',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Avatar upload
                  _buildAvatarSection(),
                  const SizedBox(height: 28),

                  // Name
                  _buildSectionLabel('Name'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      hintText: 'Dein vollstaendiger Name',
                      prefixIcon: Icon(Icons.person_outline),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Name wird benoetigt';
                      }
                      if (v.trim().length > 60) {
                        return 'Maximal 60 Zeichen';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Nickname
                  _buildSectionLabel('Nickname'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nicknameCtrl,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      hintText: 'benutzername',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '@',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      counterText: '',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-z0-9_.\-]')),
                      LengthLimitingTextInputFormatter(30),
                    ],
                    validator: (v) {
                      if (v != null && v.isNotEmpty && !_nicknameRegex.hasMatch(v)) {
                        return 'Nur a-z, 0-9, _ . - erlaubt';
                      }
                      if (v != null && v.length > 30) {
                        return 'Maximal 30 Zeichen';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Bio
                  _buildSectionLabel('Bio'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bioCtrl,
                    maxLength: 300,
                    maxLines: 4,
                    minLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Erzaehl etwas ueber dich...',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      if (v != null && v.length > 300) {
                        return 'Maximal 300 Zeichen';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Location
                  _buildSectionLabel('Standort'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _locationCtrl,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      hintText: 'z.B. Berlin, Deutschland',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v != null && v.length > 80) {
                        return 'Maximal 80 Zeichen';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Phone
                  _buildSectionLabel('Telefon'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneCtrl,
                    maxLength: 30,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+49 123 456789',
                      prefixIcon: Icon(Icons.phone_outlined),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v != null && v.length > 30) {
                        return 'Maximal 30 Zeichen';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Homepage
                  _buildSectionLabel('Homepage'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _homepageCtrl,
                    maxLength: 200,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'https://deine-website.de',
                      prefixIcon: Icon(Icons.language_outlined),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        if (v.trim().length > 200) {
                          return 'Maximal 200 Zeichen';
                        }
                        if (!_urlRegex.hasMatch(v.trim())) {
                          return 'Bitte eine gueltige URL eingeben (https://...)';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Profile public toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Oeffentliches Profil',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Dein Profil ist fuer andere Nutzer sichtbar',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value: _profilePublic,
                      onChanged: (v) => setState(() => _profilePublic = v),
                      activeColor: AppColors.primary500,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Cancel button
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAvatar,
            child: Stack(
              children: [
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 3),
                    boxShadow: AppShadows.soft,
                  ),
                  child: _pickedImageBytes != null
                      ? ClipOval(
                          child: Image.memory(
                            _pickedImageBytes!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      : AvatarWidget(
                          imageUrl: _avatarUrl,
                          name: _nameCtrl.text.isEmpty
                              ? 'U'
                              : _nameCtrl.text,
                          size: 100,
                        ),
                ),
                // Camera overlay
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary500,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: AppShadows.soft,
                    ),
                    child: _uploadingAvatar
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Profilbild aendern',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
