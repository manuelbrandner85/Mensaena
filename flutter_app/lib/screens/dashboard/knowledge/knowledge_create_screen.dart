import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/knowledge_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/tag_suggestion_field.dart';
import '../../../widgets/shared/readable_width.dart';

/// SKILL: mensaena-features
/// Knowledge-Create-Screen — Markdown-Editor mit Live-Vorschau,
/// Cover-Bild, Tags, Kategorie, Sichtbarkeit, Featured-Toggle.
/// Insert in `knowledge_articles` mit auto-generated slug.
class KnowledgeCreateScreen extends ConsumerStatefulWidget {
  const KnowledgeCreateScreen({
    this.routePath = '/dashboard/knowledge',
    super.key,
  });
  final String routePath;

  @override
  ConsumerState<KnowledgeCreateScreen> createState() =>
      _KnowledgeCreateScreenState();
}

class _KnowledgeCreateScreenState
    extends ConsumerState<KnowledgeCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _category = 'general';
  bool _isPublic = true;
  bool _isFeatured = false;
  bool _livePreview = false;
  File? _coverImage;
  String? _uploadedImageUrl;
  bool _submitting = false;
  String? _error;

  static final List<({String value, IconData icon, String label})>
      _categories = [
    (value: 'everyday', icon: LucideIcons.bookOpen, label: '📖 Alltag'),
    (value: 'skills', icon: LucideIcons.wrench, label: '🔧 Handwerk'),
    (value: 'knowledge', icon: LucideIcons.brain, label: '🧠 Wissen'),
    (value: 'housing', icon: LucideIcons.home, label: '⚖️ Wohnen'),
    (value: 'mental', icon: LucideIcons.heart, label: '💚 Gesundheit'),
    (value: 'emergency', icon: LucideIcons.alertTriangle, label: '🚨 Notfall'),
    (value: 'sharing', icon: LucideIcons.leaf, label: '🌱 Teilen'),
    (value: 'food', icon: LucideIcons.utensils, label: '🍽️ Kochen'),
    (value: 'mobility', icon: LucideIcons.bike, label: '🚲 Mobilität'),
    (value: 'animals', icon: LucideIcons.dog, label: '🐾 Tiere'),
    (value: 'moving', icon: LucideIcons.package, label: '📦 Umzug'),
    (value: 'general', icon: LucideIcons.laptop, label: '💻 Digital'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // ── Cover Image Picker ────────────────────────────────────────
  Future<void> _pickCover() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
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
      // ignorieren
    }
  }

  // ── Category Picker (BottomSheet Grid) ────────────────────────
  Future<void> _pickCategory() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'knowledge.category'.tr(),
                style: AppTypography.display(size: 18, color: AppColors.ink),
              ),
              const SizedBox(height: 14),
              GridView.extent(
                maxCrossAxisExtent: 130,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.0,
                children: [
                  for (final c in _categories)
                    InkWell(
                      onTap: () => Navigator.pop(ctx, c.value),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _category == c.value
                              ? AppColors.bronze.withValues(alpha: 0.22)
                              : AppColors.elevated,
                          border: Border.all(
                            color: _category == c.value
                                ? AppColors.bronze
                                : AppColors.line,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              c.icon,
                              size: 22,
                              color: _category == c.value
                                  ? AppColors.bronze
                                  : AppColors.bronzeSoft,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                size: 10,
                                color: AppColors.ink,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _category = selected);
    }
  }

  String _currentCategoryLabel() {
    for (final c in _categories) {
      if (c.value == _category) return c.label;
    }
    return _category;
  }

  String _slugify(String s) {
    var slug = s
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    if (slug.length > 80) slug = slug.substring(0, 80);
    return '$slug-${DateTime.now().millisecondsSinceEpoch}';
  }

  // ── Submit ────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_titleCtrl.text.trim().length < 5) {
      setState(() => _error = 'knowledge.validationTitle'.tr());
      return;
    }
    if (_contentCtrl.text.trim().length < 50) {
      setState(() => _error = 'knowledge.validationContent'.tr());
      return;
    }
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      String? imageUrl = _uploadedImageUrl;
      var coverFailed = false;
      if (_coverImage != null && imageUrl == null) {
        final bytes = await _coverImage!.readAsBytes();
        final ext = _coverImage!.path.split('.').last.toLowerCase();
        imageUrl = await KnowledgeRepository.uploadImage(
          bytes: bytes,
          userId: uid,
          fileExt: ext.isEmpty ? 'jpg' : ext,
        );
        _uploadedImageUrl = imageUrl;
        // Cover war gewählt, Upload schlug fehl → vorher still ignoriert
        // (Artikel ohne Bild, kein Hinweis). Titelbild ist optional, daher
        // veröffentlichen wir trotzdem, warnen aber danach.
        coverFailed = imageUrl == null;
      }

      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await sb.from('knowledge_articles').insert({
        'author_id': uid,
        'title': _titleCtrl.text.trim(),
        'slug': _slugify(_titleCtrl.text.trim()),
        'content': _contentCtrl.text.trim(),
        'summary': _summaryCtrl.text.trim().isEmpty
            ? null
            : _summaryCtrl.text.trim(),
        'category': _category,
        'tags': tags,
        if (imageUrl != null) 'image_url': imageUrl,
        'is_public': _isPublic,
        'is_featured': _isFeatured,
        'status': 'published',
        'published_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          coverFailed
              ? 'knowledge.publishedNoCover'.tr()
              : 'knowledge.publishArticle'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
      context.go(widget.routePath);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'knowledge.publishFailed'.tr();
      });
    }
  }

  // ── Markdown Preview Styles ───────────────────────────────────
  MarkdownStyleSheet _markdownStyles(BuildContext context) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: AppTypography.body(
          size: 14, color: AppColors.inkSoft, height: 1.65),
      h1: AppTypography.display(
          size: 20, color: AppColors.ink, weight: FontWeight.w800),
      h2: AppTypography.display(
          size: 17, color: AppColors.ink, weight: FontWeight.w700),
      h3: AppTypography.body(
          size: 15, color: AppColors.ink, weight: FontWeight.w700),
      strong: AppTypography.body(
          size: 14, color: AppColors.ink, weight: FontWeight.w700),
      em: AppTypography.body(size: 14, color: AppColors.inkSoft)
          .copyWith(fontStyle: FontStyle.italic),
      listBullet: AppTypography.body(size: 14, color: AppColors.bronze),
      code: AppTypography.mono(size: 12, color: AppColors.amber),
      codeblockDecoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      blockquote: AppTypography.body(size: 14, color: AppColors.inkSoft)
          .copyWith(fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.05),
        border: const Border(
          left: BorderSide(color: AppColors.amber, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      a: AppTypography.body(size: 14, color: AppColors.teal)
          .copyWith(decoration: TextDecoration.underline),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'knowledge.createArticle'.tr(),
      currentRoute: widget.routePath,
      body: SafeArea(
        child: ReadableWidth(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            EditorialModuleHeader(
              metaIndex: '✦ Neu',
              metaCategory: 'WISSEN',
              title: 'knowledge.createArticle'.tr(),
              subtitle:
                  'Teile dein Wissen mit der Community — Schritt-fuer-Schritt-Anleitung, Tipp oder Erklaerung.',
            ),
            const SizedBox(height: 12),

            // 1) Cover-Image
            _sectionLabel('knowledge.coverImage'.tr()),
            const SizedBox(height: 6),
            _CoverPickerBox(
              file: _coverImage,
              onTap: _pickCover,
              onRemove: () => setState(() {
                _coverImage = null;
                _uploadedImageUrl = null;
              }),
            ),
            const SizedBox(height: 16),

            // 2) Titel
            _sectionLabel('knowledge.titleField'.tr()),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              maxLength: 200,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              decoration: const InputDecoration(
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),

            // 3) Summary
            _sectionLabel('knowledge.summary'.tr()),
            const SizedBox(height: 6),
            TextField(
              controller: _summaryCtrl,
              maxLines: 2,
              maxLength: 200,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),

            // 4) Kategorie-Picker
            _sectionLabel('knowledge.category'.tr()),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickCategory,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _currentCategoryLabel(),
                        style: AppTypography.body(
                            size: 14, color: AppColors.ink),
                      ),
                    ),
                    const Icon(LucideIcons.chevronDown,
                        size: 16, color: AppColors.mute),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 5) Tags
            _sectionLabel('knowledge.tags'.tr()),
            const SizedBox(height: 6),
            TagSuggestionField(
              controller: _tagsCtrl,
              suggestions: const [
                'anleitung',
                'tipp',
                'wissen',
                'gesundheit',
                'garten',
                'reparatur',
                'recht',
                'finanzen',
              ],
            ),
            const SizedBox(height: 14),

            // 6) Content (Markdown)
            _sectionLabel('knowledge.content'.tr()),
            const SizedBox(height: 6),
            TextField(
              controller: _contentCtrl,
              maxLines: 18,
              minLines: 10,
              style: AppTypography.mono(
                size: 13,
                color: AppColors.ink,
              ),
              onChanged: (_) {
                if (_livePreview) setState(() {});
              },
              decoration: InputDecoration(
                alignLabelWithHint: true,
                hintText: 'knowledge.markdownHint'.tr(),
                hintStyle: AppTypography.body(
                  size: 12,
                  color: AppColors.mute,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 7) Live-Preview-Toggle
            SwitchListTile(
              value: _livePreview,
              onChanged: (v) => setState(() => _livePreview = v),
              activeColor: AppColors.amber,
              contentPadding: EdgeInsets.zero,
              title: Text('knowledge.livePreview'.tr(),
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.inkSoft,
                    weight: FontWeight.w600,
                  )),
            ),
            if (_livePreview && _contentCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.5),
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: MarkdownBody(
                  data: _contentCtrl.text,
                  styleSheet: _markdownStyles(context),
                ),
              ),
            ],
            const SizedBox(height: 8),

            // 8) Sichtbarkeit
            SwitchListTile(
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              activeColor: AppColors.bronze,
              contentPadding: EdgeInsets.zero,
              title: Text('knowledge.publicVisible'.tr(),
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.inkSoft,
                    weight: FontWeight.w600,
                  )),
              subtitle: Text(
                  'Auch für nicht eingeloggte Besucher sichtbar.',
                  style: AppTypography.caption()),
            ),

            // 9) Featured
            SwitchListTile(
              value: _isFeatured,
              onChanged: (v) => setState(() => _isFeatured = v),
              activeColor: AppColors.amber,
              contentPadding: EdgeInsets.zero,
              title: Text('knowledge.featuredToggle'.tr(),
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.inkSoft,
                    weight: FontWeight.w600,
                  )),
              secondary: const Icon(LucideIcons.star,
                  color: AppColors.amber, size: 18),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.herzrot.withValues(alpha: 0.10),
                  border: Border.all(
                      color: AppColors.herzrot.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: AppTypography.body(
                        size: 13, color: AppColors.herzrotWarm)),
              ),
            ],

            const SizedBox(height: 20),

            // 10) Submit
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.voidColor,
                minimumSize: const Size(double.infinity, 60),
              ),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.voidColor,
                      ),
                    )
                  : const Icon(LucideIcons.send, size: 16),
              label: Text(
                'knowledge.publish'.tr(),
                style: AppTypography.body(
                    size: 14,
                    color: AppColors.voidColor,
                    weight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
                side: const BorderSide(color: AppColors.line),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () => context.go(widget.routePath),
              child: Text('common.cancel'.tr()),
            ),
          ],
        )),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTypography.label(size: 10, color: AppColors.bronzeSoft),
      );
}

// ── Cover Picker Box ──────────────────────────────────────────────
class _CoverPickerBox extends StatelessWidget {
  const _CoverPickerBox({
    required this.file,
    required this.onTap,
    required this.onRemove,
  });
  final File? file;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.elevated,
            border: Border.all(
              color: AppColors.line,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.imagePlus,
                  color: AppColors.bronze, size: 28),
              const SizedBox(height: 8),
              Text(
                'knowledge.coverImage'.tr(),
                style: AppTypography.body(
                    size: 13,
                    color: AppColors.inkSoft,
                    weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheWidth: 800,
            cacheHeight: 400,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black.withValues(alpha: 0.6),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(LucideIcons.x, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
