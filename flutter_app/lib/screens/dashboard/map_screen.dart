import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/crisis.dart';
import '../../models/event.dart';
import '../../models/post.dart';
import '../../providers/effects_gate_provider.dart';
import '../../repositories/crisis_repository.dart';
import '../../repositories/events_repository.dart';
import '../../repositories/posts_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/air_quality_service.dart';
import '../../services/location_service.dart';
import '../../services/saved_pins_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/effects/bloom.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/app_snackbar.dart';

/// SKILL: flutter-build-responsive-layout + mensaena-features
/// Karten-Screen V2 — Pendant zur Web /dashboard/map mit Leaflet.
/// Tiles: OpenStreetMap (Light) / CartoDB Dark Matter (Dark) via FMTC-Cache.
/// 15 Features: Kategorie-Filter, Suche, Heatmap, Notfall-Blinker,
/// Dark-Mode-Tiles, Move-Reload, Standort-Punkt, Banner, gestaffeltes
/// Laden, Zoom-fit-Radius, Tile-Cache, ueberarbeitetes BottomSheet.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const LatLng _defaultCenter = LatLng(51.1657, 10.4515); // Mitte DE
  // 0 = "Alle" (kein Standort-Filter — zeigt alle Beiträge weltweit).
  // Default ist jetzt "Alle"; der Radius-Filter ist optional und greift
  // erst wenn der User aktiv einen km-Wert wählt.
  static const List<int> _radiusOptions = [0, 5, 10, 25, 50, 100];
  static const Map<int, double> _radiusZoom = {
    0: 5.0, 5: 13.0, 10: 12.0, 25: 10.0, 50: 9.0, 100: 7.0,
  };
  static const String _storeName = 'mensaena_tiles';

  final MapController _mapController = MapController();
  LatLng _center = _defaultCenter;
  // Separate GPS-Position (User-Standort) — wird NUR bei expliziter GPS-
  // Abfrage gesetzt, NICHT beim Pan. Sonst "wandert" der User-Pin.
  LatLng? _gpsLocation;
  double _zoom = 6;
  // Default 0 = Alle Beiträge (kein Standort-Filter). User kann optional
  // einen Radius wählen um nur die Umgebung zu sehen.
  int _radiusKm = 0;
  List<Post> _posts = const [];
  bool _loading = true;
  String? _error;
  bool _hasGps = false;
  // C1: Post-Sheet offen → Karte tritt minimal zurück (AnimatedScale).
  bool _postSheetOpen = false;

  // V1 — Kategorie-Filter: standardmaessig alle 9 Typen aktiv (User-Wunsch).
  // Wird beim ersten Tap auf einen Chip auf Single-Select-Style umgeschaltet.
  static const Set<String> _allTypes = {
    'crisis',
    'help_request',
    'help_offered',
    'rescue',
    'animal',
    'housing',
    'mobility',
    'sharing',
    'mental',
  };
  final Set<String> _activeTypes = {..._allTypes};

  // V2 — Suchfeld
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();

  // V5 — Debounce fuer Map-Move
  Timer? _moveDebounce;

  // V11 — Heatmap-Toggle
  bool _showHeatmap = false;

  // F62 — Tile-Style: 0=auto (light/dark via theme), 1=Voyager, 2=Topo
  int _tileStyle = 0;

  // F64 — gespeicherte User-Pins (on-device).
  List<SavedPin> _savedPins = const [];

  // V3 — FMTC-Ready Flag fuer Tile-Cache
  bool _fmtcReady = false;

  // V16 — Accessibility-Layer (Overpass-API). Toggle in Toolbar,
  // laedt wheelchair-Tags fuer den aktuellen Center+Radius. Cache pro
  // (center,radius)-Schluessel, TTL 10min, max 20 Eintraege.
  bool _accessibilityOn = false;
  bool _a11yLoading = false;
  List<_AccessiblePlace> _accessiblePlaces = const [];
  // Content-Layer-Toggles: Karte = Herzstück → mehrere Inhaltstypen
  // gleichzeitig sichtbar (User-Wunsch "1M€ App"). Defaults: Krisen IMMER
  // an (Notlagen sollen sichtbar sein), Events optional.
  bool _showCrises = true;
  bool _showEvents = true;
  final Map<String, ({DateTime at, List<_AccessiblePlace> places})>
      _a11yCache = {};

  @override
  void initState() {
    super.initState();
    _initFmtc();
    _initLocationAndLoad();
    _loadSavedPins();
  }

  Future<void> _loadSavedPins() async {
    final pins = await SavedPinsService.all();
    if (!mounted) return;
    setState(() => _savedPins = pins);
    // F90: einmal pro Install zeigen wir den Long-Press-Hinweis als Snackbar.
    if (pins.isEmpty) _maybeShowPinHint();
  }

  static const _pinHintKey = 'mensaena_map_pin_hint_v1';
  Future<void> _maybeShowPinHint() async {
    try {
      const storage = FlutterSecureStorage();
      final shown = await storage.read(key: _pinHintKey);
      if (shown == 'true') return;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: AppColors.surface,
        content: Text('map.longPressHint'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
      await storage.write(key: _pinHintKey, value: 'true');
    } catch (_) {}
  }

  /// F64: Long-Press auf Map → Dialog "Pin speichern?" mit Label-Eingabe.
  Future<void> _promptSavePin(double lat, double lng) async {
    final ctrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('map.savePinTitle'.tr(),
            style: AppTypography.body(
                size: 15,
                color: AppColors.ink,
                weight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'map.savePinHint'.tr(),
            filled: true,
            fillColor: AppColors.elevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.cancel'.tr())),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.bronze,
              foregroundColor: AppColors.voidColor,
            ),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (label == null || label.isEmpty) return;
    final pin = SavedPin(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      lat: lat,
      lng: lng,
      createdAt: DateTime.now(),
    );
    await SavedPinsService.add(pin);
    await _loadSavedPins();
  }

  /// F64: Pin-Tap → Detail-Sheet mit Lösch-Option.
  void _openSavedPinSheet(SavedPin pin) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.bookmark,
                    size: 18, color: AppColors.bronze),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(pin.label,
                      style: AppTypography.display(
                          size: 18, color: AppColors.ink)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${pin.lat.toStringAsFixed(5)}, ${pin.lng.toStringAsFixed(5)}',
              style: AppTypography.caption(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await ConfirmDialog.show(
                    ctx,
                    title: 'map.removePin'.tr(),
                    message: 'map.removePinConfirm'.tr(),
                    danger: true,
                  );
                  if (!confirmed) return;
                  await SavedPinsService.remove(pin.id);
                  await _loadSavedPins();
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                },
                icon: const Icon(LucideIcons.trash2, size: 14),
                label: Text('map.removePin'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.herzrotWarm,
                  side: BorderSide(
                      color: AppColors.herzrotWarm.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchCtrl.dispose();
    _moveDebounce?.cancel();
    super.dispose();
  }

  /// V16: Overpass-Query fuer wheelchair-Tagged Nodes in Radius.
  /// Verwendet "overpass-api.de", fallback bei Fehlern silent. Cache
  /// TTL 10min — innerhalb dieser Frist wird die Query nicht erneut
  /// gefeuert sondern aus dem Memory bedient.
  Future<void> _loadAccessiblePlaces() async {
    final lat = _center.latitude;
    final lng = _center.longitude;
    // Bei "Alle" (0) für die Barrierefrei-Orte einen sinnvollen Umkreis
    // nehmen (weltweite Overpass-Query wäre nicht machbar).
    final radiusM = (_radiusKm == 0 ? 25 : _radiusKm) * 1000;
    final cacheKey =
        '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}:$radiusM';
    final hit = _a11yCache[cacheKey];
    if (hit != null &&
        DateTime.now().difference(hit.at) < const Duration(minutes: 10)) {
      setState(() => _accessiblePlaces = hit.places);
      return;
    }
    if (!mounted) return;
    setState(() => _a11yLoading = true);
    try {
      final q =
          '[out:json][timeout:10];node["wheelchair"](around:$radiusM,$lat,$lng);out body 80;';
      final uri = Uri.parse('https://overpass-api.de/api/interpreter');
      final resp = await http.post(uri, body: {'data': q}).timeout(
          const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        if (mounted) setState(() => _a11yLoading = false);
        return;
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final elements =
          (json['elements'] as List?) ?? const <dynamic>[];
      final places = <_AccessiblePlace>[];
      for (final el in elements) {
        if (el is! Map) continue;
        final tags = el['tags'];
        final wheel = (tags is Map ? tags['wheelchair'] : null) as String?;
        final name = (tags is Map ? tags['name'] : null) as String?;
        final plat = (el['lat'] as num?)?.toDouble();
        final plng = (el['lon'] as num?)?.toDouble();
        if (plat == null || plng == null || wheel == null) continue;
        places.add(_AccessiblePlace(
          lat: plat,
          lng: plng,
          name: name ?? 'map.a11y.unnamed'.tr(),
          status: wheel,
        ));
      }
      // Cache trimmen damit kein Memory-Leak entsteht.
      if (_a11yCache.length > 20) {
        final oldest = _a11yCache.entries
            .toList()
          ..sort((a, b) => a.value.at.compareTo(b.value.at));
        _a11yCache.remove(oldest.first.key);
      }
      _a11yCache[cacheKey] = (at: DateTime.now(), places: places);
      if (!mounted) return;
      setState(() {
        _accessiblePlaces = places;
        _a11yLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _a11yLoading = false);
    }
  }

  Future<void> _initFmtc() async {
    try {
      await FMTCObjectBoxBackend().initialise();
      const store = FMTCStore(_storeName);
      final ready = await store.manage.ready;
      if (!ready) await store.manage.create();
      if (mounted) setState(() => _fmtcReady = true);
    } catch (_) {
      _fmtcReady = false;
    }
  }

  Future<void> _initLocationAndLoad() async {
    // 1) Robuster GPS-Fix (frischer Fix → Last-Known als Fallback).
    final pos = await LocationService.getBestPosition(
      accuracy: LocationAccuracy.medium,
    );
    if (pos != null) {
      if (!mounted) return;
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
        _gpsLocation = LatLng(pos.latitude, pos.longitude);
        _zoom = _radiusZoom[_radiusKm] ?? 12;
        _hasGps = true;
      });
      _mapController.move(_center, _zoom);
    } else {
      // 2) Fallback: in den Einstellungen gespeicherter Heimat-/Profil-
      //    Standort — adressiert "Standort aktiviert, aber Karte zeigt nichts".
      final profile = ref.read(myProfileProvider).asData?.value;
      final double? lat = profile?.latitude ?? profile?.homeLat;
      final double? lng = profile?.longitude ?? profile?.homeLng;
      if (lat != null && lng != null) {
        if (!mounted) return;
        final home = LatLng(lat, lng);
        setState(() {
          _center = home;
          _gpsLocation = home;
          _zoom = _radiusZoom[_radiusKm] ?? 12;
          _hasGps = true;
        });
        _mapController.move(_center, _zoom);
      } else if (mounted) {
        // 3) Wirklich nichts da → sichtbarer Hinweis statt stiller Leere.
        AppSnackBar.info(context, 'map.locationUnavailable'.tr());
      }
    }
    await _loadPosts();
  }

  /// V13 — gestaffeltes Laden bei grossem Radius.
  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // _radiusKm == 0 → "Alle": kein Standort-Filter, lat/lng = null →
      // Repository liefert die neuesten aktiven Beiträge global.
      final showAll = _radiusKm == 0;
      if (showAll || _radiusKm >= 50) {
        // Erst schnell 20 Posts zeigen, dann im Hintergrund mehr nachladen.
        final fast = await PostsRepository.getNearby(
          lat: (showAll || !_hasGps) ? null : _center.latitude,
          lng: (showAll || !_hasGps) ? null : _center.longitude,
          radiusKm: _radiusKm,
          limit: 20,
        );
        if (!mounted) return;
        setState(() {
          _posts = fast.where(_hasGeo).toList();
          _loading = false;
        });
        // Async background-fetch fuer den vollen Satz.
        unawaited(_backgroundFullFetch());
      } else {
        final posts = await PostsRepository.getNearby(
          lat: !_hasGps ? null : _center.latitude,
          lng: !_hasGps ? null : _center.longitude,
          radiusKm: _radiusKm,
          limit: 100,
        );
        if (!mounted) return;
        setState(() {
          _posts = posts.where(_hasGeo).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'map.loadFailed'.tr();
        _loading = false;
      });
    }
  }

  Future<void> _backgroundFullFetch() async {
    try {
      final showAll = _radiusKm == 0;
      final full = await PostsRepository.getNearby(
        lat: (showAll || !_hasGps) ? null : _center.latitude,
        lng: (showAll || !_hasGps) ? null : _center.longitude,
        radiusKm: _radiusKm == 0 ? 100 : _radiusKm,
        limit: 200,
      );
      if (!mounted) return;
      // Merge nach id-Set damit keine Duplikate.
      final byId = <String, Post>{for (final p in _posts) p.id: p};
      for (final p in full) {
        if (_hasGeo(p)) byId[p.id] = p;
      }
      setState(() => _posts = byId.values.toList());
    } catch (_) {/* silent fallback — fast-batch ist schon angezeigt */}
  }

  /// V2 — Suche via search_posts RPC.
  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      await _loadPosts();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final showAll = _radiusKm == 0;
      final posts = await PostsRepository.search(
        query: q,
        lat: (showAll || !_hasGps) ? null : _center.latitude,
        lng: (showAll || !_hasGps) ? null : _center.longitude,
        radiusKm: showAll ? 50 : _radiusKm,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _posts = posts.where(_hasGeo).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'map.searchFailed'.tr();
        _loading = false;
      });
    }
  }

  bool _hasGeo(Post p) => p.latitude != null && p.longitude != null;

  /// V1 — client-seitiges Kategorie-Filtern.
  List<Post> get _filteredPosts => _activeTypes.isEmpty
      ? _posts
      : _posts.where((p) => _activeTypes.contains(p.type)).toList();

  /// F61: zeigt Luftqualitaet (Open-Meteo) am aktuellen Map-Center.
  Future<void> _showAirQualitySheet() async {
    final center = _mapController.camera.center;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AirQualitySheet(lat: center.latitude, lng: center.longitude),
    );
  }

  Future<void> _recenterOnGps() async {
    final pos = await LocationService.getBestPosition(
      accuracy: LocationAccuracy.high,
    );
    if (!mounted) return;
    if (pos == null) {
      AppSnackBar.info(context, 'map.locationUnavailable'.tr());
      return;
    }
    final loc = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _center = loc;
      _gpsLocation = loc;
      _hasGps = true;
    });
    _mapController.move(loc, _radiusZoom[_radiusKm] ?? 13);
    await _loadPosts();
  }

  void _openPostSheet(Post post) {
    // C1: Karte tritt zurück solange das Sheet offen ist.
    setState(() => _postSheetOpen = true);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PostBottomSheet(
        post: post,
        markerColor: _markerColor(post.type),
        markerEmoji: _markerEmoji(post.type),
        markerLabel: _typeLabel(post.type),
        distanceKm: _hasGps && post.latitude != null && post.longitude != null
            ? LocationService.haversineKm(
                _center.latitude,
                _center.longitude,
                post.latitude!,
                post.longitude!,
              )
            : null,
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _postSheetOpen = false);
    });
  }

  String _tileUrl(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (_tileStyle) {
      case 1:
        return 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      case 2:
        return 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png';
      case 0:
      default:
        return isDark
            ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  /// F62: cycle through 3 tile styles.
  void _cycleTileStyle() {
    setState(() {
      _tileStyle = (_tileStyle + 1) % 3;
    });
    final names = [
      'map.tileStyleAuto',
      'map.tileStyleVoyager',
      'map.tileStyleTopo',
    ];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 1),
      content: Text(names[_tileStyle].tr()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final markers = _filteredPosts.map(_buildMarker).toList();
    // Krisen + Events als zusätzliche Marker-Layers. Beide Provider sind
    // FutureProvider — bei Lade/Fehler einfach leer (.asData?.value ?? []),
    // dann erscheint kein Marker. Geo-Filter passiert serverseitig durch
    // activeCrisesProvider (kann lat/lng nehmen) bzw. listUpcoming
    // (alle, hier client-seitig auf hasGeo gefiltert).
    final crises = _showCrises
        ? (ref.watch(activeCrisesProvider).asData?.value ?? const <Crisis>[])
        : const <Crisis>[];
    final events = _showEvents
        ? (ref.watch(upcomingEventsProvider).asData?.value ??
            const <EventItem>[])
        : const <EventItem>[];
    final crisisMarkers = [
      for (final c in crises)
        if (c.latitude != null && c.longitude != null)
          Marker(
            point: LatLng(c.latitude!, c.longitude!),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => context.push('/dashboard/crisis/${c.id}'),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.herzrot.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.herzrot.withValues(alpha: 0.55),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.alertTriangle,
                    size: 18, color: Colors.white),
              ),
            ),
          ),
    ];
    final eventMarkers = [
      for (final e in events)
        if (e.latitude != null && e.longitude != null)
          Marker(
            point: LatLng(e.latitude!, e.longitude!),
            width: 34,
            height: 34,
            child: GestureDetector(
              onTap: () => context.push('/dashboard/events/${e.id}'),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealSoft.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealSoft.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.calendar,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
    ];
    return DashboardScaffold(
      title: 'map.screenTitle'.tr(),
      currentRoute: '/dashboard/map',
      fab: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Content-Layer-Toggle: Krisen (Herzrot) sichtbar/aus.
          FloatingActionButton.small(
            heroTag: 'crises_fab',
            backgroundColor: _showCrises
                ? AppColors.herzrot
                : AppColors.surface,
            foregroundColor:
                _showCrises ? Colors.white : AppColors.herzrot,
            onPressed: () => setState(() => _showCrises = !_showCrises),
            tooltip: 'map.toggleCrises'.tr(),
            child: const Icon(LucideIcons.alertTriangle),
          ),
          const SizedBox(height: 10),
          // Content-Layer-Toggle: Events (Teal) sichtbar/aus.
          FloatingActionButton.small(
            heroTag: 'events_fab',
            backgroundColor: _showEvents
                ? AppColors.tealSoft
                : AppColors.surface,
            foregroundColor:
                _showEvents ? Colors.white : AppColors.tealSoft,
            onPressed: () => setState(() => _showEvents = !_showEvents),
            tooltip: 'map.toggleEvents'.tr(),
            child: const Icon(LucideIcons.calendar),
          ),
          const SizedBox(height: 10),
          // F62: Tile-Style cyclen (Auto → Voyager → Topo)
          FloatingActionButton.small(
            heroTag: 'tile_fab',
            backgroundColor: AppColors.bronze,
            foregroundColor: AppColors.voidColor,
            onPressed: _cycleTileStyle,
            tooltip: 'map.tileStyleTooltip'.tr(),
            child: const Icon(LucideIcons.layers),
          ),
          const SizedBox(height: 10),
          // F61: Air-Quality am aktuellen Map-Center
          FloatingActionButton.small(
            heroTag: 'aq_fab',
            backgroundColor: AppColors.tealSoft,
            foregroundColor: AppColors.voidColor,
            onPressed: _showAirQualitySheet,
            tooltip: 'map.airQualityTooltip'.tr(),
            child: const Icon(LucideIcons.wind),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'gps_fab',
            backgroundColor: AppColors.amber,
            foregroundColor: AppColors.voidColor,
            onPressed: _recenterOnGps,
            child: const Icon(LucideIcons.locate),
          ),
        ],
      ),
      body: AnimatedScale(
        // C1 Atmosphäre: Sheet offen → Karte tritt minimal zurück
        // (iOS-Modal-Tiefe). Nur auf `full`, Transform-only, 220 ms
        // ease-out — Barrier-Dim kommt vom Sheet selbst.
        scale: _postSheetOpen &&
                ref.watch(effectsProfileProvider).isFull
            ? 0.985
            : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              minZoom: 3,
              maxZoom: 18,
              // F64: Long-Press → eigenen Pin setzen
              onLongPress: (tapPos, latLng) =>
                  _promptSavePin(latLng.latitude, latLng.longitude),
              // V5 — debounced Move-Reload
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _moveDebounce?.cancel();
                  _moveDebounce =
                      Timer(const Duration(milliseconds: 600), () {
                    final newCenter = _mapController.camera.center;
                    if (!mounted) return;
                    // BUGFIX: nur _center updaten, NICHT _hasGps oder
                    // _gpsLocation — der User-Pin bleibt fix am echten
                    // GPS-Standort, _center bewegt sich mit der Karte.
                    setState(() {
                      _center = newCenter;
                    });
                    _loadPosts();
                  });
                }
              },
            ),
            children: [
              // V3 + V15 — TileLayer mit FMTC-Cache + Dark-Mode-aware URL
              TileLayer(
                urlTemplate: _tileUrl(context),
                userAgentPackageName: 'de.mensaena.app',
                tileProvider: _fmtcReady
                    ? const FMTCStore(_storeName).getTileProvider(
                        settings: FMTCTileProviderSettings(
                          cachedValidDuration: const Duration(days: 7),
                        ),
                      )
                    : NetworkTileProvider(),
              ),
              // F64 — gespeicherte User-Pins (Bronze-Bookmark)
              if (_savedPins.isNotEmpty)
                MarkerLayer(
                  markers: _savedPins
                      .map((p) => Marker(
                            point: LatLng(p.lat, p.lng),
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () => _openSavedPinSheet(p),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.bronze
                                      .withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.voidColor,
                                      width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.bronze
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  LucideIcons.bookmark,
                                  size: 16,
                                  color: AppColors.voidColor,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              // V4 — eigener Standort als blauer Google-Style-Punkt
              // BUGFIX: rendert _gpsLocation (statisch nach GPS-Lookup),
              // NICHT _center (wandert beim Pan).
              if (_gpsLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _gpsLocation!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4285F4)
                                  .withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              // V11 — Heatmap (CircleMarker) ODER MarkerCluster
              if (_showHeatmap)
                CircleLayer(
                  circles: [
                    for (final p in _filteredPosts)
                      CircleMarker(
                        point: LatLng(p.latitude!, p.longitude!),
                        radius: 30,
                        color: _markerColor(p.type)
                            .withValues(alpha: 0.3),
                        borderStrokeWidth: 0,
                        borderColor: Colors.transparent,
                      ),
                  ],
                )
              else
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 50,
                    size: const Size(40, 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(50),
                    markers: [
                      // Reihenfolge = Z-Order: Krisen ZULETZT, damit sie
                      // bei Überlappung dominieren (Notfall-Sichtbarkeit).
                      ...markers,
                      ...eventMarkers,
                      ...crisisMarkers,
                      if (_accessibilityOn)
                        for (final p in _accessiblePlaces)
                          Marker(
                            point: LatLng(p.lat, p.lng),
                            width: 28,
                            height: 28,
                            child: GestureDetector(
                              onTap: () => _openA11ySheet(p),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _a11yColor(p.status),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.voidColor, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  LucideIcons.accessibility,
                                  size: 14,
                                  color: AppColors.voidColor,
                                ),
                              ),
                            ),
                          ),
                    ],
                    builder: (context, mks) {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.voidColor,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${mks.length}',
                            style: AppTypography.mono(
                              size: 13,
                              color: AppColors.voidColor,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          // ── Radius-Bar + Search (top) ──────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _RadiusBar(
              options: _radiusOptions,
              selected: _radiusKm,
              loading: _loading,
              count: _filteredPosts.length,
              error: _error,
              searchOpen: _searchOpen,
              searchCtrl: _searchCtrl,
              onToggleSearch: () => setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchCtrl.clear();
                  _loadPosts();
                }
              }),
              onSubmitSearch: _runSearch,
              onSelect: (km) async {
                setState(() => _radiusKm = km);
                final zoom = _radiusZoom[km] ?? _zoom;
                _mapController.move(_center, zoom);
                await _loadPosts();
              },
            ),
          ),
          // ── V1 Kategorie-Filter ────────────────────────────────────
          Positioned(
            top: 96,
            left: 12,
            right: 12,
            child: _CategoryFilterBar(
              active: _activeTypes,
              onToggle: (type) {
                setState(() {
                  if (_activeTypes.contains(type)) {
                    _activeTypes.remove(type);
                  } else {
                    _activeTypes.add(type);
                  }
                });
              },
            ),
          ),
          // ── V16 Accessibility-Toggle ─────────────────────────────
          Positioned(
            top: 152,
            right: 60,
            child: GestureDetector(
              onTap: () async {
                setState(() => _accessibilityOn = !_accessibilityOn);
                if (_accessibilityOn) {
                  await _loadAccessiblePlaces();
                }
              },
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accessibilityOn
                      ? AppColors.leben.withValues(alpha: 0.85)
                      : AppColors.deep.withValues(alpha: 0.92),
                  border: Border.all(
                    color: _accessibilityOn
                        ? AppColors.lebenSoft
                        : AppColors.lineActive,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _a11yLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.voidColor))
                    : Icon(
                        LucideIcons.accessibility,
                        size: 18,
                        color: _accessibilityOn
                            ? AppColors.voidColor
                            : AppColors.leben,
                      ),
              ),
            ),
          ),
          // ── V11 Heatmap-Toggle (top-right) ─────────────────────────
          Positioned(
            top: 152,
            right: 12,
            child: GestureDetector(
              onTap: () => setState(() => _showHeatmap = !_showHeatmap),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _showHeatmap
                      ? AppColors.amber.withValues(alpha: 0.85)
                      : AppColors.deep.withValues(alpha: 0.92),
                  border: Border.all(
                    color: _showHeatmap
                        ? AppColors.amberWarm
                        : AppColors.lineActive,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _showHeatmap ? LucideIcons.flame : LucideIcons.mapPin,
                  size: 18,
                  color: _showHeatmap
                      ? AppColors.voidColor
                      : AppColors.amber,
                ),
              ),
            ),
          ),
          // ── V14 GPS-Banner ────────────────────────────────────────
          if (!_hasGps && !_loading)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: _GpsBanner(onActivate: () async {
                await Geolocator.openLocationSettings();
                await _initLocationAndLoad();
              }),
            ),
        ],
        ),
      ),
    );
  }

  /// V12 — Marker mit PulseBloom-Effekt fuer Notfaelle.
  Marker _buildMarker(Post p) {
    final color = _markerColor(p.type);
    // urgency ist jetzt String — PostUrgencyX-Extension liefert int-Level.
    final isUrgent = p.type == 'crisis' || p.urgencyLevel > 2;
    final pin = GestureDetector(
      onTap: () => _openPostSheet(p),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.voidColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            _markerEmoji(p.type),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
    return Marker(
      point: LatLng(p.latitude!, p.longitude!),
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: isUrgent
          ? PulseBloom(
              color: AppColors.herzrot,
              radius: 20,
              minIntensity: 0.3,
              maxIntensity: 0.8,
              child: pin,
            )
          : pin,
    );
  }

  static Color _markerColor(String type) {
    switch (type) {
      case 'crisis':
      case 'help_request':
        return AppColors.herzrot;
      case 'help_offered':
        return AppColors.leben;
      case 'rescue':
        return const Color(0xFFFB923C);
      case 'animal':
        return const Color(0xFFEC4899);
      case 'housing':
        return const Color(0xFF60A5FA);
      case 'mobility':
        return const Color(0xFF818CF8);
      case 'sharing':
        return AppColors.teal;
      case 'mental':
        return AppColors.tealSoft;
      default:
        return AppColors.amber;
    }
  }

  static String _markerEmoji(String type) {
    switch (type) {
      case 'rescue':
        return '🧡';
      case 'animal':
        return '🐾';
      case 'housing':
        return '🏡';
      case 'supply':
        return '🌾';
      case 'mobility':
        return '🚗';
      case 'sharing':
        return '🔄';
      case 'community':
        return '🗳️';
      case 'crisis':
        return '🚨';
      case 'help_request':
        return '🆘';
      case 'help_offered':
        return '💚';
      case 'skill':
        return '🎯';
      case 'knowledge':
        return '📚';
      case 'mental':
        return '🧠';
      default:
        return '📍';
    }
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'crisis':
        return 'Notfall';
      case 'help_request':
        return 'Hilfegesuch';
      case 'help_offered':
        return 'Hilfe';
      case 'rescue':
        return 'Rettung';
      case 'animal':
        return 'Tier';
      case 'housing':
        return 'Wohnen';
      case 'mobility':
        return 'Mobilität';
      case 'sharing':
        return 'Teilen';
      case 'mental':
        return 'Mental';
      case 'supply':
        return 'Versorgung';
      case 'community':
        return 'Community';
      case 'skill':
        return 'Skill';
      case 'knowledge':
        return 'Wissen';
      default:
        return 'Beitrag';
    }
  }
}

