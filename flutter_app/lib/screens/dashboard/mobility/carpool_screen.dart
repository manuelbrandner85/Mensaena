import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/carpool_route.dart';
import '../../../repositories/carpool_repository.dart';
import '../../../services/location_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/address_autocomplete_field.dart';
import '../../../widgets/shared/empty_state_widget.dart';
import '../../../widgets/shared/error_state_widget.dart';

/// Fahrgemeinschaften: zeigt die eigenen Routen und erlaubt das Anlegen neuer
/// (Wochentag + Start via GPS + Ziel via Adresssuche). Nutzt die bestehende
/// CarpoolRepository-API unverändert.
class CarpoolScreen extends ConsumerWidget {
  const CarpoolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myCarpoolRoutesProvider);
    return DashboardScaffold(
      title: 'carpool.title'.tr(),
      currentRoute: '/dashboard/mobility/carpool',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.teal,
        icon: const Icon(LucideIcons.plus, size: 18),
        label: Text('carpool.add'.tr()),
        onPressed: () => _openCreateSheet(context, ref),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: () async => ref.invalidate(myCarpoolRoutesProvider),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => ListView(children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                title: 'errors.generic'.tr(),
                onRetry: () => ref.invalidate(myCarpoolRoutesProvider),
              ),
            ]),
            data: (routes) {
              if (routes.isEmpty) {
                return ListView(children: [
                  const SizedBox(height: 80),
                  EmptyStateWidget(
                    icon: LucideIcons.users,
                    title: 'carpool.emptyTitle'.tr(),
                    subtitle: 'carpool.emptySubtitle'.tr(),
                  ),
                ]);
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: routes.length,
                itemBuilder: (_, i) => _RouteCard(
                  route: routes[i],
                  onDelete: () async {
                    await CarpoolRepository.deleteRoute(routes[i].id);
                    ref.invalidate(myCarpoolRoutesProvider);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CarpoolCreateSheet(
        onCreated: () => ref.invalidate(myCarpoolRoutesProvider),
      ),
    );
  }
}

String _dayLabel(DayOfWeek d) => 'carpool.days.${d.name}'.tr();

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, required this.onDelete});
  final CarpoolRoute route;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.users, size: 18, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dayLabel(route.dayOfWeek),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${route.startLat.toStringAsFixed(3)}, ${route.startLng.toStringAsFixed(3)}'
                  '  →  '
                  '${route.endLat.toStringAsFixed(3)}, ${route.endLng.toStringAsFixed(3)}',
                  style: AppTypography.caption(color: AppColors.lightMute),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(LucideIcons.trash2, size: 16),
            color: AppColors.lightMute,
          ),
        ],
      ),
    );
  }
}

class _CarpoolCreateSheet extends StatefulWidget {
  const _CarpoolCreateSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  State<_CarpoolCreateSheet> createState() => _CarpoolCreateSheetState();
}

class _CarpoolCreateSheetState extends State<_CarpoolCreateSheet> {
  DayOfWeek _day = DayOfWeek.monday;
  double? _startLat;
  double? _startLng;
  double? _endLat;
  double? _endLng;
  String? _endLabel;
  final _destCtrl = TextEditingController();
  bool _locating = false;
  bool _saving = false;

  @override
  void dispose() {
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService.getBestPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) {
        _startLat = pos.latitude;
        _startLng = pos.longitude;
      }
    });
    if (pos == null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errors.generic'.tr())));
    }
  }

  bool get _canSave =>
      _startLat != null && _endLat != null && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final id = await CarpoolRepository.createRoute(
      startLat: _startLat!,
      startLng: _startLng!,
      endLat: _endLat!,
      endLng: _endLng!,
      dayOfWeek: _day,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) {
      widget.onCreated();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errors.generic'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('carpool.add'.tr(),
                  style: AppTypography.body(
                      size: 15,
                      color: AppColors.lightInk,
                      weight: FontWeight.w800)),
              const SizedBox(height: 14),
              Text('carpool.day'.tr().toUpperCase(),
                  style: AppTypography.label(size: 9, color: AppColors.lightMute)),
              const SizedBox(height: 4),
              DropdownButton<DayOfWeek>(
                value: _day,
                isExpanded: true,
                items: [
                  for (final d in DayOfWeek.values)
                    DropdownMenuItem(value: d, child: Text(_dayLabel(d))),
                ],
                onChanged: (v) => setState(() => _day = v ?? _day),
              ),
              const SizedBox(height: 12),
              Text('carpool.start'.tr().toUpperCase(),
                  style: AppTypography.label(size: 9, color: AppColors.lightMute)),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.mapPin, size: 16),
                label: Text(_startLat == null
                    ? 'carpool.useLocation'.tr()
                    : '${_startLat!.toStringAsFixed(3)}, ${_startLng!.toStringAsFixed(3)}'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal),
              ),
              const SizedBox(height: 12),
              Text('carpool.destination'.tr().toUpperCase(),
                  style: AppTypography.label(size: 9, color: AppColors.lightMute)),
              const SizedBox(height: 4),
              AddressAutocompleteField(
                controller: _destCtrl,
                label: 'carpool.destination'.tr(),
                onSelected: (s) {
                  setState(() {
                    _endLat = s.lat;
                    _endLng = s.lng;
                    _endLabel = s.displayName;
                  });
                },
              ),
              if (_endLabel != null) ...[
                const SizedBox(height: 4),
                Text(_endLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(color: AppColors.lightMute)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canSave ? _save : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.check, size: 16),
                  label: Text('carpool.save'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
