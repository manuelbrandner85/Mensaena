import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_modal.dart';
import '../../core/widgets/cinema_progress.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase/database_service.dart';
import '../../services/supabase/storage_service.dart';
import 'post_detail_screen.dart';

/// Edit-Form fuer einen Post. Laedt bestehende Daten, befuellt die
/// CinemaInputs und schreibt Aenderungen zurueck via `db.updatePost`.
class PostEditScreen extends ConsumerStatefulWidget {
  final String postId;
  const PostEditScreen({super.key, required this.postId});

  @override
  ConsumerState<PostEditScreen> createState() => _PostEditScreenState();
}

class _PostEditScreenState extends ConsumerState<PostEditScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _tags = TextEditingController();
  String? _imageUrl;
  bool _loaded = false;
  bool _saving = false;
  bool _uploading = false;
  bool _deleting = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _prefill(Map<String, dynamic> post) {
    _title.text = (post['title'] as String?) ?? '';
    _content.text = (post['content'] as String?) ?? '';
    final tags = post['tags'];
    if (tags is List) {
      _tags.text = tags.map((t) => t.toString()).join(', ');
    }
    _imageUrl = post['image_url'] as String?;
    _loaded = true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final path =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await storage.uploadBytes(
        bucket: StorageService.postImagesBucket,
        path: path,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _imageUrl = url);
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: 'Upload fehlgeschlagen: $e',
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final tagList = _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      await db.updatePost(widget.postId, {
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'tags': tagList,
        'image_url': _imageUrl,
      });
      ref.invalidate(postDetailProvider(widget.postId));
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.success,
        message: 'Beitrag aktualisiert.',
      );
      GoRouter.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: 'Speichern fehlgeschlagen: $e',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await CinemaModal.show<bool>(
      context,
      title: 'Beitrag loeschen?',
      child: Text(
        'Diese Aktion kann nicht rueckgaengig gemacht werden. '
        'Der Beitrag wird fuer alle Nachbar*innen entfernt.',
        style: MnTypography.body(color: MnColors.inkSoft),
      ),
      actions: [
        GlowButton(
          label: 'Abbrechen',
          variant: GlowVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlowButton(
          label: 'Loeschen',
          variant: GlowVariant.crisis,
          icon: LucideIcons.trash2,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;
    await _delete();
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await db.deletePost(widget.postId);
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.success,
        message: 'Beitrag geloescht.',
      );
      GoRouter.of(context).go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: 'Loeschen fehlgeschlagen: $e',
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'BEITRAG BEARBEITEN'),
      body: SafeArea(
        child: postAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: CinemaLoadingSkeleton(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Fehler: $e', style: MnTypography.body()),
          ),
          data: (post) {
            if (post == null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Beitrag nicht gefunden.',
                  style: MnTypography.body(),
                ),
              );
            }
            if (!_loaded) _prefill(post);
            return _buildForm(context);
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CinemaInput(
          controller: _title,
          label: 'TITEL',
          placeholder: 'Worum geht es?',
        ),
        const SizedBox(height: 16),
        CinemaInput(
          controller: _content,
          label: 'BESCHREIBUNG',
          placeholder: 'Beschreibe deine Anfrage oder dein Angebot...',
          variant: CinemaInputVariant.multiline,
          maxLines: 6,
        ),
        const SizedBox(height: 16),
        CinemaInput(
          controller: _tags,
          label: 'TAGS',
          placeholder: 'kommagetrennt, z.B. werkzeug, garten',
        ),
        const SizedBox(height: 24),
        Text('BILD', style: MnTypography.label()),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploading ? null : _pickImage,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: MnColors.surface,
              borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
              border: Border.all(
                color: MnColors.amber.withValues(alpha: 0.2),
                width: 1.5,
              ),
              image: (_imageUrl != null && _imageUrl!.startsWith('http'))
                  ? DecorationImage(
                      image: NetworkImage(_imageUrl!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.35),
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            child: Center(
              child: _uploading
                  ? const SizedBox(
                      width: 180,
                      child: CinemaProgress(value: 0.6, label: 'Upload...'),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _imageUrl == null
                              ? LucideIcons.imagePlus
                              : LucideIcons.imageMinus,
                          size: 28,
                          color: MnColors.amber,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _imageUrl == null
                              ? 'Bild auswaehlen'
                              : 'Bild ersetzen',
                          style: MnTypography.body(color: MnColors.inkSoft),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (_imageUrl != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _uploading ? null : () => setState(() => _imageUrl = null),
              icon: const Icon(LucideIcons.x, size: 14, color: MnColors.mute),
              label: Text(
                'Bild entfernen',
                style: MnTypography.body(color: MnColors.mute, size: 12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        GlowButton(
          label: _saving ? 'Speichern...' : 'Speichern',
          variant: GlowVariant.primary,
          fullWidth: true,
          onPressed: (_saving || _uploading || _deleting) ? null : _save,
        ),
        const SizedBox(height: 12),
        GlowButton(
          label: _deleting ? 'Loesche...' : 'Loeschen',
          variant: GlowVariant.crisis,
          icon: LucideIcons.trash2,
          fullWidth: true,
          onPressed: (_saving || _uploading || _deleting) ? null : _confirmDelete,
        ),
      ],
    );
  }
}
