import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/organization_provider.dart';

class OrganizationDetailScreen extends ConsumerWidget {
  final String orgId;
  const OrganizationDetailScreen({super.key, required this.orgId});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(organizationDetailProvider(orgId));
    return Scaffold(
      appBar: AppBar(title: const Text('Organisation')),
      body: org.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (o) {
          if (o == null) return const Center(child: Text('Nicht gefunden'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [Text(o.orgCategory.emoji, style: const TextStyle(fontSize: 32)), const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Text(o.orgCategory.label, style: const TextStyle(color: AppColors.textMuted)),
              ]))]),
            if (o.description != null) ...[const SizedBox(height: 16), Text(o.description!, style: const TextStyle(height: 1.5))],
            const SizedBox(height: 16), const Divider(),
            if (o.address != null) ListTile(leading: const Icon(Icons.location_on_outlined), title: Text(o.fullAddress), contentPadding: EdgeInsets.zero),
            if (o.phone != null) ListTile(leading: const Icon(Icons.phone_outlined), title: Text(o.phone!), contentPadding: EdgeInsets.zero,
              onTap: () => launchUrl(Uri.parse('tel:${o.phone}'))),
            if (o.email != null) ListTile(leading: const Icon(Icons.email_outlined), title: Text(o.email!), contentPadding: EdgeInsets.zero,
              onTap: () => launchUrl(Uri.parse('mailto:${o.email}'))),
            if (o.website != null) ListTile(leading: const Icon(Icons.language), title: Text(o.website!), contentPadding: EdgeInsets.zero,
              onTap: () => launchUrl(Uri.parse(o.website!))),
            if (o.services.isNotEmpty) ...[const SizedBox(height: 16), const Text('Angebote', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: o.services.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 12)), backgroundColor: AppColors.primary50, side: BorderSide.none)).toList())],
          ]);
        },
      ),
    );
  }
}