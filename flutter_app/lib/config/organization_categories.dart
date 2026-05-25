import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'theme/app_colors.dart';

/// SKILL: mensaena-features + mensaena-design
/// Statisches Kategorien-Mapping fuer Organisationen. 15 Kategorien plus
/// 'allgemein' als Fallback. Wird von Karte, Suche, Detail-Screen,
/// Filter-Dropdowns und Marker-Farben genutzt.
class OrgCategoryConfig {
  const OrgCategoryConfig({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.markerColor,
  });

  /// DB-Wert (organizations.category)
  final String value;

  /// Anzeige-Label (deutsch)
  final String label;

  /// Lucide-Icon
  final IconData icon;

  /// Vordergrundfarbe (z.B. Icon-Tint)
  final Color color;

  /// Hintergrundfarbe (z.B. Chip-Background)
  final Color bgColor;

  /// Hex-Farbe fuer Map-Marker (Leaflet/MapLibre)
  final String markerColor;
}

const kOrgCategories = <OrgCategoryConfig>[
  OrgCategoryConfig(
    value: 'tierheim',
    label: 'Tierheim',
    icon: LucideIcons.dog,
    color: AppColors.amber,
    bgColor: AppColors.amberSoft,
    markerColor: '#F59E0B',
  ),
  OrgCategoryConfig(
    value: 'tierschutz',
    label: 'Tierschutz',
    icon: LucideIcons.heart,
    color: AppColors.amberWarm,
    bgColor: AppColors.amberSoft,
    markerColor: '#FBBF24',
  ),
  OrgCategoryConfig(
    value: 'tierarzt',
    label: 'Tierarzt',
    icon: LucideIcons.stethoscope,
    color: AppColors.teal,
    bgColor: AppColors.tealSoft,
    markerColor: '#0EA5E9',
  ),
  OrgCategoryConfig(
    value: 'sozial',
    label: 'Soziale Einrichtung',
    icon: LucideIcons.heart,
    color: AppColors.herzrot,
    bgColor: AppColors.herzrotWarm,
    markerColor: '#EF4444',
  ),
  OrgCategoryConfig(
    value: 'tafel',
    label: 'Tafel',
    icon: LucideIcons.shoppingBag,
    color: AppColors.leben,
    bgColor: AppColors.lebenSoft,
    markerColor: '#22C55E',
  ),
  OrgCategoryConfig(
    value: 'obdachlosenhilfe',
    label: 'Obdachlosenhilfe',
    icon: LucideIcons.home,
    color: AppColors.bronze,
    bgColor: AppColors.bronzeSoft,
    markerColor: '#C79363',
  ),
  OrgCategoryConfig(
    value: 'jugendhilfe',
    label: 'Jugendhilfe',
    icon: LucideIcons.users,
    color: AppColors.tealSoft,
    bgColor: AppColors.tealSoft,
    markerColor: '#7DD3FC',
  ),
  OrgCategoryConfig(
    value: 'seniorenhilfe',
    label: 'Seniorenhilfe',
    icon: LucideIcons.heartHandshake,
    color: AppColors.trust,
    bgColor: AppColors.trustSoft,
    markerColor: '#D4A054',
  ),
  OrgCategoryConfig(
    value: 'frauenhaus',
    label: 'Frauenhaus',
    icon: LucideIcons.shield,
    color: AppColors.herzrotWarm,
    bgColor: AppColors.herzrotWarm,
    markerColor: '#F87171',
  ),
  OrgCategoryConfig(
    value: 'fluechtlingshilfe',
    label: 'Fluechtlingshilfe',
    icon: LucideIcons.globe,
    color: AppColors.teal,
    bgColor: AppColors.tealSoft,
    markerColor: '#0EA5E9',
  ),
  OrgCategoryConfig(
    value: 'umweltschutz',
    label: 'Umweltschutz',
    icon: LucideIcons.leaf,
    color: AppColors.leben,
    bgColor: AppColors.lebenSoft,
    markerColor: '#22C55E',
  ),
  OrgCategoryConfig(
    value: 'kirche',
    label: 'Kirche & Religion',
    icon: LucideIcons.church,
    color: AppColors.trust,
    bgColor: AppColors.trustSoft,
    markerColor: '#D4A054',
  ),
  OrgCategoryConfig(
    value: 'bildung',
    label: 'Bildung',
    icon: LucideIcons.bookOpen,
    color: AppColors.bronze,
    bgColor: AppColors.bronzeSoft,
    markerColor: '#C79363',
  ),
  OrgCategoryConfig(
    value: 'kultur',
    label: 'Kultur',
    icon: LucideIcons.palette,
    color: AppColors.amberWarm,
    bgColor: AppColors.amberSoft,
    markerColor: '#FBBF24',
  ),
  OrgCategoryConfig(
    value: 'sport',
    label: 'Sport & Verein',
    icon: LucideIcons.dumbbell,
    color: AppColors.teal,
    bgColor: AppColors.tealSoft,
    markerColor: '#0EA5E9',
  ),
  OrgCategoryConfig(
    value: 'allgemein',
    label: 'Allgemein',
    icon: LucideIcons.building2,
    color: AppColors.mute,
    bgColor: AppColors.line,
    markerColor: '#64748B',
  ),
];

