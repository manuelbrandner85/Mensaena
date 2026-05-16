import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/painters/neighborhood_pulse.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_app_shell.dart';
import '../../core/widgets/cinema_sheet.dart';
import '../../core/widgets/kategorie_chip.dart';
import '../../core/widgets/nachbarschaft_card.dart';
import 'providers/map_providers.dart';

/// Interaktive Karte mit Post-Markern, Filter-Bar und Standort-Pulse.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  final Set<PostKategorie> _activeFilters = <PostKategorie>{};

  @override
  Widget build(BuildContext context) {
    final markers = ref.watch(mapMarkersProvider);
    final userPos = ref.watch(userPositionProvider).asData?.value;

    return CinemaAppShell(
      currentRoute: '/map',
      title: 'KARTE',
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userPos == null
                  ? const LatLng(51.1657, 10.4515) // Deutschland-Zentrum
                  : LatLng(userPos.latitude, userPos.longitude),
              initialZoom: userPos == null ? 6 : 13,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'de.mensaena.app',
              ),
              if (userPos != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(userPos.latitude, userPos.longitude),
                      width: 80,
                      height: 80,
                      child: const Center(
                        child: NeighborhoodPulse(maxRadius: 60),
                      ),
                    ),
                  ],
                ),
              markers.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (posts) {
                  final filtered = _activeFilters.isEmpty
                      ? posts
                      : posts.where((p) {
                          final kat = _parseKategorie(p['type'] as String?);
                          return kat != null && _activeFilters.contains(kat);
                        }).toList();
                  return MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 50,
                      size: const Size(40, 40),
                      markers: filtered.map(_buildMarker).toList(),
                      builder: (ctx, cluster) => _ClusterBubble(count: cluster.length),
                    ),
                  );
                },
              ),
            ],
          ),
          Positioned(
            top: kToolbarHeight + MediaQuery.paddingOf(context).top + 12,
            left: 12,
            right: 12,
            child: _FilterBar(
              active: _activeFilters,
              onToggle: (kat) {
                setState(() {
                  if (_activeFilters.contains(kat)) {
                    _activeFilters.remove(kat);
                  } else {
                    _activeFilters.add(kat);
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildMarker(Map<String, dynamic> post) {
    final lat = (post['lat'] as num?)?.toDouble();
    final lng = (post['lng'] as num?)?.toDouble();
    final kat = _parseKategorie(post['type'] as String?);
    if (lat == null || lng == null) {
      return const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
    }
    return Marker(
      point: LatLng(lat, lng),
      width: 28,
      height: 28,
      child: GestureDetector(
        onTap: () => _openDetail(post),
        child: Container(
          decoration: BoxDecoration(
            color: _colorFor(kat),
            shape: BoxShape.circle,
            border: Border.all(color: MnColors.ink.withValues(alpha: 0.8), width: 2),
            boxShadow: [
              BoxShadow(
                color: _colorFor(kat).withValues(alpha: 0.6),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> post) {
    final author = (post['profiles'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    CinemaSheet.show<void>(
      context,
      initialSize: 0.55,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: NachbarschaftCard(
          kategorie: _parseKategorie(post['type'] as String?),
          authorName: author['full_name'] as String?,
          authorAvatarUrl: author['avatar_url'] as String?,
          timeAgo: post['created_at'] as String? ?? '',
          content: (post['content'] as String?) ?? '',
          imageUrl: post['image_url'] as String?,
          onTap: () => GoRouter.of(context).push('/posts/${post['id']}'),
        ),
      ),
    );
  }

  PostKategorie? _parseKategorie(String? type) {
    if (type == null) return null;
    return PostKategorie.values.where((k) => k.name == type).firstOrNull;
  }

  Color _colorFor(PostKategorie? kat) {
    switch (kat) {
      case PostKategorie.krisenhilfe:
        return MnColors.herzrot;
      case PostKategorie.hilfeAnbieten:
        return MnColors.amber;
      case PostKategorie.hilfeSuchen:
        return MnColors.teal;
      case PostKategorie.veranstaltung:
        return MnColors.tealSoft;
      default:
        return MnColors.amberWarm;
    }
  }

}

class _FilterBar extends StatelessWidget {
  final Set<PostKategorie> active;
  final void Function(PostKategorie) onToggle;

  const _FilterBar({required this.active, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: MnColors.voidColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: MnColors.line),
      ),
      child: SizedBox(
        height: 28,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: PostKategorie.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final kat = PostKategorie.values[i];
            return KategorieChip(
              kategorie: kat,
              selected: active.contains(kat),
              onTap: () => onToggle(kat),
            );
          },
        ),
      ),
    );
  }
}

class _ClusterBubble extends StatelessWidget {
  final int count;
  const _ClusterBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MnColors.elevated,
        shape: BoxShape.circle,
        border: Border.all(color: MnColors.amber, width: 2),
        boxShadow: [
          BoxShadow(color: MnColors.amber.withValues(alpha: 0.4), blurRadius: 12),
        ],
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: MnTypography.mono(
            size: 13,
            color: MnColors.ink,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
