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
import '../../core/widgets/cinema_progress.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../core/widgets/kategorie_chip.dart';
import '../../core/widgets/nachbarschaft_card.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase/database_service.dart';
import '../../services/supabase/storage_service.dart';

class PostCreateScreen extends ConsumerStatefulWidget {
  final String? prefilledCategory;
  const PostCreateScreen({super.key, this.prefilledCategory});

  @override
  ConsumerState<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends ConsumerState<PostCreateScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  PostKategorie? _kategorie;
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _tags = TextEditingController();
  String? _imageUrl;
  bool _submitting = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCategory != null) {
      _kategorie = PostKategorie.values
          .where((k) => k.name == widget.prefilledCategory)
          .firstOrNull;
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
      _pageCtrl.animateToPage(
        _step,
        duration: MnDimensions.durMed,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(
        _step,
        duration: MnDimensions.durMed,
        curve: Curves.easeOutCubic,
      );
    }
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

  Future<void> _publish() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _kategorie == null) return;
    setState(() => _submitting = true);
    try {
      final post = await db.createPost({
        'user_id': user.id,
        'type': _kategorie!.name,
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'image_url': _imageUrl,
        'tags': _tags.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
      });
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.success,
        message: 'Beitrag veroeffentlicht.',
      );
      GoRouter.of(context).go('/posts/${post['id']}');
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: 'Veroeffentlichung fehlgeschlagen: $e',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'NEUER BEITRAG'),
      body: SafeArea(
        child: Column(
          children: [
            _StepDots(current: _step, total: 4),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepCategory(
                    selected: _kategorie,
                    onSelect: (k) {
                      setState(() => _kategorie = k);
                      Future.delayed(MnDimensions.durFast, _next);
                    },
                  ),
                  _StepContent(
                    title: _title,
                    content: _content,
                    tags: _tags,
                  ),
                  _StepMedia(
                    imageUrl: _imageUrl,
                    onPick: _pickImage,
                    uploading: _uploading,
                  ),
                  _StepPreview(
                    kategorie: _kategorie,
                    title: _title.text,
                    content: _content.text,
                    imageUrl: _imageUrl,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    GlowButton(
                      label: 'Zurueck',
                      variant: GlowVariant.ghost,
                      onPressed: _back,
                    ),
                  const Spacer(),
                  GlowButton(
                    label: _step < 3
                        ? 'Weiter'
                        : (_submitting ? 'Senden...' : 'Veroeffentlichen'),
                    variant: GlowVariant.primary,
                    onPressed: _submitting
                        ? null
                        : (_step < 3 ? _next : _publish),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int current;
  final int total;
  const _StepDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i == current;
          final past = i < current;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: MnDimensions.durMed,
              width: active ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? MnColors.amber
                    : past
                        ? MnColors.amber.withValues(alpha: 0.5)
                        : MnColors.mute.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StepCategory extends StatelessWidget {
  final PostKategorie? selected;
  final ValueChanged<PostKategorie> onSelect;
  const _StepCategory({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Worum geht es?', style: MnTypography.display(size: 22)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: PostKategorie.values.length,
              itemBuilder: (_, i) {
                final kat = PostKategorie.values[i];
                final isSelected = selected == kat;
                return GestureDetector(
                  onTap: () => onSelect(kat),
                  child: AnimatedContainer(
                    duration: MnDimensions.durFast,
                    decoration: BoxDecoration(
                      color: MnColors.surface,
                      borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                      border: Border.all(
                        color: isSelected ? MnColors.amber : MnColors.line,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: KategorieChip(kategorie: kat, selected: isSelected),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  final TextEditingController title;
  final TextEditingController content;
  final TextEditingController tags;

  const _StepContent({
    required this.title,
    required this.content,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          CinemaInput(
            controller: title,
            label: 'TITEL',
            placeholder: 'Worum geht es?',
          ),
          const SizedBox(height: 16),
          CinemaInput(
            controller: content,
            label: 'BESCHREIBUNG',
            placeholder: 'Beschreibe deine Anfrage oder dein Angebot...',
            variant: CinemaInputVariant.multiline,
            maxLines: 6,
          ),
          const SizedBox(height: 16),
          CinemaInput(
            controller: tags,
            label: 'TAGS',
            placeholder: 'kommagetrennt, z.B. werkzeug, garten',
          ),
        ],
      ),
    );
  }
}

class _StepMedia extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback onPick;
  final bool uploading;

  const _StepMedia({
    required this.imageUrl,
    required this.onPick,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bild & Standort', style: MnTypography.display(size: 22)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: uploading ? null : onPick,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: MnColors.surface,
                borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                border: Border.all(
                  color: MnColors.amber.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                image: (imageUrl != null && imageUrl!.startsWith('http'))
                    ? DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.35),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: Center(
                child: uploading
                    ? const SizedBox(
                        width: 180,
                        child: CinemaProgress(value: 0.6, label: 'Upload...'),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            imageUrl == null
                                ? LucideIcons.imagePlus
                                : LucideIcons.check,
                            size: 32,
                            color: MnColors.amber,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            imageUrl == null
                                ? 'Bild auswaehlen'
                                : 'Bild ausgewaehlt',
                            style: MnTypography.body(color: MnColors.inkSoft),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Standort: aktueller GPS-Punkt wird beim Veroeffentlichen erfasst.',
            style: MnTypography.caption(),
          ),
        ],
      ),
    );
  }
}

class _StepPreview extends StatelessWidget {
  final PostKategorie? kategorie;
  final String title;
  final String content;
  final String? imageUrl;

  const _StepPreview({
    required this.kategorie,
    required this.title,
    required this.content,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vorschau', style: MnTypography.display(size: 22)),
          const SizedBox(height: 16),
          NachbarschaftCard(
            kategorie: kategorie,
            authorName: 'Du',
            timeAgo: 'gerade eben',
            content: '${title.isNotEmpty ? "$title\n\n" : ""}$content',
            imageUrl: imageUrl,
          ),
          const SizedBox(height: 12),
          const Center(
            child: CinemaProgress(value: 1.0, label: '4/4'),
          ),
        ],
      ),
    );
  }
}
