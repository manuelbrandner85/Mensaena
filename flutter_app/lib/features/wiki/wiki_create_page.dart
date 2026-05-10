import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// /dashboard/wiki/create — Pendant zu src/app/dashboard/wiki/create.
class WikiCreatePage extends ConsumerStatefulWidget {
  const WikiCreatePage({super.key});

  @override
  ConsumerState<WikiCreatePage> createState() => _WikiCreatePageState();
}

class _WikiCreatePageState extends ConsumerState<WikiCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _summary = TextEditingController();
  final _tags = TextEditingController();

  String _category = 'guide';
  bool _saving = false;

  static const _categories = [
    (value: 'guide', emoji: '📘', label: 'Anleitung'),
    (value: 'recipe', emoji: '🍲', label: 'Rezept'),
    (value: 'tutorial', emoji: '🎓', label: 'Tutorial'),
    (value: 'tip', emoji: '💡', label: 'Tipp'),
    (value: 'glossary', emoji: '📖', label: 'Glossar'),
    (value: 'other', emoji: '📦', label: 'Sonstiges'),
  ];

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _summary.dispose();
    _tags.dispose();
    super.dispose();
  }

  String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[äÄ]'), 'ae')
        .replaceAll(RegExp(r'[öÖ]'), 'oe')
        .replaceAll(RegExp(r'[üÜ]'), 'ue')
        .replaceAll(RegExp(r'[ßẞ]'), 'ss')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) throw Exception('Nicht eingeloggt');
      final title = _title.text.trim();
      final tags = _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final slug = '${_slugify(title)}-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      final row = await db.from('knowledge_articles').insert(<String, dynamic>{
        'author_id': user.id,
        'title': title,
        'slug': slug,
        'content': _content.text.trim(),
        'category': _category,
        if (_summary.text.trim().isNotEmpty)
          'summary': _summary.text.trim(),
        if (tags.isNotEmpty) 'tags': tags,
        'is_public': true,
        'status': 'published',
        'published_at': DateTime.now().toIso8601String(),
      }).select('id').single();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wiki-Eintrag veröffentlicht')),
      );
      context.go('/dashboard/wiki/${row['id']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Wiki-Eintrag erstellen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Label('Titel *'),
            TextFormField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('Was möchtest du teilen?'),
              validator: (v) =>
                  (v ?? '').trim().length < 5 ? 'Min. 5 Zeichen' : null,
            ),
            const SizedBox(height: 12),
            const _Label('Kurzbeschreibung'),
            TextFormField(
              controller: _summary,
              maxLength: 200,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('1-2 Sätze worum es geht'),
            ),
            const SizedBox(height: 12),
            const _Label('Inhalt *  (Markdown unterstützt)'),
            _MarkdownToolbar(controller: _content),
            TextFormField(
              controller: _content,
              maxLines: 14,
              minLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco(
                '## Überschrift\n\nDein Text in **Markdown**.\n\n- Liste\n- ...',
              ),
              validator: (v) =>
                  (v ?? '').trim().length < 20 ? 'Min. 20 Zeichen' : null,
            ),
            const SizedBox(height: 12),
            const _Label('Kategorie *'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories
                  .map(
                    (c) => ChoiceChip(
                      label: Text('${c.emoji} ${c.label}'),
                      selected: _category == c.value,
                      onSelected: (_) =>
                          setState(() => _category = c.value),
                      selectedColor:
                          AppColors.primary500.withValues(alpha: 0.15),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            const _Label('Tags (mit Komma getrennt)'),
            TextFormField(
              controller: _tags,
              decoration: _deco('z. B. garten, frühling, biologisch'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.menu_book_outlined),
                label: Text(
                    _saving ? 'Veröffentliche…' : 'Veröffentlichen'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primary500,
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

/// Mini-Markdown-Toolbar — Buttons fügen Markdown-Snippets in den Editor ein
/// und positionieren den Cursor sinnvoll. Pendant zur Web-`ArticleEditor`-
/// Toolbar (Bold/Italic/H2/H3/Liste/Code/Link).
class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({required this.controller});
  final TextEditingController controller;

  void _wrap(String left, String right) {
    final sel = controller.selection;
    final text = controller.text;
    if (!sel.isValid) {
      controller.text = '$text$left$right';
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length - right.length,
      );
      return;
    }
    final selected = sel.textInside(text);
    final replaced = '$left$selected$right';
    final newText = sel.textBefore(text) + replaced + sel.textAfter(text);
    final newCursor = sel.start + left.length + selected.length;
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursor);
  }

  void _prefixLine(String prefix) {
    final sel = controller.selection;
    final text = controller.text;
    final start = sel.isValid ? sel.start : text.length;
    // Find start of current line
    var lineStart = start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    final newText = text.substring(0, lineStart) +
        prefix +
        text.substring(lineStart);
    controller.text = newText;
    controller.selection =
        TextSelection.collapsed(offset: start + prefix.length);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _btn(Icons.format_bold, 'Bold', () => _wrap('**', '**')),
            _btn(
              Icons.format_italic,
              'Italic',
              () => _wrap('*', '*'),
            ),
            _btn(
              Icons.title,
              'Überschrift',
              () => _prefixLine('## '),
            ),
            _btn(
              Icons.format_list_bulleted,
              'Liste',
              () => _prefixLine('- '),
            ),
            _btn(
              Icons.format_quote,
              'Zitat',
              () => _prefixLine('> '),
            ),
            _btn(
              Icons.code,
              'Code',
              () => _wrap('`', '`'),
            ),
            _btn(
              Icons.link,
              'Link',
              () => _wrap('[', '](https://)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String tip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: AppColors.stone100,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: tip,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Icon(icon, size: 18, color: AppColors.ink700),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppColors.ink400,
        ),
      ),
    );
  }
}
