import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// /dashboard/settings/emergency-contacts — Pendant zur Web-`EmergencyContacts.tsx`.
/// User pflegt eine Liste von Notfallkontakten (Name, Telefon, Beziehung).
/// Persistiert als JSONB-Array in `profiles.emergency_contacts`.
class EmergencyContactsPage extends ConsumerStatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  ConsumerState<EmergencyContactsPage> createState() =>
      _EmergencyContactsPageState();
}

const _kRelations = [
  'Partner/in',
  'Elternteil',
  'Kind',
  'Geschwister',
  'Freund/in',
  'Nachbar/in',
  'Sonstige',
];

class _EmergencyContactsPageState extends ConsumerState<EmergencyContactsPage> {
  List<_Contact> _contacts = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final row = await db
          .from('profiles')
          .select('emergency_contacts')
          .eq('id', user.id)
          .maybeSingle();
      final raw = row?['emergency_contacts'];
      final list = <_Contact>[];
      if (raw is List) {
        for (final c in raw) {
          if (c is Map<String, dynamic>) {
            list.add(_Contact.fromJson(c));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _contacts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _save(List<_Contact> next) async {
    setState(() => _saving = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      final json = next.map((c) => c.toJson()).toList();
      await db.from('profiles').update(<String, dynamic>{
        'emergency_contacts': json,
      }).eq('id', user.id);
      if (!mounted) return;
      setState(() => _contacts = next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addContact() async {
    final result = await showModalBottomSheet<_Contact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _AddContactSheet(),
    );
    if (result != null) {
      await _save([..._contacts, result]);
    }
  }

  Future<void> _removeContact(int index) async {
    final next = [..._contacts]..removeAt(index);
    await _save(next);
  }

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notfallkontakte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Kontakt hinzufügen',
            onPressed: _saving ? null : _addContact,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? _Empty(onAdd: _addContact)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = _contacts[i];
                    return Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEE2E2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.phone,
                                color: Color(0xFFB91C1C),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    c.relationship.isEmpty
                                        ? c.phone
                                        : '${c.phone} · ${c.relationship}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.ink400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone_outlined,
                                  color: AppColors.primary500),
                              tooltip: 'Anrufen',
                              onPressed: () => _dial(c.phone),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppColors.emergency500),
                              tooltip: 'Entfernen',
                              onPressed: _saving ? null : () => _removeContact(i),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _Contact {
  const _Contact({
    required this.name,
    required this.phone,
    required this.relationship,
  });

  final String name;
  final String phone;
  final String relationship;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };

  factory _Contact.fromJson(Map<String, dynamic> j) => _Contact(
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        relationship: j['relationship'] as String? ?? '',
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_outline,
                size: 48, color: AppColors.stone400),
            const SizedBox(height: 12),
            const Text(
              'Keine Notfallkontakte',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Wir können diese Personen kontaktieren, falls dir etwas zustößt.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.ink400),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Ersten Kontakt hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet();

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _relationship;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    Navigator.of(context).pop(_Contact(
      name: name,
      phone: phone,
      relationship: _relationship ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: SizedBox(
                width: 40,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.stone200,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Notfallkontakt hinzufügen',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'z. B. Anna Müller',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon *',
                hintText: '+43 660 …',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _relationship,
              decoration: const InputDecoration(labelText: 'Beziehung'),
              items: _kRelations
                  .map(
                    (r) => DropdownMenuItem(value: r, child: Text(r)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _relationship = v),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}

