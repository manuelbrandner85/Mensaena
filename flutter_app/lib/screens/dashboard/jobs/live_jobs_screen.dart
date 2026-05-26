/// SKILL: mensaena-features + mensaena-design
/// Live-Jobsuche via Bundesagentur fuer Arbeit (DE).
/// Service-Klasse JobsService.search() existiert seit Phase 3 — hier nur
/// die UI dazu. Filter: Postleitzahl, Umkreis-Slider, optionales Stichwort.
/// Tap auf Job-Karte → externalUrl im Browser.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/profiles_repository.dart';
import '../../../services/jobs_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';

class LiveJobsScreen extends ConsumerStatefulWidget {
  const LiveJobsScreen({super.key});

  @override
  ConsumerState<LiveJobsScreen> createState() => _LiveJobsScreenState();
}

class _LiveJobsScreenState extends ConsumerState<LiveJobsScreen> {
  final _plzCtrl = TextEditingController();
  final _qCtrl = TextEditingController();
  int _radius = 25;
  Future<List<JobOffer>>? _future;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _preFillPlz();
  }

  Future<void> _preFillPlz() async {
    final p = await ProfilesRepository.getMine();
    String plz = p?.homePostalCode ?? '';
    if (plz.isEmpty) {
      final loc = p?.location ?? '';
      final m = RegExp(r'\b\d{5}\b').firstMatch(loc);
      if (m != null) plz = m.group(0)!;
    }
    // FIX (User-Wunsch: GPS-unabhängig): KEIN Hardcode auf Berlin mehr.
    // Wenn PLZ leer → leer lassen + bundesweite Suche.
    if (!mounted) return;
    setState(() => _plzCtrl.text = plz);
    _search();
  }

  @override
  void dispose() {
    _plzCtrl.dispose();
    _qCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    // PLZ leer = bundesweit suchen (User-Wunsch GPS-unabhängig).
    setState(() {
      _loading = true;
      _future = JobsService.search(
        plz: _plzCtrl.text.trim(),
        umkreis: _radius,
        was: _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
        size: 40,
      );
    });
    await _future;
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'jobs.liveSearchTitle'.tr(),
      currentRoute: '/dashboard/jobs/search',
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: EditorialModuleHeader(
                metaIndex: '§ 22',
                metaCategory: 'jobs.liveSearchTitle'.tr(),
                title: 'jobs.liveSearchTitle'.tr(),
                subtitle: 'jobs.liveSearchSubtitle'.tr(),
              ),
            ),
            // Filter-Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _plzCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      decoration: InputDecoration(
                        hintText: 'PLZ',
                        counterText: '',
                        prefixIcon: const Icon(LucideIcons.mapPin, size: 14),
                        filled: true,
                        fillColor: AppColors.elevated,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: AppTypography.body(size: 13, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _qCtrl,
                      decoration: InputDecoration(
                        hintText: 'jobs.searchHint'.tr(),
                        prefixIcon: const Icon(LucideIcons.search, size: 14),
                        filled: true,
                        fillColor: AppColors.elevated,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: AppTypography.body(size: 13, color: AppColors.ink),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Text('jobs.radiusKm'.tr(namedArgs: {'km': '$_radius'}),
                      style: AppTypography.label(size: 10)),
                  Expanded(
                    child: Slider(
                      value: _radius.toDouble(),
                      min: 5,
                      max: 200,
                      divisions: 9,
                      activeColor: AppColors.bronze,
                      label: '$_radius km',
                      onChanged: (v) =>
                          setState(() => _radius = v.round()),
                      onChangeEnd: (_) => _search(),
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _search,
                    icon: const Icon(LucideIcons.search,
                        size: 18, color: AppColors.bronze),
                    tooltip: 'common.search'.tr(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.line, height: 8),
            Expanded(
              child: _future == null
                  ? Center(
                      child: Text('jobs.enterPlzPrompt'.tr(),
                          style: AppTypography.caption()),
                    )
                  : FutureBuilder<List<JobOffer>>(
                      future: _future,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.bronze),
                          );
                        }
                        final list = snap.data ?? const <JobOffer>[];
                        if (list.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: EmptyStateCard(
                              icon: LucideIcons.briefcase,
                              title: 'jobs.noneFound'.tr(),
                              description: 'jobs.noneFoundHint'.tr(),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, i) => _JobCard(job: list[i]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});
  final JobOffer job;

  Future<void> _open() async {
    try {
      await launchUrl(Uri.parse(job.externalUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bronze.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.briefcase,
                  size: 18, color: AppColors.bronze),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                    ),
                  ),
                  if (job.employer != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      job.employer!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft),
                    ),
                  ],
                  if (job.location != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin,
                            size: 11, color: AppColors.mute),
                        const SizedBox(width: 3),
                        Text(job.location!,
                            style: AppTypography.caption()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(LucideIcons.externalLink,
                size: 14, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}
