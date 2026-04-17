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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Top accent line
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary500, AppColors.primary500.withValues(alpha: 0.2)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category icon
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary500.withValues(alpha: 0.1)),
                    ),
                    child: Center(child: Text(org.orgCategory.emoji, style: const TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(org.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 6),
                            if (org.isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.verified, color: AppColors.success, size: 14),
                              ),
                            const SizedBox(width: 4),
                            Text(org.countryFlag, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Category badge + city
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(6)),
                              child: Text(org.orgCategory.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.primary700)),
                            ),
                            if (org.city != null) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted.withValues(alpha: 0.7)),
                              const SizedBox(width: 2),
                              Expanded(child: Text('${org.city}${org.state != null ? ', ${org.state}' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ],
                        ),
                        // Services
                        if (org.services.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: org.services.take(3).map((s) => Text('• $s', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))).toList(),
                          ),
                        ],
                        // Opening hours
                        if (org.openingHours != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(org.openingHours.toString(), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          ]),
                        ],
                        // Contact quick info
                        if (org.phone != null || org.email != null || org.website != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (org.phone != null) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.phone_outlined, size: 13, color: AppColors.primary500)),
                              if (org.email != null) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.email_outlined, size: 13, color: AppColors.primary500)),
                              if (org.website != null) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.language_outlined, size: 13, color: AppColors.primary500)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}