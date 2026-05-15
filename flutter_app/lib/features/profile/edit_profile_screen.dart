import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_avatar.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_progress.dart';
import '../../core/widgets/cinema_select.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase/database_service.dart';
import '../../services/supabase/storage_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const EditProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();
  int _radius = 5;
  String? _avatarUrl;
  bool _busy = false;
  bool _uploadingAvatar = false;
  bool _loaded = false;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final path = '${widget.userId}/avatar.jpg';
      final url = await storage.uploadBytes(
        bucket: StorageService.avatarsBucket,
        path: path,
        bytes: bytes,
      );
      // Cache-Bust via Query-Param, damit der neue Upload sofort sichtbar wird.
      final busted = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
      await db.updateProfile(widget.userId, {'avatar_url': busted});
      ref.invalidate(profileByIdProvider(widget.userId));
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      setState(() => _avatarUrl = busted);
      CinemaToast.show(
        context,
        variant: ToastVariant.success,
        message: 'Profilbild aktualisiert.',
      );
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: 'Upload fehlgeschlagen: $e',
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final profile = ref.watch(profileByIdProvider(widget.userId)).asData?.value;
      if (profile != null) {
        _name.text = (profile['full_name'] as String?) ?? '';
        _bio.text = (profile['bio'] as String?) ?? '';
        _location.text = (profile['location'] as String?) ?? '';
        _radius = (profile['radius_km'] as int?) ?? 5;
        _avatarUrl = profile['avatar_url'] as String?;
        _loaded = true;
      }
    }

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'PROFIL BEARBEITEN'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AvatarSection(
              imageUrl: _avatarUrl,
              displayName: _name.text,
              uploading: _uploadingAvatar,
              onTap: _uploadingAvatar ? null : _pickAvatar,
            ),
            const SizedBox(height: 24),
            CinemaInput(controller: _name, label: 'NAME'),
            const SizedBox(height: 16),
            CinemaInput(
              controller: _bio,
              label: 'BIO',
              variant: CinemaInputVariant.multiline,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            CinemaInput(controller: _location, label: 'ORT'),
            const SizedBox(height: 16),
            CinemaSelect<int>(
              label: 'RADIUS',
              value: _radius,
              options: const [
                CinemaSelectOption(value: 1, label: '1 km'),
                CinemaSelectOption(value: 2, label: '2 km'),
                CinemaSelectOption(value: 5, label: '5 km'),
                CinemaSelectOption(value: 10, label: '10 km'),
                CinemaSelectOption(value: 25, label: '25 km'),
              ],
              onChanged: (v) => setState(() => _radius = v),
            ),
            const SizedBox(height: 24),
            GlowButton(
              label: _busy ? 'Speichern...' : 'Speichern',
              variant: GlowVariant.primary,
              fullWidth: true,
              onPressed: (_busy || _uploadingAvatar) ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await db.updateProfile(widget.userId, {
        'full_name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'location': _location.text.trim(),
        'radius_km': _radius,
      });
      ref.invalidate(profileByIdProvider(widget.userId));
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.success,
        message: 'Profil aktualisiert.',
      );
      GoRouter.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _AvatarSection extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final bool uploading;
  final VoidCallback? onTap;

  const _AvatarSection({
    required this.imageUrl,
    required this.displayName,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CinemaAvatar(
              imageUrl: imageUrl,
              displayName: displayName.isEmpty ? null : displayName,
              size: AvatarSize.xl,
              onTap: onTap,
            ),
            Container(
              decoration: BoxDecoration(
                color: MnColors.amber,
                shape: BoxShape.circle,
                border: Border.all(color: MnColors.voidColor, width: 2),
              ),
              padding: const EdgeInsets.all(6),
              child: Icon(
                uploading ? LucideIcons.loader : LucideIcons.camera,
                size: 14,
                color: MnColors.voidColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (uploading)
          const SizedBox(
            width: 180,
            child: CinemaProgress(value: 0.6, label: 'Upload...'),
          )
        else
          Text(
            'Profilbild aendern',
            style: MnTypography.caption(color: MnColors.mute),
          ),
      ],
    );
  }
}
