import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class OrganizationSuggestScreen extends ConsumerStatefulWidget {
  const OrganizationSuggestScreen({super.key});

  @override
  ConsumerState<OrganizationSuggestScreen> createState() =>
      _OrganizationSuggestScreenState();
}

class _OrganizationSuggestScreenState
    extends ConsumerState<OrganizationSuggestScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  String _category = 'verein';
  bool _submitting = false;
  String? _info;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Org. vorschlagen',
      currentRoute: '/dashboard/organizations',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Vorschlag geht an Admins zur Prüfung — nach Freigabe '
              'erscheint die Organisation im Verzeichnis.',
              style: AppTypography.caption(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              dropdownColor: AppColors.surface,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              items: const [
                'verein',
                'sozial',
                'umwelt',
                'kultur',
                'bildung',
                'sport',
                'religion',
                'sonstiges',
              ]
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _city,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Stadt'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _address,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Adresse'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 3,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Telefon'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'E-Mail'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _website,
              keyboardType: TextInputType.url,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Webseite'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.herzrotWarm,
                ),
              ),
            ],
            if (_info != null) ...[
              const SizedBox(height: 10),
              Text(
                _info!,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.lebenSoft,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _submitting
                  ? null
                  : () async {
                      if (_name.text.trim().isEmpty ||
                          _city.text.trim().isEmpty) {
                        setState(() =>
                            _error = 'Name und Stadt sind Pflicht.');
                        return;
                      }
                      setState(() {
                        _submitting = true;
                        _error = null;
                      });
                      final ok = await OrganizationsRepository.suggest(
                        name: _name.text.trim(),
                        category: _category,
                        city: _city.text.trim(),
                        description: _desc.text.trim().isEmpty
                            ? null
                            : _desc.text.trim(),
                        address: _address.text.trim().isEmpty
                            ? null
                            : _address.text.trim(),
                        phone: _phone.text.trim().isEmpty
                            ? null
                            : _phone.text.trim(),
                        email: _email.text.trim().isEmpty
                            ? null
                            : _email.text.trim(),
                        website: _website.text.trim().isEmpty
                            ? null
                            : _website.text.trim(),
                      );
                      if (!mounted) return;
                      setState(() {
                        _submitting = false;
                        _info = ok
                            ? 'Vorschlag eingereicht. Danke!'
                            : null;
                        _error = ok
                            ? null
                            : 'Konnte Vorschlag nicht speichern.';
                      });
                    },
              icon: const Icon(LucideIcons.send, size: 16),
              label: Text(_submitting ? 'Sende…' : 'Vorschlag einreichen'),
            ),
          ],
        ),
      ),
    );
  }
}
