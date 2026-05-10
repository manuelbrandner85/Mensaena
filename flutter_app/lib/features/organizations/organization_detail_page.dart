import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import 'models.dart';
import 'organizations_repository.dart';

class OrganizationDetailPage extends ConsumerStatefulWidget {
  const OrganizationDetailPage({super.key, required this.idOrSlug});
  final String idOrSlug;

  @override
  ConsumerState<OrganizationDetailPage> createState() =>
      _OrganizationDetailPageState();
}

class _OrganizationDetailPageState
    extends ConsumerState<OrganizationDetailPage> {
  Organization? _org;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final org = await ref
          .read(organizationsRepositoryProvider)
          .fetch(widget.idOrSlug);
      if (!mounted) return;
      if (org == null) {
        setState(() {
          _error = 'Nicht gefunden';
          _loading = false;
        });
        return;
      }
      setState(() {
        _org = org;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _launch(String uri) async {
    final url = Uri.parse(uri);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_org?.name ?? 'Organisation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(_org!),
    );
  }

  Widget _buildBody(Organization org) {
    final cat = org.categoryConfig;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image / logo header
          if (org.coverImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: org.coverImageUrl!,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const ColoredBox(color: Color(0xFFF5F5F4)),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: cat.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(cat.emoji, style: const TextStyle(fontSize: 48)),
            ),
          const SizedBox(height: 12),
          // Logo + name + category
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: cat.accentColor.withValues(alpha: 0.15),
                backgroundImage:
                    org.logoUrl != null ? NetworkImage(org.logoUrl!) : null,
                child: org.logoUrl == null
                    ? Text(cat.emoji, style: const TextStyle(fontSize: 24))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            org.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (org.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            size: 18,
                            color: AppColors.primary500,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.label,
                      style: TextStyle(
                        color: cat.accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (org.ratingCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${org.ratingAvg.toStringAsFixed(1)} · ${org.ratingCount} Bewertungen',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if ((org.shortDescription ?? '').isNotEmpty)
            Text(
              org.shortDescription!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          if ((org.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              org.description!,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
          const SizedBox(height: 20),
          _ContactCard(org: org, onLaunch: _launch),
          if (org.services.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ChipSection(title: 'Leistungen', items: org.services),
          ],
          if (org.targetGroups.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ChipSection(title: 'Zielgruppen', items: org.targetGroups),
          ],
          if (org.languages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ChipSection(title: 'Sprachen', items: org.languages),
          ],
          if (org.openingHoursText != null) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Öffnungszeiten'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                org.openingHoursText!,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.org, required this.onLaunch});
  final Organization org;
  final ValueChanged<String> onLaunch;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    final addressParts = <String>[];
    if (org.address != null && org.address!.isNotEmpty) {
      addressParts.add(org.address!);
    }
    if (org.zipCode != null) addressParts.add(org.zipCode!);
    addressParts.add(org.city);
    if (org.country.isNotEmpty && org.country != 'Österreich') {
      addressParts.add(org.country);
    }
    final fullAddress = addressParts.join(', ');
    if (fullAddress.isNotEmpty) {
      rows.add(
        _row(
          Icons.location_on_outlined,
          'Adresse',
          fullAddress,
          onTap: () => onLaunch(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(fullAddress)}',
          ),
        ),
      );
    }
    if (org.phone != null) {
      rows.add(
        _row(
          Icons.phone_outlined,
          'Telefon',
          org.phone!,
          onTap: () => onLaunch('tel:${org.phone}'),
        ),
      );
    }
    if (org.email != null) {
      rows.add(
        _row(
          Icons.mail_outline,
          'E-Mail',
          org.email!,
          onTap: () => onLaunch('mailto:${org.email}'),
        ),
      );
    }
    if (org.website != null) {
      rows.add(
        _row(
          Icons.language,
          'Website',
          org.website!,
          onTap: () => onLaunch(org.website!),
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(children: rows),
    );
  }

  Widget _row(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.ink400),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.ink400, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: onTap != null ? FontWeight.w600 : FontWeight.w400,
                color: onTap != null ? AppColors.primary500 : AppColors.ink700,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map(
                (s) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.ink400,
      ),
    );
  }
}
