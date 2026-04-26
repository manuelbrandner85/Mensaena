# INTEGRATIONS.md – Externe Datenquellen

Übersicht aller von MensaEna konsumierten externen APIs. Stand: April 2026.
Spalten: Endpunkt · Key · Rate-Limit · Modul-Datei · Verfügbarkeit · UI-Modul.

> **Konvention:** Alle Implementierungen liegen in `src/lib/api/`. UI-Komponenten
> werden je nach `GeoContext.supportLevel` (`DE | AT | CH | EU | WORLD`) durch
> `getApiAvailability()` aus `src/lib/api/api-router.ts` ein- oder ausgeblendet.

## Verfügbarkeitsmatrix

| #  | Quelle                       | Endpunkt                                                            | Key  | Rate-Limit       | Modul-Datei                          | Verfügbarkeit   | UI-Modul              |
|----|------------------------------|---------------------------------------------------------------------|------|------------------|--------------------------------------|-----------------|-----------------------|
| 1  | Open-Meteo Forecast          | `https://api.open-meteo.com/v1/forecast`                            | nein | ~10 000/Tag      | `src/lib/api/weather.ts`             | Weltweit        | Dashboard, Karte      |
| 2  | Bright Sky (DWD)             | `https://api.brightsky.dev`                                         | nein | unbegrenzt       | `src/lib/api/weather.ts`             | DE              | Dashboard             |
| 3  | Open-Meteo Air Quality       | `https://air-quality-api.open-meteo.com/v1/air-quality`             | nein | ~10 000/Tag      | `src/lib/api/air-quality.ts`         | Weltweit (Pollen EU) | Dashboard       |
| 4  | NINA Bevölkerungsschutz      | `https://nina.api.proxy.bund.dev/api31/`                            | nein | unbegrenzt       | `src/lib/nina-api.ts`                | DE              | Warnungen             |
| 5  | MeteoAlarm                   | `https://api.meteoalarm.org/edr/v1/`                                | nein | 10 Min Aktualisierung | `src/lib/api/meteoalarm.ts`     | EU 38           | Warnungen             |
| 6  | Nager.Date Feiertage         | `https://date.nager.at/api/v3/`                                     | nein | unbegrenzt       | `src/lib/api/holidays-nager.ts`      | Weltweit        | Kalender              |
| 7  | feiertage-api.de (DE)        | `https://feiertage-api.de/api/`                                     | nein | unbegrenzt       | `src/lib/api/holidays.ts`            | DE              | Kalender, Events      |
| 8  | Lebensmittelwarnung BVL      | `https://megov.bayern.de/verbraucherschutz/…`                       | nein | unbegrenzt       | `src/lib/api/foodwarnings.ts`        | DE              | Warnungen             |
| 9  | RASFF EU                     | `https://webgate.ec.europa.eu/rasff-window/…`                       | nein | best-effort (CORS) | `src/lib/api/foodwarnings.ts`     | EU              | Warnungen             |
| 10 | Photon Geocoder              | `https://photon.komoot.io/api/`                                     | nein | ~5/s             | `src/lib/api/geocoder.ts`            | Weltweit        | Überall (Suche)       |
| 11 | Nominatim Reverse Geocoding  | `https://nominatim.openstreetmap.org/reverse`                       | nein | 1/s              | `src/lib/api/nominatim.ts`           | Weltweit        | Überall (Adresse)     |
| 12 | Overpass API (POIs)          | `https://overpass-api.de/api/interpreter`                           | nein | fair-use         | `src/lib/services/overpass.ts`       | Weltweit        | Karte                 |
| 13 | OpenRouteService             | `https://api.openrouteservice.org/v2/`                              | ja*  | 2 000/Tag        | `src/lib/api/routing.ts`             | Weltweit        | Karte                 |
| 14 | Pegelonline                  | `https://www.pegelonline.wsv.de/webservices/rest-api/v2/`           | nein | unbegrenzt       | `src/lib/api/waterlevel.ts`          | DE              | Dashboard, Karte      |
| 15 | BfS ODL (Radioaktivität)     | `https://odlinfo.bfs.de/`                                           | nein | unbegrenzt       | `src/lib/api/radiation.ts` *(geplant)* | DE            | Dashboard, Karte      |
| 16 | Autobahn API                 | `https://verkehr.autobahn.de/o/autobahn/`                           | nein | unbegrenzt       | `src/lib/api/autobahn.ts`            | DE              | Mobility              |
| 17 | Tagesschau Regional News     | `https://www.tagesschau.de/api2u/`                                  | nein | unbegrenzt       | `src/lib/api/news.ts` *(geplant)*    | DE              | Community             |
| 18 | Wikidata SPARQL              | `https://query.wikidata.org/sparql`                                 | nein | fair-use         | `src/lib/api/wikidata.ts`            | Weltweit        | Wiki                  |
| 19 | OpenLibrary Books            | `https://openlibrary.org/search.json`                               | nein | fair-use         | `src/lib/api/books.ts`               | Weltweit        | Knowledge             |
| 20 | OpenFoodFacts                | `https://world.openfoodfacts.org/api/v2/`                           | nein | fair-use         | `src/lib/api/foodfacts.ts`           | Weltweit        | Supply                |
| 21 | Deutsche Digitale Bibliothek | `https://api.deutsche-digitale-bibliothek.de/`                      | ja*  | unbegrenzt       | `src/lib/api/ddb.ts`                 | DE              | Knowledge             |
| 22 | Open-Meteo Geocoding         | `https://geocoding-api.open-meteo.com/v1/search`                    | nein | ~10 000/Tag      | `src/lib/api/citysearch.ts` *(geplant)* | Weltweit     | Überall               |

