/// SKILL: mensaena-features
/// E) KI-Wiki-Generator (NUR Admin). Erzeugt einen Entwurf via ai-wiki-draft.
/// Der Entwurf wird serverseitig als knowledge_articles mit status='draft'
/// angelegt — Admin gibt ihn anschließend manuell frei (NICHT auto-veröffentlicht).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_features_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class AdminWikiGeneratorScreen extends ConsumerStatefulWidget {
  const AdminWikiGeneratorScreen({super.key});

  @override
  ConsumerState<AdminWikiGeneratorScreen> createState() =>
      _AdminWikiGeneratorScreenState();
}

class _AdminWikiGeneratorScreenState
    extends ConsumerState<AdminWikiGeneratorScreen> {
  final _topicCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _draft;

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty || _loading) return;
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
    });
    if (d == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('assistant.error'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'assistant.wiki_generator_title'.tr(),
      currentRoute: '/dashboard/admin/wiki-ai',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('assistant.wiki_generator_hint'.tr(),
                style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
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
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(
                      color: AppColors.bronze.withValues(alpha: 0.30)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 15, color: AppColors.leben),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('assistant.wiki_saved_draft'.tr(),
                              style: AppTypography.label(
                                  size: 10, color: AppColors.leben)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text((_draft!['title'] ?? '').toString(),
                        style: AppTypography.display(
                            size: 17, color: AppColors.ink)),
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
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
