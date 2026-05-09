import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supabase.dart';
import 'update_models.dart';

const _kLastSeenBuildNumberKey = 'updates.last_seen_build_number';

/// State für UpdateGate. Drei mögliche Zustände:
/// - Loading (während wir Versions-Manifest laden)
/// - Pflicht-Update (mandatory & remote.buildNumber > local.buildNumber)
/// - OK / kein Update nötig
class UpdateState {
  const UpdateState({
    required this.loading,
    this.mandatoryRelease,
    this.error,
  });

  final bool loading;

  /// Wenn != null: User MUSS aktualisieren, App-UI ist blockiert.
  final AppRelease? mandatoryRelease;
  final String? error;

  bool get blocked => mandatoryRelease != null;

  static const initial = UpdateState(loading: true);
}

class UpdateService {
  UpdateService();

  /// Liefert das aktuellste Release für Android oder null falls keins existiert.
  Future<AppRelease?> latestRelease() async {
    final rows = await sb
        .from('app_releases')
        .select('*')
        .inFilter('platform', ['android', 'all'])
        .order('build_number', ascending: false)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isEmpty) return null;
    return AppRelease.fromJson(list.first);
  }

  /// Liefert das HÖCHSTE mandatory-Release (egal wie alt) – sodass User
  /// auf einer ALTEN Version, die unter einer mandatory-Build-Number liegt,
  /// blockiert werden, selbst wenn danach noch nicht-mandatory Releases
  /// erschienen sind.
  Future<AppRelease?> latestMandatoryRelease() async {
    final rows = await sb
        .from('app_releases')
        .select('*')
        .inFilter('platform', ['android', 'all'])
        .eq('mandatory', true)
        .eq('is_patch', false)
        .order('build_number', ascending: false)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isEmpty) return null;
    return AppRelease.fromJson(list.first);
  }

  /// Liefert alle Releases mit höherer Build-Number als [currentBuildNumber],
  /// neuestes zuerst. Nützlich um aufgesammelte Patches als Was-ist-Neu zu zeigen.
  Future<List<AppRelease>> releasesNewerThan(int currentBuildNumber) async {
    final rows = await sb
        .from('app_releases')
        .select('*')
        .inFilter('platform', ['android', 'all'])
        .gt('build_number', currentBuildNumber)
        .order('build_number', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows)
        .map(AppRelease.fromJson)
        .toList();
  }

  /// Aktuelle App-Version als (versionString, buildNumber).
  Future<({String version, int buildNumber})> currentApp() async {
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    return (version: '${info.version}+${info.buildNumber}', buildNumber: build);
  }

  /// Liefert alle Releases mit Build-Number ≤ aktueller App-Version,
  /// die der User bei einem früheren Launch noch nicht gesehen hat.
  /// Beim ersten Launch wird der Marker auf die aktuelle Build-Number
  /// gesetzt und eine leere Liste zurückgegeben (kein Sheet beim Erst-Login).
  Future<List<AppRelease>> consumeUnseenReleases() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await currentApp();
    final lastSeen = prefs.getInt(_kLastSeenBuildNumberKey);
    if (lastSeen == null) {
      await prefs.setInt(_kLastSeenBuildNumberKey, current.buildNumber);
      return const [];
    }
    if (lastSeen >= current.buildNumber) return const [];
    final rows = await sb
        .from('app_releases')
        .select('*')
        .inFilter('platform', ['android', 'all'])
        .gt('build_number', lastSeen)
        .lte('build_number', current.buildNumber)
        .order('build_number', ascending: false)
        .limit(20);
    final list = List<Map<String, dynamic>>.from(rows)
        .map(AppRelease.fromJson)
        .toList();
    await prefs.setInt(_kLastSeenBuildNumberKey, current.buildNumber);
    return list;
  }

  /// Hauptcheck: gibt es ein zwingendes Update?
  ///
  /// Algorithmus:
  /// 1. Hole das HÖCHSTE mandatory-APK-Release (egal wie viele Patches
  ///    danach noch erschienen sind).
  /// 2. Liegt unsere build_number darunter → BLOCK.
  /// 3. Sonst kein Block (Patches landen über Shorebird automatisch,
  ///    der WhatsNewSheet wird vom AppShell-Observer getriggert).
  ///
  /// Wichtig: dadurch wird ein User auf z. B. 2.0.0 vom App-Start
  /// abgehalten sobald 2.5.0 mit mandatory=true existiert, auch wenn
  /// nach 2.5.0 noch reine Patches (2.5.1, 2.5.2 …) gepostet wurden.
  Future<UpdateState> check() async {
    try {
      final current = await currentApp();
      final mandatory = await latestMandatoryRelease();
      if (mandatory != null && mandatory.buildNumber > current.buildNumber) {
        return UpdateState(loading: false, mandatoryRelease: mandatory);
      }
      return const UpdateState(loading: false);
    } catch (e) {
      return UpdateState(loading: false, error: '$e');
    }
  }
}

final updateServiceProvider =
    Provider<UpdateService>((ref) => UpdateService());

/// Async-Provider für den initialen Update-Check beim App-Launch.
final updateCheckProvider = FutureProvider<UpdateState>((ref) async {
  final service = ref.watch(updateServiceProvider);
  return service.check();
});
