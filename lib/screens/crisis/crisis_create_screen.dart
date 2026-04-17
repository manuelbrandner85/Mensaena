import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/crisis_provider.dart';
import 'package:mensaena/models/crisis.dart';

class CrisisCreateScreen extends ConsumerStatefulWidget {
  const CrisisCreateScreen({super.key});
  @override
  ConsumerState<CrisisCreateScreen> createState() => _CrisisCreateScreenState();
}

class _CrisisCreateScreenState extends ConsumerState<CrisisCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  String _category = 'other';
  String _urgency = 'high';
  bool _isAnonymous = false;
  int _affectedCount = 0;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _contactNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(crisisServiceProvider).createCrisis({
        'creator_id': userId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'urgency': _urgency,
        'location_text': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
        'contact_phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        'contact_name': _contactNameCtrl.text.trim().isNotEmpty ? _contactNameCtrl.text.trim() : null,
        'is_anonymous': _isAnonymous,
        'affected_count': _affectedCount,
        'status': 'active',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Krisenmeldung erstellt'), backgroundColor: AppColors.success));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Krise melden'),
        backgroundColor: AppColors.emergencyLight,
        foregroundColor: AppColors.emergency,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emergencyLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emergency.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.emergency),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bitte nur echte Notfälle melden. Missbrauch kann zur Sperrung führen.',
                      style: TextStyle(fontSize: 12, color: AppColors.emergency),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Category
            const Text('Kategorie *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CrisisCategory.values.map((cat) {
                final selected = _category == cat.value;
                return FilterChip(
                  label: Text('${cat.emoji} ${cat.label}', style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  )),
                  selected: selected,
                  selectedColor: AppColors.emergency,
                  onSelected: (_) => setState(() => _category = cat.value),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Titel *',
                hintText: 'Kurze Beschreibung der Krise',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) => v == null || v.trim().length < 5 ? 'Mindestens 5 Zeichen' : null,
              maxLength: 200,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Beschreibung *',
                hintText: 'Was ist passiert? Welche Hilfe wird benötigt?',
                alignLabelWithHint: true,
              ),
              validator: (v) => v == null || v.trim().length < 10 ? 'Mindestens 10 Zeichen' : null,
              maxLines: 5,
              maxLength: 5000,
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Standort / Adresse',
                hintText: 'Wo ist die Krise?',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // Urgency
            const Text('Dringlichkeit *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            ...CrisisUrgency.values.map((u) {
              final selected = _urgency == u.value;
              final color = _getUrgencyColor(u);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => setState(() => _urgency = u.value),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.1) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? color : AppColors.border, width: selected ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Text(u.label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                        const Spacer(),
                        if (selected) Icon(Icons.check_circle, color: color, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Affected count
            Row(
              children: [
                const Text('Betroffene Personen:', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _affectedCount > 0 ? () => setState(() => _affectedCount--) : null,
                ),
                Text('$_affectedCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary500),
                  onPressed: () => setState(() => _affectedCount++),
                ),
              ],
            ),

            const Divider(height: 32),

            // Contact info
            const Text('Kontaktdaten (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Kontaktperson',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefonnummer',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Anonymous toggle
            SwitchListTile(
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              title: const Text('Anonym melden'),
              subtitle: const Text('Dein Name wird nicht angezeigt'),
              activeTrackColor: AppColors.primary500,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _create,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergency),
                icon: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.warning),
                label: Text(_loading ? 'Wird gemeldet...' : 'Krise melden'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Color _getUrgencyColor(CrisisUrgency u) {
    switch (u) {
      case CrisisUrgency.critical: return AppColors.emergency;
      case CrisisUrgency.high: return const Color(0xFFF97316);
      case CrisisUrgency.medium: return AppColors.warning;
      case CrisisUrgency.low: return AppColors.success;
    }
  }
}
