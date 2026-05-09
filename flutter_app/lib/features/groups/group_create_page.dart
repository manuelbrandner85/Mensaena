import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// /dashboard/groups/create — Pendant zu src/app/dashboard/groups/create.
class GroupCreatePage extends ConsumerStatefulWidget {
  const GroupCreatePage({super.key});

  @override
  ConsumerState<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends ConsumerState<GroupCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();

  String _category = 'other';
  bool _isPrivate = false;
  bool _saving = false;

  static const _categories = [
    (value: 'neighborhood', emoji: '🏘️', label: 'Nachbarschaft'),
    (value: 'family', emoji: '👨‍👩‍👧', label: 'Familie'),
    (value: 'sport', emoji: '🏃', label: 'Sport'),
    (value: 'culture', emoji: '🎭', label: 'Kultur'),
    (value: 'food', emoji: '🍽️', label: 'Essen'),
    (value: 'environment', emoji: '🌱', label: 'Umwelt'),
    (value: 'support', emoji: '🤝', label: 'Hilfe'),
    (value: 'hobby', emoji: '🎨', label: 'Hobby'),
    (value: 'professional', emoji: '💼', label: 'Beruf'),
    (value: 'other', emoji: '📦', label: 'Sonstiges'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
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
      final name = _name.text.trim();
      final slug = '${_slugify(name)}-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      final row = await db.from('groups').insert(<String, dynamic>{
        'creator_id': user.id,
        'name': name,
        'slug': slug,
        'category': _category,
        if (_description.text.trim().isNotEmpty)
          'description': _description.text.trim(),
        'is_private': _isPrivate,
      }).select('id').single();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gruppe erstellt')),
      );
      context.go('/dashboard/groups/${row['id']}');
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
      appBar: AppBar(title: const Text('Gruppe erstellen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Label('Name *'),
            TextFormField(
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('z. B. Nachbarschaftshilfe Wien 1010'),
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'Min. 3 Zeichen' : null,
            ),
            const SizedBox(height: 12),
            const _Label('Beschreibung'),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('Worum geht es in dieser Gruppe?'),
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
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
              title: const Text(
                'Private Gruppe',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Nur per Einladung sichtbar',
                style: TextStyle(color: AppColors.ink400, fontSize: 12),
              ),
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
                    : const Icon(Icons.group_add),
                label:
                    Text(_saving ? 'Erstelle…' : 'Gruppe gründen'),
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
