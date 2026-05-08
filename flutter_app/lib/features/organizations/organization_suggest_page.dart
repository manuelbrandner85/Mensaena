import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import 'models.dart';
import 'organizations_repository.dart';

class OrganizationSuggestPage extends ConsumerStatefulWidget {
  const OrganizationSuggestPage({super.key});

  @override
  ConsumerState<OrganizationSuggestPage> createState() =>
      _OrganizationSuggestPageState();
}

class _OrganizationSuggestPageState
    extends ConsumerState<OrganizationSuggestPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _zip = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _description = TextEditingController();
  final _sourceUrl = TextEditingController();

  String _category = 'allgemein';
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _address.dispose();
    _zip.dispose();
    _phone.dispose();
    _email.dispose();
    _website.dispose();
    _description.dispose();
    _sourceUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(organizationsRepositoryProvider).suggest(
            name: _name.text.trim(),
            city: _city.text.trim(),
            category: _category,
            address: _address.text.trim(),
            zipCode: _zip.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            website: _website.text.trim(),
            description: _description.text.trim(),
            sourceUrl: _sourceUrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vorschlag eingereicht – wird geprüft.'),
        ),
      );
      context.pop();
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
      appBar: AppBar(title: const Text('Organisation vorschlagen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Label('Kategorie'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: OrganizationCategory.all
                  .map(
                    (c) => ChoiceChip(
                      label: Text('${c.emoji} ${c.label}'),
                      selected: _category == c.value,
                      onSelected: (_) => setState(() => _category = c.value),
                      selectedColor: c.accentColor.withValues(alpha: 0.15),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const _Label('Name *'),
            TextFormField(
              controller: _name,
              decoration: _deco(hint: 'Name der Organisation'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().length < 3 ? 'Bitte Name angeben' : null,
            ),
            const SizedBox(height: 12),
            const _Label('Stadt *'),
            TextFormField(
              controller: _city,
              decoration: _deco(hint: 'z. B. Wien'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Bitte Stadt angeben' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Adresse'),
                      TextFormField(
                        controller: _address,
                        decoration: _deco(hint: 'Straße + Nr.'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('PLZ'),
                      TextFormField(
                        controller: _zip,
                        keyboardType: TextInputType.number,
                        decoration: _deco(hint: '1010'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _Label('Telefon'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _deco(hint: '+43 …'),
            ),
            const SizedBox(height: 12),
            const _Label('E-Mail'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _deco(hint: 'kontakt@…'),
            ),
            const SizedBox(height: 12),
            const _Label('Website'),
            TextFormField(
              controller: _website,
              keyboardType: TextInputType.url,
              decoration: _deco(hint: 'https://…'),
            ),
            const SizedBox(height: 12),
            const _Label('Beschreibung'),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 1000,
              decoration: _deco(hint: 'Was tut die Organisation?'),
            ),
            const SizedBox(height: 12),
            const _Label('Quelle (URL, optional)'),
            TextFormField(
              controller: _sourceUrl,
              decoration: _deco(hint: 'Wo hast du die Daten her?'),
            ),
            const SizedBox(height: 24),
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
                label: Text(_submitting ? 'Sende…' : 'Vorschlag einreichen'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dein Vorschlag wird vom Mensaena-Team geprüft. Sobald freigegeben, '
              'erscheint die Organisation in der Liste.',
              style: TextStyle(color: AppColors.ink400, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco({required String hint}) => InputDecoration(
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
      padding: const EdgeInsets.only(bottom: 6),
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