// ── Radius-Bar mit Such-Toggle ───────────────────────────────────────────
class _RadiusBar extends StatelessWidget {
  const _RadiusBar({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.loading,
    required this.count,
    required this.error,
    required this.searchOpen,
    required this.searchCtrl,
    required this.onToggleSearch,
    required this.onSubmitSearch,
  });

  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool loading;
  final int count;
  final String? error;
  final bool searchOpen;
  final TextEditingController searchCtrl;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSubmitSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.deep.withValues(alpha: 0.92),
        border: Border.all(color: AppColors.lineActive),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.target,
                size: 13,
                color: AppColors.amber,
              ),
              const SizedBox(width: 6),
              if (searchOpen)
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSubmitSearch,
                    style: AppTypography.body(
                        size: 12, color: AppColors.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'map.searchHint'.tr(),
                      hintStyle: AppTypography.caption(),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                )
              else
                Text(
                  'Radius',
                  style: AppTypography.label(size: 9),
                ),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: AppColors.amber,
                  ),
                )
              else if (error != null)
                Text(
                  error!,
                  style: AppTypography.body(
                    size: 11,
                    color: AppColors.herzrotWarm,
                  ),
                )
              else if (!searchOpen)
                Text(
                  '$count Beiträge',
                  style: AppTypography.mono(
                    size: 11,
                    color: AppColors.ink,
                  ),
                ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onToggleSearch,
                child: Icon(
                  searchOpen ? LucideIcons.x : LucideIcons.search,
                  size: 14,
                  color: searchOpen ? AppColors.amber : AppColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: options
                .map(
                  (km) => GestureDetector(
                    onTap: () => onSelect(km),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: km == selected
                            ? AppColors.amber.withValues(alpha: 0.2)
                            : AppColors.surface.withValues(alpha: 0.7),
                        border: Border.all(
                          color: km == selected
                              ? AppColors.amber
                              : AppColors.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        km == 0 ? 'map.radiusAll'.tr() : '$km km',
                        style: AppTypography.mono(
                          size: 11,
                          color: km == selected
                              ? AppColors.amber
                              : AppColors.inkSoft,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── V1 Kategorie-Filter ──────────────────────────────────────────────────
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({required this.active, required this.onToggle});

  final Set<String> active;
  final ValueChanged<String> onToggle;

  static const List<(String, String, String, Color)> _entries = [
    ('crisis', '🚨', 'Notfall', AppColors.herzrot),
    ('help_request', '🆘', 'Hilfegesuch', AppColors.herzrot),
    ('help_offered', '💚', 'Hilfe', AppColors.leben),
    ('rescue', '🧡', 'Rettung', Color(0xFFFB923C)),
    ('animal', '🐾', 'Tier', Color(0xFFEC4899)),
    ('housing', '🏡', 'Wohnen', Color(0xFF60A5FA)),
    ('mobility', '🚗', 'Mobilität', Color(0xFF818CF8)),
    ('sharing', '🔄', 'Teilen', AppColors.teal),
    ('mental', '🧠', 'Mental', AppColors.tealSoft),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.deep.withValues(alpha: 0.92),
        border: Border.all(color: AppColors.lineActive),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final e in _entries) ...[
              _CategoryChip(
                type: e.$1,
                emoji: e.$2,
                label: e.$3,
                color: e.$4,
                isActive: active.contains(e.$1),
                onTap: () => onToggle(e.$1),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.type,
    required this.emoji,
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  final String type;
  final String emoji;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.25)
              : AppColors.surface.withValues(alpha: 0.7),
          border: Border.all(
            color: isActive
                ? color
                : AppColors.line.withValues(alpha: 0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.label(
                size: 9,
                color: isActive ? color : AppColors.inkSoft,
                weight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── V14 GPS-Banner ───────────────────────────────────────────────────────
class _GpsBanner extends StatelessWidget {
  const _GpsBanner({required this.onActivate});
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.20),
        border: Border.all(color: AppColors.amber),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.mapPinOff,
              color: AppColors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'map.gpsOffTitle'.tr(),
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  'map.gpsOffBody'.tr(),
                  style: AppTypography.body(
                    size: 11,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onActivate,
            child: Text('map.gpsActivate'.tr()),
          ),
        ],
      ),
    );
  }
}

// ── V6 erweiterter Post-Bottom-Sheet ─────────────────────────────────────
/// K2: öffnet die Karten-App des Geräts mit einer Route zum Ziel.
/// Versucht zuerst geo:?q= (Android-Standard, lässt den User die App
/// wählen), fällt auf die Google-Maps-Web-URL zurück (öffnet App falls
/// installiert, sonst Browser — funktioniert auch auf iOS).
Future<void> _openDirections(
    BuildContext context, double lat, double lng) async {
  final geo = Uri.parse('geo:0,0?q=$lat,$lng');
  final web = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  try {
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(web, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      AppSnackBar.error(context, 'map.routeFailed'.tr());
    }
  }
}

class _PostBottomSheet extends StatelessWidget {
  const _PostBottomSheet({
    required this.post,
    required this.markerColor,
    required this.markerEmoji,
    required this.markerLabel,
    required this.distanceKm,
  });

  final Post post;
  final Color markerColor;
  final String markerEmoji;
  final String markerLabel;
  final double? distanceKm;

  String _relativeTime() {
    final now = DateTime.now();
    final diff = now.difference(post.createdAt);
    if (diff.inMinutes < 60) return 'map.minutesAgo'.tr(namedArgs: {'n': '${diff.inMinutes}'});
    if (diff.inHours < 24) return 'map.hoursAgo'.tr(namedArgs: {'n': '${diff.inHours}'});
    if (diff.inDays < 30) return 'map.daysAgo'.tr(namedArgs: {'n': '${diff.inDays}'});
    final months = diff.inDays ~/ 30;
    return 'map.monthsAgo'.tr(namedArgs: {'n': '$months'});
  }

  @override
  Widget build(BuildContext context) {
    final firstImage = post.allImageUrls.isNotEmpty
        ? post.allImageUrls.first
        : null;
    final isUrgent = post.hasUrgency;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Kategorie-Badge + Bild
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: markerColor.withValues(alpha: 0.2),
                          border: Border.all(color: markerColor),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(markerEmoji,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              markerLabel,
                              style: AppTypography.label(
                                size: 9,
                                color: markerColor,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isUrgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.herzrot
                                .withValues(alpha: 0.2),
                            border:
                                Border.all(color: AppColors.herzrot),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.alertTriangle,
                                  size: 10, color: AppColors.herzrot),
                              const SizedBox(width: 4),
                              Text(
                                'map.urgent'.tr(),
                                style: AppTypography.label(
                                  size: 9,
                                  color: AppColors.herzrot,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (firstImage != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: firstImage,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 80,
                        height: 80,
                        color: AppColors.elevated,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: AppColors.elevated,
                        child: const Icon(LucideIcons.imageOff,
                            color: AppColors.mute),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              post.title,
              style: AppTypography.display(
                size: 22,
                height: 1.2,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            // Zeit + Entfernung
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.clock,
                        size: 11, color: AppColors.mute),
                    const SizedBox(width: 4),
                    Text(_relativeTime(),
                        style: AppTypography.caption()),
                  ],
                ),
                if (distanceKm != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 11, color: AppColors.mute),
                      const SizedBox(width: 4),
                      Text(
                        'map.distanceKm'.tr(namedArgs: {
                          'km': distanceKm!.toStringAsFixed(1),
                        }),
                        style: AppTypography.caption(),
                      ),
                    ],
                  ),
              ],
            ),
            if (post.description != null && post.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                post.description!,
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.inkSoft,
                  height: 1.55,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (post.locationText != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    LucideIcons.mapPin,
                    size: 14,
                    color: AppColors.mute,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      post.locationText!,
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.mute,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            // K2 Routenplanung — öffnet die Karten-App des Geräts mit einer
            // Route zum Post-Standort. Nur wenn Koordinaten vorhanden.
            if (post.latitude != null && post.longitude != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openDirections(
                      context, post.latitude!, post.longitude!),
                  icon: const Icon(LucideIcons.navigation, size: 16),
                  label: Text('map.routeTo'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bronze,
                    side: BorderSide(
                        color: AppColors.bronze.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('common.close'.tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/dashboard/posts/${post.id}');
                    },
                    icon: const Icon(LucideIcons.arrowRight, size: 16),
                    label: Text('common.open'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── V16 Accessibility (Overpass-Layer) ────────────────────────────
class _AccessiblePlace {
  const _AccessiblePlace({
    required this.lat,
    required this.lng,
    required this.name,
    required this.status,
  });

  final double lat;
  final double lng;
  final String name;
  final String status; // 'yes' | 'limited' | 'no' | sonstige

  Color get color {
    switch (status) {
      case 'yes':
        return AppColors.leben;
      case 'limited':
        return AppColors.amber;
      case 'no':
        return AppColors.herzrot;
      default:
        return AppColors.mute;
    }
  }
}

Color _a11yColor(String s) {
  switch (s) {
    case 'yes':
      return AppColors.leben;
    case 'limited':
      return AppColors.amber;
    case 'no':
      return AppColors.herzrot;
    default:
      return AppColors.mute;
  }
}

extension _A11ySheet on _MapScreenState {
  void _openA11ySheet(_AccessiblePlace p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.accessibility,
                        size: 18, color: AppColors.voidColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                          size: 16, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'map.a11y.status.${p.status}'.tr(),
                style: AppTypography.body(size: 13, color: p.color),
              ),
              const SizedBox(height: 4),
              Text(
                'map.a11y.source'.tr(),
                style: AppTypography.caption(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// F61: Air-Quality-Bottom-Sheet — listet aktuelle Schadstoffwerte am Punkt.
class _AirQualitySheet extends StatefulWidget {
  const _AirQualitySheet({required this.lat, required this.lng});
  final double lat;
  final double lng;

  @override
  State<_AirQualitySheet> createState() => _AirQualitySheetState();
}

class _AirQualitySheetState extends State<_AirQualitySheet> {
  late Future<List<AirQualitySample>> _future;

  @override
  void initState() {
    super.initState();
    _future =
        AirQualityService.nearby(lat: widget.lat, lng: widget.lng);
  }

  String _labelFor(String code) {
    switch (code) {
      case 'pm25':
        return 'PM2.5';
      case 'pm10':
        return 'PM10';
      case 'o3':
        return 'Ozon';
      case 'no2':
        return 'NO₂';
      case 'so2':
        return 'SO₂';
      case 'co':
        return 'CO';
      default:
        return code.toUpperCase();
    }
  }

  Color _colorFor(String code, double v) {
    // grobe WHO/EEA-Grenzen — gruen = gut, gelb = mittel, rot = schlecht.
    double good = 50, mid = 100;
    if (code == 'pm25') {
      good = 10;
      mid = 25;
    } else if (code == 'pm10') {
      good = 20;
      mid = 50;
    } else if (code == 'o3') {
      good = 60;
      mid = 120;
    } else if (code == 'no2') {
      good = 25;
      mid = 50;
    }
    if (v <= good) return AppColors.leben;
    if (v <= mid) return AppColors.amber;
    return AppColors.herzrotWarm;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.wind,
                  size: 20, color: AppColors.tealSoft),
              const SizedBox(width: 8),
              Text('map.airQualityTitle'.tr(),
                  style: AppTypography.display(
                      size: 18, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.lat.toStringAsFixed(3)}, ${widget.lng.toStringAsFixed(3)} · Open-Meteo',
            style: AppTypography.caption(),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<AirQualitySample>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.tealSoft),
                    ),
                  ),
                );
              }
              final list = snap.data ?? const <AirQualitySample>[];
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('map.airQualityEmpty'.tr(),
                      style: AppTypography.caption()),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: list.map((s) {
                  final color = _colorFor(s.parameter, s.value);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: color.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_labelFor(s.parameter),
                            style: AppTypography.body(
                                size: 11,
                                color: color,
                                weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '${s.value.toStringAsFixed(1)} ${s.unit}',
                          style: AppTypography.body(
                              size: 14,
                              color: AppColors.ink,
                              weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
