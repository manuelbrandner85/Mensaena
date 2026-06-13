/// SKILL: mensaena-design (Higgsfield-Modul-Banner)
/// Zentrale Zuordnung Modul-Route → Header-Banner-Asset.
///
/// Jedes Modul bekommt oben ein passendes, einheitlich gestaltetes
/// Higgsfield-Keyart (Dusk-Diorama-Look, konsistent mit Splash/Onboarding).
/// Die Bilder liegen in `assets/images/modules/<key>.webp`.
///
/// Nutzung: `DashboardScaffold(headerImage: moduleBanner('/dashboard/posts'))`.
/// Unbekannte/nicht gepflegte Routen → null (kein Banner, kein Fehler).
library;

/// Route (oder Route-Präfix) → Banner-Asset. Reihenfolge: erst exakte
/// Treffer, dann Präfix-Fallback für Detail-Routen desselben Moduls.
// Es werden NUR Routen gelistet, für die das Banner-Asset wirklich
// existiert (sonst zeigte ModuleBanner ein leeres Band). Alle 22 Module
// haben jetzt ein eigenes, themenpassendes Higgsfield-Keyart.
const Map<String, String> _kModuleBanners = {
  '/dashboard/posts': 'assets/images/modules/posts.webp',
  '/dashboard/marketplace': 'assets/images/modules/marketplace.webp',
  '/dashboard/events': 'assets/images/modules/events.webp',
  '/dashboard/groups': 'assets/images/modules/groups.webp',
  '/dashboard/crisis': 'assets/images/modules/crisis.webp',
  '/dashboard/knowledge': 'assets/images/modules/knowledge.webp',
  // map bewusst OHNE Banner: die Karte ist vollflächig + nicht scrollbar,
  // ein Header-Streifen würde nur Kartenfläche kosten.
  '/dashboard/organizations': 'assets/images/modules/organizations.webp',
  '/dashboard/animals': 'assets/images/modules/animals.webp',
  '/dashboard/mental-support': 'assets/images/modules/mental_support.webp',
  '/dashboard/board': 'assets/images/modules/board.webp',
  '/dashboard/challenges': 'assets/images/modules/challenges.webp',
  '/dashboard/supply': 'assets/images/modules/supply.webp',
  '/dashboard/harvest': 'assets/images/modules/harvest.webp',
  '/dashboard/rescuer': 'assets/images/modules/rescuer.webp',
  '/dashboard/housing': 'assets/images/modules/housing.webp',
  '/dashboard/mobility': 'assets/images/modules/mobility.webp',
  '/dashboard/jobs': 'assets/images/modules/jobs.webp',
  '/dashboard/timebank': 'assets/images/modules/timebank.webp',
  '/dashboard/wiki': 'assets/images/modules/wiki.webp',
  '/dashboard/skills': 'assets/images/modules/skills.webp',
  '/dashboard/interactions': 'assets/images/modules/interactions.webp',
  // Zweite Welle: weitere user-facing Bereiche, die bisher ohne Header-Bild
  // waren. Admin-/Settings-/Detail-/Create-Screens bleiben bewusst bannerlos.
  '/dashboard/badges': 'assets/images/modules/badges.webp',
  '/dashboard/matching': 'assets/images/modules/matching.webp',
  '/dashboard/friends': 'assets/images/modules/friends.webp',
  '/dashboard/leaderboard': 'assets/images/modules/leaderboard.webp',
  '/dashboard/calendar': 'assets/images/modules/calendar.webp',
  '/dashboard/community-polls': 'assets/images/modules/community_polls.webp',
  '/dashboard/mentorship': 'assets/images/modules/mentorship.webp',
  // Discovery-Variante teilt sich das Mentorship-Keyart (prefix:false → der
  // exakte Sub-Pfad braucht einen eigenen Eintrag).
  '/dashboard/mentorship/find': 'assets/images/modules/mentorship.webp',
  '/dashboard/identify': 'assets/images/modules/identify.webp',
  '/dashboard/harvest-wild': 'assets/images/modules/harvest_wild.webp',
  '/dashboard/charge-stations': 'assets/images/modules/charge_stations.webp',
  '/dashboard/voicemail': 'assets/images/modules/voicemail.webp',
  '/dashboard/wissen': 'assets/images/modules/wissen.webp',
  '/dashboard/teilen': 'assets/images/modules/teilen.webp',
  '/dashboard/warnungen': 'assets/images/modules/warnungen.webp',
};

/// Liefert das Banner-Asset für [route]. [prefix]=false → nur exakter
/// Treffer (Modul-Landing); Detail-Routen wie /dashboard/posts/123 bekommen
/// dann KEIN Banner (sie haben eigene Hero-Bilder). [prefix]=true erlaubt
/// den längsten Präfix-Treffer. Sonst null.
String? moduleBanner(String route, {bool prefix = true}) {
  final exact = _kModuleBanners[route];
  if (exact != null) return exact;
  if (!prefix) return null;
  String? best;
  var bestLen = 0;
  for (final e in _kModuleBanners.entries) {
    if (route.startsWith(e.key) && e.key.length > bestLen) {
      best = e.value;
      bestLen = e.key.length;
    }
  }
  return best;
}
