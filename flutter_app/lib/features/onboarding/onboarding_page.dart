import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// 3-Step-Wizard direkt nach Sign-Up: Avatar/Name → Standort → Interessen.
/// Setzt am Ende `profiles.onboarding_completed = true`. Der Router schickt
/// User mit `onboarding_completed=false` hierhin, sonst direkt zum Dashboard.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  int _step = 0;
  bool _saving = false;

  // Step 1
  final _name = TextEditingController();
  String? _avatarUrl;
  bool _uploadingAvatar = false;

  // Step 2
  final _city = TextEditingController();
  final _postalCode = TextEditingController();

  // Step 3
  final Set<String> _offerTags = {};
  final Set<String> _seekTags = {};

  static const _interestOptions = [
    '🌱 Garten',
    '🛠️ Handwerk',
    '🍳 Kochen',
    '👶 Kinder',
    '🐾 Tiere',
    '💻 Technik',
    '📚 Bildung',
    '🎵 Musik',
    '🚗 Mobilität',
    '🏠 Wohnen',
    '🤝 Pflege',
    '♻️ Nachhaltigkeit',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _city.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      final ext = picked.name.split('.').last.toLowerCase();
      final path =
          '${user.id}/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await picked.readAsBytes();
      await db.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = db.storage.from('avatars').getPublicUrl(path);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _name.text.trim().length >= 2;
      case 1:
        return _city.text.trim().isNotEmpty ||
            _postalCode.text.trim().isNotEmpty;
      case 2:
        return _offerTags.isNotEmpty || _seekTags.isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _next() async {
    if (!_canAdvance) return;
    HapticFeedback.lightImpact();
    if (_step < 2) {
      setState(() => _step += 1);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    await _finish();
  }

  Future<void> _back() async {
    if (_step == 0) return;
    setState(() => _step -= 1);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      await db.from('profiles').update(<String, dynamic>{
        'name': _name.text.trim(),
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        if (_postalCode.text.trim().isNotEmpty)
          'postal_code': _postalCode.text.trim(),
        if (_offerTags.isNotEmpty) 'offer_tags': _offerTags.toList(),
        if (_seekTags.isNotEmpty) 'seek_tags': _seekTags.toList(),
        'onboarding_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      if (!mounted) return;
      context.go(Routes.dashboard);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    // Auch beim Skip onboarding_completed setzen, damit User nicht
    // jedes Mal hier landen.
    setState(() => _saving = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      await db.from('profiles').update(<String, dynamic>{
        'onboarding_completed': true,
      }).eq('id', user.id);
      if (!mounted) return;
      context.go(Routes.dashboard);
    } catch (_) {
      // Egal — bei Fehler kommt der User später wieder hierhin.
      if (mounted) context.go(Routes.dashboard);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schritt ${_step + 1} von 3'),
        leading: _step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _back,
              ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _skip,
            child: const Text('Überspringen'),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / 3,
            minHeight: 3,
            backgroundColor: AppColors.stone200,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StepName(
                  controller: _name,
                  avatarUrl: _avatarUrl,
                  uploading: _uploadingAvatar,
                  onPickAvatar: _pickAvatar,
                  onChanged: () => setState(() {}),
                ),
                _StepLocation(
                  city: _city,
                  postalCode: _postalCode,
                  onChanged: () => setState(() {}),
                ),
                _StepInterests(
                  options: _interestOptions,
                  offerTags: _offerTags,
                  seekTags: _seekTags,
                  onToggleOffer: (t) {
                    setState(() {
                      if (_offerTags.contains(t)) {
                        _offerTags.remove(t);
                      } else {
                        _offerTags.add(t);
                      }
                    });
                  },
                  onToggleSeek: (t) {
                    setState(() {
                      if (_seekTags.contains(t)) {
                        _seekTags.remove(t);
                      } else {
                        _seekTags.add(t);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: (_saving || !_canAdvance) ? null : _next,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_step < 2 ? 'Weiter' : 'Fertig'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepName extends StatelessWidget {
  const _StepName({
    required this.controller,
    required this.avatarUrl,
    required this.uploading,
    required this.onPickAvatar,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onPickAvatar;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wer bist du?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dein Name wird Nachbarn angezeigt. Ein Foto hilft beim Vertrauen.',
            style: TextStyle(fontSize: 14, color: AppColors.ink400),
          ),
          const SizedBox(height: 24),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary500.withValues(alpha: 0.15),
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? const Icon(
                          Icons.person_outline,
                          size: 36,
                          color: AppColors.primary500,
                        )
                      : null,
                ),
                Material(
                  color: AppColors.primary500,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: uploading ? null : onPickAvatar,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: uploading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 14,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name *',
              hintText: 'z. B. Anna',
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _StepLocation extends StatelessWidget {
  const _StepLocation({
    required this.city,
    required this.postalCode,
    required this.onChanged,
  });

  final TextEditingController city;
  final TextEditingController postalCode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wo bist du?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mensaena zeigt dir Nachbarn und Hilfsanfragen aus deiner Umgebung. '
            'Eine grobe Region reicht — Adresse ist nicht nötig.',
            style: TextStyle(fontSize: 14, color: AppColors.ink400),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Stadt',
              hintText: 'z. B. Wien',
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: postalCode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'PLZ',
              hintText: 'z. B. 1010',
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _StepInterests extends StatelessWidget {
  const _StepInterests({
    required this.options,
    required this.offerTags,
    required this.seekTags,
    required this.onToggleOffer,
    required this.onToggleSeek,
  });

  final List<String> options;
  final Set<String> offerTags;
  final Set<String> seekTags;
  final void Function(String) onToggleOffer;
  final void Function(String) onToggleSeek;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Was kannst du, was suchst du?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wähle ein paar Themen, die dich interessieren — wir zeigen dir '
            'passende Hilfsanfragen und Angebote in deiner Nachbarschaft.',
            style: TextStyle(fontSize: 14, color: AppColors.ink400),
          ),
          const SizedBox(height: 20),
          const _SectionTitle(text: '✨ Ich biete an'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options
                .map(
                  (t) => FilterChip(
                    label: Text(t),
                    selected: offerTags.contains(t),
                    onSelected: (_) => onToggleOffer(t),
                    selectedColor:
                        AppColors.primary500.withValues(alpha: 0.15),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(text: '🤝 Ich suche'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options
                .map(
                  (t) => FilterChip(
                    label: Text(t),
                    selected: seekTags.contains(t),
                    onSelected: (_) => onToggleSeek(t),
                    selectedColor:
                        AppColors.trust400.withValues(alpha: 0.15),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.ink700,
        letterSpacing: 0.4,
      ),
    );
  }
}