`*` = Kostenloser Key, optional. Fehlt der Key → Feature wird in der UI versteckt.

## API-Routing

`getApiAvailability(ctx)` liefert für jeden GeoContext eine
`ApiAvailability`-Struktur. Beispiel für `supportLevel: 'DE'`:

```ts
{
  weather:      { primary: 'brightsky', fallback: 'open-meteo' },
  warnings:     { sources: ['nina', 'meteoalarm', 'dwd'] },
  foodWarnings: true,
  wasteCalendar: true,
  holidays:     { api: 'feiertage-api', countryCode: 'DE' },
  airQuality:   true,
  pollen:       true,
  waterLevels:  true,
  radiation:    true,
  autobahn:     true,
  news:         { source: 'tagesschau' },
}
```

Für `WORLD` werden nur Wetter (Open-Meteo) und Feiertage (Nager.Date) aktiviert.

## Caching-Strategie

| Typ                         | Storage          | TTL              |
|----------------------------|------------------|------------------|
| Wetter (Open-Meteo / Bright Sky) | sessionStorage | 30 Min           |
| Luftqualität / Pollen      | sessionStorage   | 30 Min           |
| Warnungen (NINA)           | sessionStorage   | 15 Min           |
| Warnungen (MeteoAlarm)     | sessionStorage   | 15 Min           |
| Lebensmittelwarnungen (BVL)| localStorage     | 2 h              |
| Lebensmittelwarnungen (RASFF) | localStorage  | 1 h              |
| Feiertage (Nager.Date)     | localStorage     | 7 Tage / 24 h    |
| Feiertage (feiertage-api)  | sessionStorage   | 24 h             |
| Reverse-Geocoding (Nominatim) | localStorage  | 7 Tage           |
| Adress-Autocomplete (Photon) | In-Memory (LRU 100) | bis Reload    |
| Country-Reverse (Nominatim Country) | localStorage | 24 h           |

Cache-Schlüssel verwenden gerundete Koordinaten (2 Nachkommastellen) um
Treffer für nahegelegene Anfragen wiederzuverwenden.

## Rate-Limiting

- **Nominatim**: harte Drossel auf 1 req/s über einen modulinternen Singleton-Wait.
- **Overpass**: fair-use; bei 429/503 wird auf den Mirror umgeschaltet.
- **Photon**: keine harte Drossel, ~5 req/s in der Praxis ok; LRU-Cache reduziert Bedarf.
- **OpenRouteService**: 2 000 Directions / 500 Isochrones pro Tag (kostenloser Tier).

## Privacy / GDPR

- Alle externen Aufrufe gehen direkt vom Browser des Users an die Drittanbieter
  (kein Server-Proxy). Drittanbieter sehen daher die IP des Users.
- Der `User-Agent` wird auf `MensaEna/1.0 (https://www.mensaena.de)` gesetzt
  (nominatim und OSM verlangen identifizierende UA).
- Caching geschieht ausschließlich im Browser (session-/localStorage), nicht
  serverseitig.

## Geplante Erweiterungen

Folgende Backend-Module sind referenziert aber noch nicht erstellt
(folgen in separaten PRs):

- `src/lib/api/radiation.ts` (BfS ODL)
- `src/lib/api/news.ts` (Tagesschau Regional)
- `src/lib/api/citysearch.ts` (Open-Meteo Geocoding für CitySearch-Komponente)
- `src/lib/api/waste-collection.ts` (Abfallnavi + Supabase-Fallback)

Sowie folgende UI-Module für bestehende Backends:

- `PoiLayerControls`, `PoiMarker` (Overpass)
- `RoutingPanel`, `RouteLayer`, `IsochroneLayer`, `IsochroneControl` (ORS)
- Widget-Orchestrator (Settings-Modal, Drag-Drop)
