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
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (list) => list.isEmpty ? EmptyState(icon: Icons.business_outlined, title: 'Keine Organisationen') :
            ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: list.length,
              itemBuilder: (_, i) => _OrgCard(org: list[i], onTap: () => context.push('/dashboard/organizations/${list[i].id}'))),
        )),
      ]),
    );
  }
}

class _OrgCard extends StatelessWidget {
  final Organization org;
  final VoidCallback onTap;
  const _OrgCard({required this.org, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(org.orgCategory.emoji, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(org.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (org.isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified, color: AppColors.primary500, size: 16)],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(org.countryFlag, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        if (org.city != null) Text(org.city!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const Spacer(),
                        if (org.averageRating != null && org.averageRating! > 0) ...[
                          const Icon(Icons.star, size: 14, color: AppColors.warning),
                          const SizedBox(width: 2),
                          Text(org.averageRating!.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          if (org.reviewCount != null) Text(' (${org.reviewCount})', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                    if (org.services.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(org.services.take(3).join(' · '), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}