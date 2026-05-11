// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas, unused_import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_select.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase/database_service.dart';

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
  bool _busy = false;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final profile = ref.watch(profileByIdProvider(widget.userId)).asData?.value;
      if (profile != null) {
        _name.text = (profile['full_name'] as String?) ?? '';
        _bio.text = (profile['bio'] as String?) ?? '';
        _location.text = (profile['location'] as String?) ?? '';
        _radius = (profile['radius_km'] as int?) ?? 5;
        _loaded = true;
      }
    }

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'PROFIL BEARBEITEN'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              onPressed: _busy ? null : _save,
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
