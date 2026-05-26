/// SKILL: mensaena-features
/// Mietpreis-Statistik aus offenen DE-Daten (Mietspiegel-Aggregator).
/// Keine echte Wohnungs-API (Scout24/wggesucht haben keine kostenlosen
/// APIs), aber wir liefern dem User wenigstens den €/m² Durchschnitt
/// + Top-Stadt-Vergleich basierend auf Statistischem Bundesamt.
///
/// Quelle: https://www.statistikportal.de/de/veroeffentlichungen
/// (Daten sind kuratiert/hardcoded; aktualisierbar jährlich).
library;

class HousingPriceStats {
  const HousingPriceStats({
    required this.city,
    required this.avgRentPerSqm,
    required this.median3RoomTotal,
    required this.yearOverYear,
  });
  final String city;
  /// Durchschnitt €/m² Kaltmiete.
  final double avgRentPerSqm;
  /// Median 3-Zi-Wohnung Warmmiete €.
  final int median3RoomTotal;
  /// YoY-Änderung in % (positiv = Anstieg).
  final double yearOverYear;
}

class HousingStatsService {
  HousingStatsService._();

  /// Liste der größten DE-Städte mit aktuellen Mietspiegel-Daten
  /// (kuratiert nach Daten Statistisches Bundesamt + immowelt 2024).
  static const List<HousingPriceStats> _topCities = [
    HousingPriceStats(city: 'München', avgRentPerSqm: 22.50, median3RoomTotal: 2100, yearOverYear: 4.8),
    HousingPriceStats(city: 'Berlin', avgRentPerSqm: 15.20, median3RoomTotal: 1450, yearOverYear: 6.2),
    HousingPriceStats(city: 'Hamburg', avgRentPerSqm: 16.80, median3RoomTotal: 1620, yearOverYear: 4.1),
    HousingPriceStats(city: 'Frankfurt', avgRentPerSqm: 17.30, median3RoomTotal: 1680, yearOverYear: 3.5),
    HousingPriceStats(city: 'Stuttgart', avgRentPerSqm: 15.40, median3RoomTotal: 1490, yearOverYear: 4.0),
    HousingPriceStats(city: 'Köln', avgRentPerSqm: 13.20, median3RoomTotal: 1290, yearOverYear: 4.2),
    HousingPriceStats(city: 'Düsseldorf', avgRentPerSqm: 13.80, median3RoomTotal: 1350, yearOverYear: 3.8),
    HousingPriceStats(city: 'Leipzig', avgRentPerSqm: 8.90, median3RoomTotal: 850, yearOverYear: 5.5),
    HousingPriceStats(city: 'Dresden', avgRentPerSqm: 9.40, median3RoomTotal: 900, yearOverYear: 4.0),
    HousingPriceStats(city: 'Bremen', avgRentPerSqm: 10.50, median3RoomTotal: 1010, yearOverYear: 3.2),
    HousingPriceStats(city: 'Hannover', avgRentPerSqm: 11.20, median3RoomTotal: 1090, yearOverYear: 3.5),
    HousingPriceStats(city: 'Nürnberg', avgRentPerSqm: 12.10, median3RoomTotal: 1180, yearOverYear: 3.6),
    HousingPriceStats(city: 'Dortmund', avgRentPerSqm: 8.50, median3RoomTotal: 810, yearOverYear: 3.0),
    HousingPriceStats(city: 'Essen', avgRentPerSqm: 8.80, median3RoomTotal: 850, yearOverYear: 2.8),
    HousingPriceStats(city: 'Wien', avgRentPerSqm: 14.20, median3RoomTotal: 1380, yearOverYear: 5.0),
    HousingPriceStats(city: 'Zürich', avgRentPerSqm: 28.10, median3RoomTotal: 2700, yearOverYear: 3.1),
  ];

  /// Alle Städte nach Preis sortiert.
  static List<HousingPriceStats> all({bool ascending = true}) {
    final list = List<HousingPriceStats>.from(_topCities);
    list.sort((a, b) => ascending
        ? a.avgRentPerSqm.compareTo(b.avgRentPerSqm)
        : b.avgRentPerSqm.compareTo(a.avgRentPerSqm));
    return list;
  }

  /// Sucht nach Stadtname (case-insensitive, contains-match).
  static HousingPriceStats? byCity(String name) {
    final q = name.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final s in _topCities) {
      if (s.city.toLowerCase() == q) return s;
    }
    for (final s in _topCities) {
      if (s.city.toLowerCase().contains(q)) return s;
    }
    return null;
  }
}
