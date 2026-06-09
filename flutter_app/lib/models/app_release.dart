/// SKILL: mensaena-architektur
/// Spiegel der Supabase-Tabelle `app_releases`. Wird vom UpdateGate
/// gelesen um zu pruefen ob ein neuerer Build/Patch verfuegbar ist.
class AppRelease {
  const AppRelease({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.mandatory,
    required this.isPatch,
    required this.platform,
    required this.releasedAt,
    required this.changelog,
    this.apkUrl,
  });

  final String id;
  final String version;
  final int buildNumber;
  final bool mandatory;
  final bool isPatch;
  final String platform;
  final DateTime releasedAt;
  final Map<String, dynamic> changelog;
  final String? apkUrl;

  factory AppRelease.fromJson(Map<String, dynamic> j) {
    return AppRelease(
      id: j['id'] as String,
      version: j['version'] as String? ?? '',
      buildNumber: (j['build_number'] as num?)?.toInt() ?? 0,
      mandatory: (j['mandatory'] as bool?) ?? false,
      isPatch: (j['is_patch'] as bool?) ?? false,
      platform: j['platform'] as String? ?? 'android',
      releasedAt: DateTime.tryParse(j['released_at'] as String? ?? '')?.toUtc() ??
          DateTime.now(),
      changelog: (j['changelog'] is Map)
          ? Map<String, dynamic>.from(j['changelog'] as Map)
          : const {},
      apkUrl: j['apk_url'] as String?,
    );
  }
}
