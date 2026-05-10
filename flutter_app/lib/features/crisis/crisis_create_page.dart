import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import 'crisis_repository.dart';
import 'models.dart';

class CrisisCreatePage extends ConsumerStatefulWidget {
  const CrisisCreatePage({super.key, this.editId});

  /// Wenn gesetzt: Page läuft im Edit-Mode, lädt die bestehende Krise und
  /// schreibt Änderungen via updateCrisis() statt Insert.
  final String? editId;

  @override
  ConsumerState<CrisisCreatePage> createState() => _CrisisCreatePageState();
}

class _CrisisCreatePageState extends ConsumerState<CrisisCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();

  String _category = 'medical';
  CrisisUrgency _urgency = CrisisUrgency.high;
  double _radiusKm = 5;
  int _affectedCount = 1;
  int _neededHelpers = 1;
  bool _isAnonymous = false;
  bool _submitting = false;
  bool _loadingExisting = false;

  bool get _isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    try {
      final crisis = await ref
          .read(crisisRepositoryProvider)
          .fetch(widget.editId!);
      if (!mounted || crisis == null) return;
      setState(() {
        _title.text = crisis.title;
        _description.text = crisis.description;
        _location.text = crisis.locationText ?? '';
        _phone.text = crisis.contactPhone ?? '';
        _category = crisis.category;
        _urgency = crisis.urgency;
        _radiusKm = crisis.radiusKm;
        _affectedCount = crisis.affectedCount;
        _neededHelpers = crisis.neededHelpers;
        _isAnonymous = crisis.isAnonymous;
        _loadingExisting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingExisting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Krise konnte nicht geladen werden: $e')),
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      final repo = ref.read(crisisRepositoryProvider);
      final String resultId;
      if (_isEdit) {
        await repo.updateCrisis(
          crisisId: widget.editId!,
          title: _title.text.trim(),
          description: _description.text.trim(),
          category: _category,
          urgency: _urgency,
          locationText: _location.text.trim(),
          radiusKm: _radiusKm,
          affectedCount: _affectedCount,
          neededHelpers: _neededHelpers,
          contactPhone: _phone.text.trim(),
          isAnonymous: _isAnonymous,
        );
        resultId = widget.editId!;
      } else {
        resultId = await repo.create(
          title: _title.text.trim(),
          description: _description.text.trim(),
          category: _category,
          urgency: _urgency,
          locationText: _location.text.trim(),
          radiusKm: _radiusKm,
          affectedCount: _affectedCount,
          neededHelpers: _neededHelpers,
          contactPhone: _phone.text.trim(),
          isAnonymous: _isAnonymous,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Änderungen gespeichert'
                : 'Krisenbericht veröffentlicht',
          ),
        ),
      );
      context.go('${Routes.dashboardCrisis}/$resultId');
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
      appBar: AppBar(
        title: Text(_isEdit ? 'Krise bearbeiten' : 'Krise melden'),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isEdit) const _Banner(),
            const SizedBox(height: 16),
            const _Label('Kategorie *'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: CrisisCategory.all.map((c) {
                final selected = _category == c.value;
                return ChoiceChip(
                  label: Text('${c.emoji} ${c.label}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c.value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const _Label('Dringlichkeit *'),
            Row(
              children: CrisisUrgency.values.map((u) {
                final selected = _urgency == u;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _urgency = u),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? u.color.withValues(alpha: 0.15)
                            : Colors.white,
                        border: Border.all(
                          color: selected ? u.color : Colors.grey.shade300,
                          width: selected ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        u.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: selected ? u.color : AppColors.ink400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const _Label('Titel *'),
            TextFormField(
              controller: _title,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('z. B. Person verletzt nach Verkehrsunfall'),
              validator: (v) => (v ?? '').trim().length < 4 ? 'Bitte einen Titel angeben' : null,
            ),
            const SizedBox(height: 12),
            const _Label('Beschreibung *'),
            TextFormField(
              controller: _description,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('Was ist passiert? Wer ist betroffen? Was wird gebraucht?'),
              validator: (v) => (v ?? '').trim().length < 10 ? 'Bitte mehr Details angeben' : null,
            ),
            const SizedBox(height: 12),
            const _Label('Ort'),
            TextFormField(
              controller: _location,
              decoration: _deco('Adresse oder Beschreibung'),
            ),
            const SizedBox(height: 12),
            const _Label('Notfall-Telefon (optional)'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _deco('+43 …'),
            ),
            const SizedBox(height: 16),
            _NumberRow(
              label: 'Radius (km)',
              value: _radiusKm.toInt(),
              onChange: (v) => setState(() => _radiusKm = v.toDouble()),
              min: 1,
              max: 50,
            ),
            _NumberRow(
              label: 'Betroffene Personen',
              value: _affectedCount,
              onChange: (v) => setState(() => _affectedCount = v),
              min: 1,
              max: 200,
            ),
            _NumberRow(
              label: 'Benötigte Helfer',
              value: _neededHelpers,
              onChange: (v) => setState(() => _neededHelpers = v),
              min: 1,
              max: 50,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              title: const Text('Anonym melden'),
              subtitle: const Text(
                'Dein Name wird auf dem Bericht nicht angezeigt.',
                style: TextStyle(fontSize: 12, color: AppColors.ink400),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
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
                    : const Icon(Icons.warning_amber_rounded),
                label: Text(
                  _submitting
                      ? (_isEdit ? 'Speichere…' : 'Veröffentliche…')
                      : (_isEdit ? 'Änderungen speichern' : 'Veröffentlichen'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
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
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12, height: 1.4),
                children: [
                  TextSpan(
                    text: 'Bei akutem Notfall: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: 'Rufe 112 (EU-Notruf) bzw. die örtliche Rettung. '),
                  TextSpan(text: 'Ein Krisenbericht hier ersetzt keinen Notruf.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.onChange,
    required this.min,
    required this.max,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChange;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChange(value - 1) : null,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChange(value + 1) : null,
          ),
        ],
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
          color: AppColors.ink700,
        ),
      ),
    );
  }
}
