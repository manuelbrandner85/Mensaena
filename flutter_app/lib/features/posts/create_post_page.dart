import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import 'models.dart';
import 'posts_repository.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _tagsInput = TextEditingController();

  String _type = 'rescue';
  int _urgency = 1;
  bool _isAnonymous = false;
  bool _submitting = false;

  static const _typeOptions = [
    ('rescue', 'Hilfe / Retten', '🧡'),
    ('animal', 'Tierhilfe', '🐾'),
    ('housing', 'Wohnangebot', '🏡'),
    ('supply', 'Versorgung', '🌾'),
    ('mobility', 'Mobilität', '🚗'),
    ('sharing', 'Teilen / Skill', '🔄'),
    ('community', 'Community', '🗳️'),
    ('crisis', 'Notfall', '🚨'),
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _tagsInput.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      final tags = _tagsInput.text
          .split(RegExp(r'[\s,]+'))
          .map((t) => t.trim().replaceFirst(RegExp('^#'), ''))
          .where((t) => t.isNotEmpty)
          .toList();
      final id = await ref.read(postsRepositoryProvider).create(
            type: _type,
            title: _title.text.trim(),
            description: _description.text.trim(),
            locationText: _location.text.trim(),
            urgency: _urgency,
            tags: tags,
            isAnonymous: _isAnonymous,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post erstellt')),
      );
      context.go('${Routes.dashboardPosts}/$id');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Post erstellen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type
            const _Label('Was möchtest du posten?'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _typeOptions.map((t) {
                final selected = _type == t.$1;
                return ChoiceChip(
                  label: Text('${t.$3} ${t.$2}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t.$1),
                  selectedColor: PostTypeConfig.forType(t.$1).background,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Title
            const _Label('Titel'),
            TextFormField(
              controller: _title,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDeco(hint: 'Was brauchst du / bietest du?'),
              validator: (v) => (v ?? '').trim().length < 4 ? 'Bitte einen Titel angeben' : null,
            ),
            const SizedBox(height: 12),
            // Description
            const _Label('Beschreibung'),
            TextFormField(
              controller: _description,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDeco(hint: 'Details, Kontext, was wichtig ist…'),
            ),
            const SizedBox(height: 12),
            // Location
            const _Label('Ort (optional)'),
            TextFormField(
              controller: _location,
              decoration: _inputDeco(hint: 'z.B. Wien, Graz, 1010 Wien'),
            ),
            const SizedBox(height: 12),
            // Tags
            const _Label('Tags (optional, mit Komma getrennt)'),
            TextFormField(
              controller: _tagsInput,
              decoration: _inputDeco(hint: 'z.B. lebensmittel, transport, dringend'),
            ),
            const SizedBox(height: 20),
            // Urgency
            const _Label('Dringlichkeit'),
            Row(
              children: List.generate(5, (i) {
                final level = i + 1;
                final selected = _urgency == level;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _urgency = level),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary500.withValues(alpha: 0.15)
                            : Colors.white,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary500
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$level',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.primary500
                              : AppColors.ink400,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Anonymous
            SwitchListTile.adaptive(
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              title: const Text('Anonym posten'),
              subtitle: const Text(
                'Dein Name wird auf dem Post nicht angezeigt.',
                style: TextStyle(fontSize: 12, color: AppColors.ink400),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            // Submit
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Veröffentliche…' : 'Veröffentlichen'),
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

  InputDecoration _inputDeco({required String hint}) => InputDecoration(
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
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppColors.ink700,
        ),
      ),
    );
  }
}
