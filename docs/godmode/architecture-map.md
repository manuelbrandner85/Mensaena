# Godmode Architektur-Map

**Diese Datei ist die zweite Pflicht-Referenz für den Admin-Dev-Agent** (neben
`conventions.md`). Sie beschreibt WO Code hingehört und WIE die zentralen
Systeme zusammenspielen — damit der Agent Architektur-Entscheidungen trifft,
statt bei jeder Aufgabe die Struktur neu zu erraten. Bei Widerspruch zwischen
dieser Datei und dem tatsächlichen Code: **Code gewinnt** — kurz per Grep
verifizieren, diese Datei ggf. nachziehen (siehe „Pflege" unten).

## 1. Verzeichnis-Konvention

```
lib/config/        Theme, Routen, Motion-Konfiguration
lib/models/        Datenmodelle (.fromJson()/.toJson()), KEINE Business-Logik
lib/providers/      Riverpod — der GESAMTE App-State lebt hier
lib/repositories/   Supabase-Zugriffsschicht (query/mutation) — EINZIGER Ort
                    für sb.from(...); screens/widgets rufen NUR Repositories
lib/screens/        Ganzseitige Widgets (dashboard/, legal/, misc/, public/, shared/)
lib/services/       Singletons (Supabase-Client, Location, Notifications, …)
lib/utils/          Helfer/Validatoren/Formatter
lib/widgets/         Wiederverwendbare UI-Komponenten, nach Domäne sortiert
```

**Neues Modul X folgt diesem Muster:**
- `lib/screens/dashboard/x/x_screen.dart` (+ weitere Screens im selben Ordner)
- `lib/repositories/x_repository.dart` — Query/Mutation-Schicht
- `lib/providers/x_provider.dart` — Riverpod-State (meist
  `FutureProvider.autoDispose` oder `StreamProvider.autoDispose`, ggf. `.family`)
- `lib/widgets/x/` — modul-eigene Komponenten (nur hier verwendet)
- `lib/models/x.dart` — Datenmodell

Keine eigene „Controller"-Schicht — State-Vermittlung läuft ausschließlich
über Riverpod (`FutureProvider`, `StreamProvider`, `StateNotifierProvider`,
`Provider` für abgeleiteten State).

`lib/widgets/` Unterordner-Konvention:
- `widgets/shared/` — modulübergreifend (Buttons, Cards, Snackbars, Skeletons)
- `widgets/{module}/` — nur für dieses Modul
- `widgets/effects/` — Cinema-Overlay-Ebenen, Animationen, A11y-Overlays
- `widgets/layouts/` — Seiten-Templates (`DashboardScaffold`, `ReadableWidth`)

## 2. Module unter `lib/screens/dashboard/`

Alle aktuell fertig implementiert, außer explizit markiert. Bei neuen
Aufträgen zu einem Modul: erst hier den Zweck verifizieren, dann gezielt in
`{module}_repository.dart` / `{module}_screen.dart` einlesen.

| Modul | Zweck |
|---|---|
| admin | Admin-Dashboard: Usermanagement, Moderation, KI-Aufsicht, Crash-Logs, Zeitbank-Admin |
| badges | Abzeichen-Galerie, rückwirkende Vergabe |
| board | Community-Board / Forum-Posts |
| call | Geplante Anrufe, Mailbox |
| challenges | Tages-/Wochen-Challenges, Leaderboard, Streaks |
| chat | DMs + Channels, KI-Chat, Moderation |
| create | Post-Erstellungs-Wizard (Typ-Auswahl, Bild-Upload, Modul-Routing) |
| crisis | SOS-Alarme, Notfallkontakte, Mental-Health-Ressourcen (KEINE Cinema-Effekte) |
| events | Event-Liste, RSVP, Kalender |
| groups | Gruppen-Entdeckung, Beitritt, gruppen-interne Posts |
| harvest | Wildfrüchte-Karte (OSM Overpass, Viewport-Live-Fetch) |
| home | Dashboard-Startseite: Stats, Wetter, SmartMatch, Nearby-Feed |
| invite | Einladungslinks, Referral-Tracking |
| jobs | Länderspezifische Job-Portale (kuratierte Links, EURES-API-Fallback) |
| knowledge | Wissensdatenbank, Wiki-Artikel, Suche |
| live | Livestream-Räume (alle können publishen), Glass-Card-Tiles |
| marketplace | Anzeigen (Kaufen/Verkaufen/Verschenken/Tauschen), Karte, Favoriten |
| matching | SmartMatch-Algorithmus, swipebare Karten |
| mental_support | Krisen-Hotlines (DE/AT/CH), verifizierte Quellen |
| mobility | Fahrgemeinschaften (Route + Erstellung, Wochentag+GPS+Adresse) |
| module | Generisches Scaffolding — `ModuleQuickAction`-Launcher (~20 Module teilen sich `ModulePostsScreen`) |
| oepnv | ÖPNV-Verbindungen via Transitous/MOTIS (kostenlos), Geocoding via Nominatim |
| organizations | Organisations-Entdeckung, Mitgliedschaft, org-interne Posts |
| safety | Sicherheitstipps, Block/Unblock, Notfallkontakte |
| skills | Skill-Profil, Endorsements, Zeitbank-Matchmaking |
| species | Foto-Bestimmung (Tiere/Pflanzen) via iNaturalist CV-API |
| strompreise | Stündliche Strompreise DE-LU via Energy-Charts (Fraunhofer ISE, kostenlos) |
| supply | Versorgung/Ressourcen-Teilen, Filter nach Typ/Standort |
| teilen | Hub-Screen: Verschenken/Verleihen · Verkaufen/Tauschen · Zeitbank |
| warnungen | Lebensmittel-Warnungen (BVL-Public-API, kein Server-Proxy nötig) |
| weather | Aktuelles Wetter, Vorhersage, Warnungen — Basis für Cinema-Wetter-Ebenen |
| wissen | Hub-Screen: Tiere · Pflanzen · Guides |

(`admin`, `module`, `create`, `invite` sind Infrastruktur/Shell, keine
fachlichen Endnutzer-Module — daher in der Deep-Scan-Modul-Matrix
ausgeschlossen.)

## 3. Datenzugriff & Realtime-Patterns

**Drei Provider-Muster, je nach Datenart:**

1. **One-Shot** — `FutureProvider.autoDispose<T>`: einmaliger Abruf, disposed
   sich, sobald niemand mehr zuhört.
2. **Realtime** — `StreamProvider.autoDispose<List<T>>`: Repository liefert
   `Stream` aus `sb.from(table).stream(primaryKey: ['id'])`, Provider reicht
   sie durch. IMMER `.limit(N)` im Repository (Guard `check_stream_limits.py`).
   Beispiel: `EmergencyRepository.watchNearby()` → `.eq('status','active')
   .limit(150).map(...)`.
3. **Parametrisiert** — `FutureProvider.family.autoDispose` /
   `StreamProvider.family.autoDispose` für Queries mit Argument (z. B. Posts
   nach `pollId`).

`StateNotifierProvider` für mutablen State (z. B. `CinemaIntensityNotifier`,
`A11yNotifier`). `Provider` für abgeleiteten/kombinierten State (z. B.
`effectsProfileProvider` kombiniert 5 Signale).

**RLS**: läuft serverseitig über Supabase Policies — kein expliziter
Permission-Check im Flutter-Code nötig, aber Repository-Kommentare wie
`// SELECT-RLS filtert <500 m` dokumentieren die Erwartung. Edge Functions
prüfen `role` explizit vor INSERT/UPDATE (z. B. `send-push-campaign` prüft
`role === 'admin'`).

## 4. Cinema-/Effekte-System — Gate-Hierarchie

```
effectsProfileProvider (lib/providers/effects_gate_provider.dart)
├─ reduceMotion (A11y/Senior)         → hart: EffectsProfile.none
├─ effectsSafetyCap (Jank ODER RAM>85%) → deckelt full → reduced
├─ forceFullEffectsProvider (User-Override) → full TROTZ Lite, aber safetyCap bleibt
├─ liteModeActiveProvider (ARM32/Android<9) → max reduced (oder none bei minimal)
└─ cinemaIntensityProvider (User-Setting full/reduced/minimal) → 1:1 Mapping
```

`CinemaOverlay` (lib/widgets/effects/cinema_overlay.dart) rendert:
- **Hinter dem Content**: Mesh-Gradient-Drift, Wolken, Starfield, God-Rays,
  Sky-Body (Sonne/Mond), Lens-Flare, Light-Leaks, Dust, Tiefen-Haze, Nebel,
  Regenschleier, Gewitter-Tint.
- **Über dem Content** (immer sicher, nie Lesbarkeits-Verlust): Film-Grain
  (subtil), Vignette (nur Eck-Falloff), Chromatic Aberration (nur Randpixel).

**Wichtiges Architektur-Prinzip (aus Bugfix 2026-06-24):** Der
Live-Wetter-Hintergrund hat einen EIGENEN Schalter
(`cinemaWeatherAdaptiveProvider`, Default an) und ist bewusst vom
Cinema-Master-Gate ENTKOPPELT — er wird über `_weatherOnlyOverlay` auch
gerendert, wenn das große Kino-Gate aus ist. Animierte Wetter-Ebenen
respektieren trotzdem Lite-Mode/A11y (Crash-Schutz geht vor); Farb-Tint/Mood
(reine ColoredBox/Gradient-Ebenen ohne AnimationController) laufen immer.
**Regel für neue Ambient-Features mit eigenem Schalter: genauso verfahren**
— siehe „Bewährte Patterns" in `conventions.md`.

Wetter-Ableitung (`lib/providers/cinema_provider.dart`):
`cinemaWeatherNowProvider` (15-Min-Refresh, Open-Meteo, Standort = Profil ODER
GPS-Fallback) → `cloudColorOf()`, `rainVeilFor()`, `thunderMoodColor()`,
`weatherParticleSpec()`, skaliert nach gemessenem Niederschlag/Schneefall.

Phasen (`lib/config/theme/cinema_theme.dart`): dawn/morning/day/dusk/evening/
night, gesteuert über `effectiveCinemaPhaseProvider`
(auto/forceNight/forceDay/forceDusk/off). Sonnen-/Mond-Position folgt der
echten Sonnenzeit via `cinemaSkyBodyAlignmentProvider` (Fallback: statische
Phasen-Position).

## 5. Auth & Rollen

- Aktueller Nutzer: `SupabaseService.currentUser` (sync) bzw.
  `currentUserProvider` (reaktiv, `lib/providers/role_provider.dart`).
- Rollen-Cache: `UserRoleCache` (statisch, für `GoRouter.redirect` im Sync-
  Kontext), `reload()` bei Login/Logout. Rollen: `user | moderator | admin`.
- Helfer: `UserRoleCache.isAdmin`, `UserRoleCache.isModerator`.
- Edge Functions prüfen die Rolle IMMER serverseitig zusätzlich (Flutter-Check
  allein reicht nie für sicherheitsrelevante Aktionen).

## 6. Push-Notifications

- **Versand**: Edge Function `send-push-campaign` → Query `profiles` (Opt-in +
  Segment) → Insert in `notifications` → Postgres-Trigger →
  `send_push_notification()` RPC → FCM-Token aus `fcm_tokens` → Firebase Admin
  SDK.
- **Vordergrund** (App offen): `FirebaseMessaging.onMessage` →
  `_handleForegroundMessage()` (nutzt `data`-Payload, nicht
  `notification.title` — stabiler auf Android) → lokale Notification via
  `flutter_local_notifications`.
- **Hintergrund**: Android zeigt die native Notification selbst;
  `onMessageOpenedApp` beim Tap → `NotificationRouter.navigateFromPush()` →
  Deep-Link-Routing.
- **6 Android-Channels**: `mensaena_default`, `_calls` (MAX, Fullscreen),
  `_crisis` (MAX), `_chat` (HIGH+Sound), `_social` (DEFAULT), `_system` (LOW,
  stumm). Neue Benachrichtigungsart → passenden Channel wählen, nicht
  `_default` missbrauchen.

## 7. i18n-Struktur

`assets/translations/{de,en,it,es,fr,tr,ru}.json` — flaches JSON, Top-Level-
Namespace pro Feature/Screen (aktuell ~140 Namespaces, z. B. `common`, `nav`,
`navGroups`, `auth`, `profile`, `settings`, `chat`, `errors`, `onboarding`,
`marketplace`, `events`, `crisis`, `skills`, `adminDev`, `weather`, …). Neuer
Screen → eigener Top-Level-Key. Vollständige, aktuelle Liste: `de.json` ist
die Quelle der Wahrheit — bei Bedarf direkt nachschlagen statt raten.

## Pflege

Ändert ein Auftrag die Architektur spürbar (neues Modul, neue zentrale
Provider-Kette, neues Gate-Prinzip), ergänzt der Agent diese Datei knapp im
selben PR — insbesondere neue Einträge in Abschnitt 2 (Module) und
Architektur-Prinzipien in Abschnitt 4 (Cinema) oder vergleichbaren Systemen.
