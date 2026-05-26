import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_release.dart';
import '../services/supabase_service.dart';

/// SKILL: mensaena-architektur
/// Pruefung auf neue App-Releases. Nur APK-Releases (is_patch=false)
/// triggern die UpdateGate — Patches kommen lautlos via Shorebird OTA.
class AppReleasesRepository {
  const AppReleasesRepository._();

  /// Neueste APK-Release (is_patch=false) — Snapshot.
  static Future<AppRelease?> latestApk({
    String platform = 'android',
  }) async {
    try {
      final row = await sb
          .from('app_releases')
          .select()
          .eq('platform', platform)
          .eq('is_patch', false)
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return AppRelease.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Letzte N Releases (APK + Patches) sortiert nach build_number desc.
  /// Fuer den In-App "Was ist neu?"-Sheet (F48).
  static Future<List<AppRelease>> recent({
    int limit = 8,
    String platform = 'android',
  }) async {
    try {
      final rows = await sb
          .from('app_releases')
          .select()
          .eq('platform', platform)
          .order('build_number', ascending: false)
          .limit(limit);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(AppRelease.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// Resultat-Tuple: Latest-Release, current-buildNumber.
class UpdateCheck {
  const UpdateCheck({
    required this.currentBuild,
    required this.latest,
  });
  final int currentBuild;
  final AppRelease? latest;

  bool get hasUpdate =>
      latest != null && latest!.buildNumber > currentBuild;
  bool get isMandatory => hasUpdate && (latest?.mandatory ?? false);
}

/// Provider — wird vom UpdateGate gewatched.
final updateCheckProvider = FutureProvider<UpdateCheck>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final current = int.tryParse(info.buildNumber) ?? 0;
  final latest = await AppReleasesRepository.latestApk();
  return UpdateCheck(currentBuild: current, latest: latest);
});
