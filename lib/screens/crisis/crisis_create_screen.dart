import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/crisis_provider.dart';
import 'package:mensaena/models/crisis.dart';

class CrisisCreateScreen extends ConsumerStatefulWidget {
  const CrisisCreateScreen({super.key});
  @override ConsumerState<CrisisCreateScreen> createState() => _CrisisCreateScreenState();
}

class _CrisisCreateScreenState extends ConsumerState<CrisisCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _type = 'other';
  String _severity = 'medium';
  bool _loading = false;

  @override void dispose() { _titleCtrl.dispose(); _descCtrl.dispose(); _addressCtrl.dispose(); super.dispose(); }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(crisisServiceProvider).createCrisis({
        'reporter_id': userId, 'title': _titleCtrl.text.trim(), 'description': _descCtrl.text.trim(),
        'type': _type, 'severity': _severity, 'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null, 'status': 'active',
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Krisenmeldung erstellt'))); context.pop(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Krise melden'), backgroundColor: AppColors.emergencyLight),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Kategorie', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: CrisisCategory.values.map((cat) => FilterChip(
          label: Text('${cat.emoji} ${cat.label}'), selected: _type == cat.value, selectedColor: AppColors.emergencyLight,
          onSelected: (_) => setState(() => _type = cat.value))).toList()),
        const SizedBox(height: 16),
        TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Titel *')),
        const SizedBox(height: 16),
        TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Beschreibung'), maxLines: 4),
        const SizedBox(height: 16),
        TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Adresse / Ort', prefixIcon: Icon(Icons.location_on_outlined))),
        const SizedBox(height: 16),
        const Text('Dringlichkeit', style: TextStyle(fontWeight: FontWeight.w600)),
        RadioGroup<String>(
          groupValue: _severity,
          onChanged: (v) => setState(() => _severity = v ?? _severity),
          child: Column(children: CrisisUrgency.values.map((u) => RadioListTile<String>(
            title: Text(u.label), value: u.value, toggleable: false,
          )).toList()),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _create,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergency),
          child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Krise melden'))),
      ]),
    );
  }
}