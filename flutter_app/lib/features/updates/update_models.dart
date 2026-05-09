/// Modelle für `app_releases` und Changelog-Einträge.

enum ChangelogType {
  feature,
  improvement,
  fix,
  notice,
  unknown;

  static ChangelogType fromString(String? raw) {
    switch (raw) {
      case 'feature':
        return ChangelogType.feature;
      case 'improvement':
        return ChangelogType.improvement;
      case 'fix':
        return ChangelogType.fix;
      case 'notice':
        return ChangelogType.notice;
      default:
        return ChangelogType.unknown;
    }
  }

  String get emoji {
    switch (this) {
      case ChangelogType.feature:
        return '✨';
      case ChangelogType.improvement:
        return '🚀';
      case ChangelogType.fix:
        return '🐛';
      case ChangelogType.notice:
        return '📣';
      case ChangelogType.unknown:
        return '•';
    }
  }

  String get label {
    switch (this) {
      case ChangelogType.feature:
        return 'Neu';
      case ChangelogType.improvement:
        return 'Verbessert';
      case ChangelogType.fix:
        return 'Behoben';
      case ChangelogType.notice:
        return 'Hinweis';
      case ChangelogType.unknown:
        return 'Update';
    }
  }
}

class ChangelogEntry {
  const ChangelogEntry({
    required this.type,
    required this.title,
    this.description,
  });

  final ChangelogType type;
  final String title;
  final String? description;

  factory ChangelogEntry.fromJson(Map<String, dynamic> j) => ChangelogEntry(
        type: ChangelogType.fromString(j['type'] as String?),
        title: (j['title'] as String?) ?? '',
        description: j['description'] as String?,
      );
}

class AppRelease {
  const AppRelease({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.mandatory,
    required this.isPatch,
    required this.platform,
    required this.releasedAt,
    required this.entries,
    this.apkUrl,
  });

  final String id;
  final String version;
  final int buildNumber;
  final bool mandatory;
  final bool isPatch;
  final String platform;
  final DateTime releasedAt;
  final List<ChangelogEntry> entries;
  final String? apkUrl;

  factory AppRelease.fromJson(Map<String, dynamic> j) {
    final changelog = j['changelog'];
    final raw = changelog is Map<String, dynamic>
        ? (changelog['entries'] as List<dynamic>? ?? const <dynamic>[])
        : const <dynamic>[];
    return AppRelease(
      id: j['id'] as String,
      version: j['version'] as String,
      buildNumber: (j['build_number'] as num).toInt(),
      mandatory: (j['mandatory'] as bool?) ?? false,
      isPatch: (j['is_patch'] as bool?) ?? false,
      platform: (j['platform'] as String?) ?? 'android',
      releasedAt: DateTime.tryParse(j['released_at'] as String? ?? '') ??
          DateTime.now(),
      entries: raw
          .whereType<Map<String, dynamic>>()
          .map(ChangelogEntry.fromJson)
          .toList(),
      apkUrl: j['apk_url'] as String?,
    );
  }
}
