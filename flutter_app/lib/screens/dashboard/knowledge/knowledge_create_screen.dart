import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';

/// SKILL: mensaena-features
/// 1:1 zu Web `src/app/dashboard/wiki/create/page.tsx` + knowledge.
/// Eigenes Schema `knowledge_articles` (NICHT posts) mit:
/// title, slug, content, summary, category, tags, image_url, is_public,
/// status (draft/published/archived).
class KnowledgeCreateScreen extends ConsumerStatefulWidget {
  const KnowledgeCreateScreen({this.routePath = '/dashboard/knowledge', super.key});
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
  String _category = 'general';
  bool _isPublic = true;
  bool _saving = false;
  String? _error;

  static const _categories = [
    ('everyday', '📖 Alltag & Ratgeber'),
    ('skills', '🔧 Handwerk & Anleitung'),
    ('knowledge', '🧠 Wissen & Bildung'),
    ('housing', '⚖️ Wohnen & Recht'),
    ('mental', '💚 Gesundheit & Wohlbefinden'),
    ('emergency', '🚨 Notfall-Tipps'),
    ('sharing', '🌱 Nachhaltigkeit & Teilen'),
    ('food', '🍽️ Ernährung & Kochen'),
    ('mobility', '🚲 Mobilität & Unterwegs'),
    ('animals', '🐾 Tiere & Natur'),
    ('moving', '📦 Umzug & Neuanfang'),
    ('general', '💻 Digital & Sonstiges'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
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
    // Append timestamp to avoid collisions
    return '$slug-${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().length < 5) {
      setState(() => _error = 'Titel mind. 5 Zeichen.');
      return;
    }
    if (_contentCtrl.text.trim().length < 50) {
      setState(
          () => _error = 'Inhalt mind. 50 Zeichen — bitte detaillierter.');
      return;
    }
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final inserted = await sb
          .from('knowledge_articles')
          .insert({
            'author_id': uid,
            'title': _titleCtrl.text.trim(),
            'slug': _slugify(_titleCtrl.text.trim()),
            'content': _contentCtrl.text.trim(),
            'summary': _summaryCtrl.text.trim().isEmpty
                ? null
                : _summaryCtrl.text.trim(),
            'category': _category,
            'tags': tags,
            'is_public': _isPublic,
            'status': 'published',
            'published_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id, slug')
          .single();
      if (!mounted) return;
      context.go(widget.routePath);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          '✓ Artikel veröffentlicht: ${inserted['slug']}',
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Fehler: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Neuer Wissens-Artikel',
      currentRoute: widget.routePath,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const EditorialModuleHeader(
              metaIndex: '✦ Neu',
              metaCategory: 'WISSEN',
              title: 'Neuer Wissens-Artikel',
              subtitle:
                  'Teile dein Wissen mit der Community — Schritt-für-Schritt-Anleitung, Tipp oder Erklärung.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              maxLength: 200,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Titel*',
                counterText: '',
                hintText: 'Worüber willst du schreiben?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _summaryCtrl,
              maxLines: 2,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Kurzfassung (1–2 Sätze, optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Text('knowledge.category'.tr(), style: AppTypography.label(size: 10)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (val, label) in _categories)
                  ChoiceChip(
                    label: Text(label,
                        style: AppTypography.label(size: 10)),
                    selected: _category == val,
                    onSelected: (_) =>
                        setState(() => _category = val),
                    selectedColor:
                        AppColors.bronze.withValues(alpha: 0.3),
                    backgroundColor: AppColors.elevated,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _contentCtrl,
              maxLines: 16,
              minLines: 10,
              style: AppTypography.body(
                  size: 14, color: AppColors.ink, height: 1.55),
              decoration: const InputDecoration(
                labelText: 'Inhalt*',
                alignLabelWithHint: true,
                hintText:
                    'Schreibe deinen Artikel hier. Du kannst Markdown verwenden (**fett**, *kursiv*, # Überschriften, - Listen).',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsCtrl,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Tags (komma-getrennt)',
                hintText: 'z.B. einkaufen, wien, vegan',
              ),
            ),
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      AppColors.herzrot.withValues(alpha: 0.10),
                  border: Border.all(
                      color:
                          AppColors.herzrot.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.herzrotWarm)),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.bronze,
                foregroundColor: AppColors.voidColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.voidColor,
                      ),
                    )
                  : const Icon(LucideIcons.send, size: 16),
              label: Text('knowledge.publishArticle'.tr()),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
                side: const BorderSide(color: AppColors.line),
              ),
              onPressed: () => context.go(widget.routePath),
              child: Text('common.cancel'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
