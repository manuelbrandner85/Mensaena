/// SKILL: mensaena-features
/// E) KI-Wiki-Generator als wiederverwendbares Bottom-Sheet (nur Admin).
/// Genutzt in Wiki + Bildung (KnowledgeScreen) und im Admin-Dashboard.
/// Generiert einen Entwurf (ai-wiki-draft -> knowledge_articles status=draft)
/// und bietet "Direkt veröffentlichen" (status=published) ODER als Entwurf behalten.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/ai_features_repository.dart';
import '../../services/haptics.dart';
import '../../widgets/shared/app_snackbar.dart';

/// Öffnet den Generator. Liefert true, wenn ein Artikel erstellt/veröffentlicht
/// wurde (Aufrufer kann dann die Liste neu laden).
Future<bool> showAiWikiGenerator(BuildContext context) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AiWikiGeneratorSheet(),
  );
  return res ?? false;
}

class _AiWikiGeneratorSheet extends StatefulWidget {
  const _AiWikiGeneratorSheet();
  @override
  State<_AiWikiGeneratorSheet> createState() => _AiWikiGeneratorSheetState();
}

class _AiWikiGeneratorSheetState extends State<_AiWikiGeneratorSheet> {
  final _topicCtrl = TextEditingController();
  bool _loading = false;
  bool _publishing = false;
  Map<String, dynamic>? _draft;
  bool _created = false;

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty || _loading) return;
    Haptics.tap();
    setState(() {
      _loading = true;
      _draft = null;
    });
    Map<String, dynamic>? d;
    try {
      d = await AiFeaturesRepository()
          .wikiDraft(topic, context.locale.languageCode);
    } catch (_) {/* unten behandelt */}
    if (!mounted) return;
    setState(() {
      _loading = false;
      _draft = d;
      _created = d != null;
    });
    if (d == null) {
      AppSnackBar.error(context, 'assistant.error'.tr());
    }
  }

  Future<void> _publish() async {
    final id = _draft?['id']?.toString();
    if (id == null || id.isEmpty || _publishing) return;
    Haptics.tap();
    setState(() => _publishing = true);
    final ok = await AiFeaturesRepository().publishWikiArticle(id);
    if (!mounted) return;
    setState(() => _publishing = false);
    AppSnackBar.error(context, ok
            ? 'assistant.wiki_published'.tr()
            : 'assistant.error'.tr());
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 18, color: AppColors.bronze),
                  const SizedBox(width: 8),
                  Text('assistant.wiki_generator_title'.tr(),
                      style:
                          AppTypography.display(size: 17, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 10),
              Text('assistant.wiki_generator_hint'.tr(),
                  style: AppTypography.body(size: 12, color: AppColors.inkSoft)),
              const SizedBox(height: 12),
              TextField(
                controller: _topicCtrl,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'assistant.wiki_topic_label'.tr(),
                  filled: true,
                  fillColor: AppColors.elevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _generate(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.voidColor))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text('assistant.wiki_generate'.tr()),
              ),
              if (_draft != null) ...[
                const SizedBox(height: 16),
                Text((_draft!['title'] ?? '').toString(),
                    style: AppTypography.display(size: 16, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(
                  '${(_draft!['category'] ?? '').toString()} · '
                  '${(_draft!['tags'] as List?)?.join(', ') ?? ''}',
                  style: AppTypography.label(size: 10, color: AppColors.mute),
                ),
                const SizedBox(height: 10),
                Text((_draft!['content'] ?? '').toString(),
                    style: AppTypography.body(
                        size: 13, color: AppColors.inkSoft, height: 1.45)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, _created),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(
                              color: AppColors.line),
                          minimumSize: const Size(0, 46),
                        ),
                        child: Text('assistant.wiki_keep_draft'.tr()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _publishing ? null : _publish,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.leben,
                          foregroundColor: AppColors.voidColor,
                          minimumSize: const Size(0, 46),
                        ),
                        child: _publishing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.voidColor))
                            : Text('assistant.wiki_publish'.tr()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('assistant.wiki_saved_draft'.tr(),
                    style: AppTypography.label(size: 10, color: AppColors.mute)),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
