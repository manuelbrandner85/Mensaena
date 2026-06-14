# Godmode-Ressourcen-Katalog — kostenlose APIs & geprüfte Pakete

> Lebende Liste. Der Godmode-Agent (`admin_agent.yml`) und der Tiefen-Scan
> (`admin_scan.yml`) lesen diese Datei und **bevorzugen** die hier gelisteten
> bewährten, **kostenlosen** Ressourcen, statt Funktionen von Grund auf neu zu
> bauen. Beim Umsetzen einer Aufgabe: passende Ressource hier suchen → bei
> Bedarf aktuelle Doku via Web prüfen → sauber integrieren.

## Grundregeln
- **Kostenlos/ohne Key bevorzugen.** Wo ein Key nötig ist, ist er als
  *(API-Key)* markiert → der Key gehört in Supabase/GitHub-Secrets, **niemals**
  in den Code.
- **Rate-Limits & Attribution respektieren** (z. B. OSM Nominatim: ≤1 req/s,
  User-Agent pflicht; OSM-Daten © OpenStreetMap-Mitwirkende).
- **Pakete:** vorhandene `pubspec.yaml`-Dependencies zuerst nutzen. Neue Pakete
  nur, wenn klar besser; **null-safe, aktiv gepflegt, hohe pub.dev-Popularität**.
  Achtung: **native** Pakete brauchen einen Versions-Bump (kein OTA-Patch) und
  ggf. Plattform-Config — reine Dart-Pakete sind unkritisch.
- **Streams:** Supabase `.stream()` immer mit `.limit()` + `autoDispose`
  (siehe CLAUDE.md). i18n: jeder neue UI-String in alle 7 JSON-Dateien.

## Geo / Karten / Routing
- **OpenStreetMap Nominatim** — Geocoding/Reverse-Geocoding, *kein Key*
  (`https://nominatim.openstreetmap.org`). Rate-Limit ≤1 req/s + User-Agent.
- **Photon (komoot)** — Geocoding-Autocomplete, *kein Key*
  (`https://photon.komoot.io`). Gut für Tipp-Vorschläge.
- **Overpass API** — OSM-POIs (Ladesäulen, Tankstellen, Bänke …), *kein Key*
  (`https://overpass-api.de/api/interpreter`). In der App bereits genutzt.
- **OSM Raster-Tiles** — *kein Key* (Tile-Usage-Policy beachten). Renderer:
  `flutter_map` (bereits Dependency).
- **OSRM** — Routing/Distanz-Matrix, Demo *kein Key*
  (`https://router.project-osrm.org`); für Produktion self-host.
- **OpenRouteService** — Routing/Isochronen/Matrix *(API-Key, free tier)*.

## Wetter / Umwelt
- **Open-Meteo** — Wettervorhersage, **kein Key**, frei für nicht-kommerziell
  (`https://api.open-meteo.com`). Auch **Air-Quality**, **Marine**, **Flood**.
  Bevorzugt vor OpenWeatherMap, wenn kein Key gewünscht ist.
- **DWD Open Data** — Deutscher Wetterdienst, offene Daten.
- **MeteoAlarm** — EU-Wetterwarnungen (Atom-Feeds). In der App genutzt (`xml`).

## Krisen / Warnungen
- **NINA / BBK** — amtliche Bevölkerungswarnungen Deutschland, *kein Key*
  (`https://nina.api.proxy.bund.dev`). Hochwasser, Zivilschutz, Wetter.
- **MoWaS/Katwarn** — über NINA abgedeckt.

## Marktplatz / Versorgung / Natur
- **Open Food Facts** — Produkt-/Barcode-Lookup, *kein Key*
  (`https://world.openfoodfacts.org`). In Marketplace genutzt (`mobile_scanner`).
- **Tankerkönig** — deutsche Spritpreise *(API-Key, kostenlos)*. Gas-Preise.
- **Open Charge Map** — E-Ladesäulen *(API-Key, kostenlos)* — Alternative/Ergänzung
  zu Overpass.
- **Mundraub** — frei zugängliche Obst-/Sammelstellen. Harvest/Wild genutzt.
- **iNaturalist** / **GBIF** — Arten-Bestimmung & Biodiversität, frei. Identify.
- **Nager.Date** — Feiertage pro Land/Jahr, **kein Key**
  (`https://date.nager.at`). Für Kalender/Events.
- **Bundesagentur für Arbeit – Jobsuche** — Stellen, *(kostenloser Client)*. Jobs.

## Text / Übersetzung / Medien
- **LibreTranslate** — Übersetzung, self-host/freie Instanzen. UI-Texte bleiben
  aber statisch via `easy_localization` (7 JSON-Dateien).
- **DiceBear** (Identicons) / **Pollinations.ai** (KI-Bilder) — *kein Key*,
  bereits im `AvatarGenerator` genutzt.

## Nützliche pub.dev-Pakete (vor Neu-Erfindung prüfen)
Bereits vorhanden u. a.: `flutter_map`, `geolocator`, `geocoding`,
`cached_network_image`, `flutter_markdown`, `share_plus`, `url_launcher`,
`mobile_scanner`, `table`-artige Listen via Standard-Widgets, `confetti`,
`shimmer`/`skeletonizer`, `qr_flutter`, `intl`, `http`.
Für **neue** Bedarfe (immer erst hier + pubspec prüfen): Diagramme → `fl_chart`;
Kalender-Grid → `table_calendar`; reichhaltige Animationen → `flutter_animate`
(rein Dart). Native Pakete = Versions-Bump nötig.
