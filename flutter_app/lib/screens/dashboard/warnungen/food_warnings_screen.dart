import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Lebensmittelwarnungen (BVL). Direkt-Fetch von der oeffentlichen API,
/// kein Server-Proxy noetig.
class FoodWarningsScreen extends ConsumerStatefulWidget {
  const FoodWarningsScreen({super.key});

  @override
  ConsumerState<FoodWarningsScreen> createState() =>
      _FoodWarningsScreenState();
}

class _FoodWarningsScreenState extends ConsumerState<FoodWarningsScreen> {
  static const String _bvlUrl =
      'https://megov.bayern.de/verbraucherschutz/produkt/lebensmittelwarnung/api?searchText=&page=0&size=30';

  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(_bvlUrl));
      req.headers.set('User-Agent', 'MensaEna-App/4.0');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map && data['content'] is List) {
          return data['content'] as List;
        }
      }
    } catch (_) {
      // fall-through → empty
    } finally {
      client.close(force: true);
    }
    return const [];
  }

  Future<void> _refresh() async {
    final fresh = _fetch();
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'modules.foodWarnings'.tr(),
      currentRoute: '/dashboard/warnungen',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                );
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.apple,
                            size: 32,
                            color: AppColors.mute,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Keine aktuellen Lebensmittelwarnungen.',
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final w = list[i] as Map<String, dynamic>;
                  return _Tile(warning: w);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.warning});
  final Map<String, dynamic> warning;

  @override
  Widget build(BuildContext context) {
    final title = (warning['titel'] ?? warning['title'] ?? '').toString();
    final product = (warning['produktbezeichnung'] ?? '').toString();
    final company = (warning['inverkehrbringer'] ?? '').toString();
    final published =
        DateTime.tryParse((warning['veroeffentlichungsdatum'] ?? '').toString());
    final link =
        (warning['link'] ?? warning['detailLink'] ?? '').toString();

    return InkWell(
      onTap: link.isNotEmpty
          ? () => launchUrl(Uri.parse(link),
              mode: LaunchMode.externalApplication)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 14, color: AppColors.amber),
                const SizedBox(width: 6),
                Text('BVL', style: AppTypography.label(size: 9)),
                const Spacer(),
                if (published != null)
                  Text(
                    DateFormat('dd.MM.yyyy').format(published),
                    style: AppTypography.caption(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.body(
                size: 14,
                color: AppColors.ink,
                weight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (product.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                product,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
            if (company.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                company,
                style: AppTypography.caption(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
