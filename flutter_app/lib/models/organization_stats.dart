/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Aggregierte Zahlen zum Organisations-Verzeichnis. Quelle ist die
/// PostgreSQL-Funktion `get_organization_stats()` (RPC), die ein JSONB
/// liefert mit u.a. `total`, `verified`, `with_reviews`, `avg_rating`,
/// `by_category` (Map<String,int>), `by_country` (Map<String,int>).
class OrganizationStats {
  const OrganizationStats({
    required this.total,
    required this.verified,
    required this.withReviews,
    required this.avgRating,
    required this.byCategory,
    required this.byCountry,
  });

  final int total;
  final int verified;
  final int withReviews;
  final double avgRating;
  final Map<String, int> byCategory;
  final Map<String, int> byCountry;

  factory OrganizationStats.empty() => const OrganizationStats(
        total: 0,
        verified: 0,
        withReviews: 0,
        avgRating: 0,
        byCategory: {},
        byCountry: {},
      );

  factory OrganizationStats.fromJson(Map<String, dynamic> j) {
    Map<String, int> intMap(dynamic v) {
      if (v is! Map) return const {};
      final out = <String, int>{};
      v.forEach((k, val) {
        if (val is num) out[k.toString()] = val.toInt();
      });
      return out;
    }

    return OrganizationStats(
      total: (j['total'] as num?)?.toInt() ?? 0,
      verified: (j['verified'] as num?)?.toInt() ?? 0,
      withReviews: (j['with_reviews'] as num?)?.toInt() ?? 0,
      avgRating: (j['avg_rating'] as num?)?.toDouble() ?? 0.0,
      byCategory: intMap(j['by_category']),
      byCountry: intMap(j['by_country']),
    );
  }
}