/// Liefert die Konfiguration zu einer Kategorie. Faellt auf
/// `allgemein` zurueck, wenn die Kategorie nicht bekannt ist.
OrgCategoryConfig getCategoryConfig(String category) {
  for (final c in kOrgCategories) {
    if (c.value == category) return c;
  }
  return kOrgCategories.last;
}

const kCountryFlags = <String, String>{
  'DE': '🇩🇪',
  'AT': '🇦🇹',
  'CH': '🇨🇭',
};

const kCountryLabels = <String, String>{
  'DE': 'Deutschland',
  'AT': 'Oesterreich',
  'CH': 'Schweiz',
};

const kDaysMap = <String, String>{
  'monday': 'Montag',
  'tuesday': 'Dienstag',
  'wednesday': 'Mittwoch',
  'thursday': 'Donnerstag',
  'friday': 'Freitag',
  'saturday': 'Samstag',
  'sunday': 'Sonntag',
};

const _kWeekdayKeys = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// Prueft anhand eines JSONB-Maps `opening_hours`, ob die Organisation
/// gerade geoeffnet ist. Erwartet pro Wochentag entweder:
///   - `{ "open": "09:00", "close": "17:00" }`
///   - `{ "closed": true }`
///   - eine Liste mehrerer Slots `[ { "open": ..., "close": ... }, ... ]`
/// Rueckgabe: `'open'`, `'closed'` oder `'unknown'` (wenn kein Eintrag).
String isCurrentlyOpen(Map<String, dynamic>? openingHours) {
  if (openingHours == null || openingHours.isEmpty) return 'unknown';
  final now = DateTime.now();
  final dayKey = _kWeekdayKeys[(now.weekday - 1).clamp(0, 6)];
  final entry = openingHours[dayKey];
  if (entry == null) return 'unknown';
  final slots = <Map<String, dynamic>>[];
  if (entry is List) {
    for (final s in entry) {
      if (s is Map<String, dynamic>) slots.add(s);
    }
  } else if (entry is Map<String, dynamic>) {
    slots.add(entry);
  } else {
    return 'unknown';
  }
  if (slots.isEmpty) return 'closed';
  final nowMinutes = now.hour * 60 + now.minute;
  for (final slot in slots) {
    if (slot['closed'] == true) continue;
    final open = _parseHHMM(slot['open']);
    final close = _parseHHMM(slot['close']);
    if (open == null || close == null) continue;
    if (close > open) {
      if (nowMinutes >= open && nowMinutes < close) return 'open';
    } else {
      // Ueber Mitternacht (z.B. 22:00-02:00)
      if (nowMinutes >= open || nowMinutes < close) return 'open';
    }
  }
  return 'closed';
}

int? _parseHHMM(Object? raw) {
  if (raw is! String) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}
