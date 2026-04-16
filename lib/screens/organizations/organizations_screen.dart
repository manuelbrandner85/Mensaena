import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/organization_provider.dart';
import 'package:mensaena/models/organization.dart';
import 'package:mensaena/widgets/empty_state.dart';

class OrganizationsScreen extends ConsumerStatefulWidget {
  const OrganizationsScreen({super.key});
  @override ConsumerState<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends ConsumerState<OrganizationsScreen> {
  String? _category;
  String _search = '';

  @override Widget build(BuildContext context) {
    final orgs = ref.watch(organizationsProvider({'category': _category, 'search': _search.isNotEmpty ? _search : null, 'country': null}));
    return Scaffold(
      appBar: AppBar(title: const Text('🏢 Hilfsorganisationen')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          decoration: InputDecoration(hintText: 'Organisation suchen...', prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), filled: true, fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          onSubmitted: (v) => setState(() => _search = v),
        )),
        SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [null, ...OrganizationCategory.values.take(8)].map((cat) => Padding(padding: const EdgeInsets.only(right: 8),
            child: FilterChip(label: Text(cat?.label ?? 'Alle', style: const TextStyle(fontSize: 12)),
              selected: _category == cat?.value, selectedColor: AppColors.primary100,
              onSelected: (_) => setState(() => _category = cat?.value)))).toList())),
        const SizedBox(height: 8),
        Expanded(child: orgs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler: \$e')),
          data: (list) => list.isEmpty ? EmptyState(icon: Icons.business_outlined, title: 'Keine Organisationen') :
            ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: list.length,
              itemBuilder: (_, i) => _OrgCard(org: list[i], onTap: () => context.push('/dashboard/organizations/\${list[i].id}'))),
        )),
      ]),
    );
  }
}

class _OrgCard extends StatelessWidget {
  final Organization org; final VoidCallback onTap;
  const _OrgCard({required this.org, required this.onTap});
  @override Widget build(BuildContext context) {
    return Card(margin: const EdgeInsets.only(bottom: 10), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(org.orgCategory.emoji, style: const TextStyle(fontSize: 22)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(org.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (org.city != null) Text('\${org.countryFlag} \${org.city}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ])),
        if (org.isVerified) const Icon(Icons.verified, color: AppColors.primary500, size: 18),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ]))));
  }
}