# Migrationsplan: Capacitor → Flutter

## Ausgangslage

Die bisherige "Capacitor-App" ist faktisch eine native WebView-Hülle, die `https://www.mensaena.de` lädt (`capacitor.config.ts` → `server.url`). Es existieren keine eigenständigen Capacitor-Quellen mit Geschäftslogik — die gesamte Logik liegt in der Next.js-App (`src/app/**`, 83 Pages, 164 Components, 57 API-Routes, 3 Zustand-Stores).

## Zielbild

Eigenständige native Flutter-App, die:

- **funktional 1:1** zur Web-App ist (jeder Klick, jeder Status, jede Validierung)
- **visuell 1:1** ist (gleiche Farben, Typografie, Schatten, Spacing, Animationen)
- **dasselbe Backend** nutzt: Supabase-Projekt `huaqldjkgyosefzfhjnf`, Cloudflare Workers (`/api/*`), LiveKit
- **parallel zur Web-App** existiert (`www.mensaena.de` bleibt produktiv)

## Phasen

### ✅ Phase 0 – Fundament (abgeschlossen)
Ergebnis: dieses Commit.
- Projektstruktur, pubspec.yaml, analysis_options
- Designsystem (Theme + Tokens + Widgets)
- Supabase + LiveKit + API-Client
- Routing für alle 83 Routen (mit dynamischen Sub-Routen)
- Auth-Flow (Login/Register)
- App-Shell (Topbar + Sidebar + BottomNav)
- Dashboard-Übersicht
- CI-Workflow (Flutter Android Debug-APK)

### Phase 1 – Kommunikation
Module: `messages`, `chat`, `matching`

**Phase 1a (✅ abgeschlossen):**
- DM-Repository (`features/messages/messages_repository.dart`) mit Conversations,
  Messages, Realtime-Subscription auf `messages` (filter conversation_id)
- Conversation-Liste (`features/messages/messages_page.dart`) – sortiert nach
  letzter Nachricht, Unread-Badge pro Eintrag
- Thread-View (`features/messages/conversation_page.dart`) – Bubbles,
  Tagestrenner, Auto-Scroll, optimistic-send + Realtime-Append, mark-as-read
  beim Öffnen, sender-Profile via Foreign-Key-Join
- `markAsRead` aktualisiert `conversation_members.last_read_at`
- `findOrCreateDirectConversation`-Helper für DM-Start aus Profil

**Phase 1b (✅ abgeschlossen):**
- DM-Call-Repository (`features/calls/calls_repository.dart`) mit allen
  `/api/dm-calls/{start,answer,end,decline,missed,cancel}`-Aufrufen sowie
  Realtime-Streams auf `dm_calls` (incoming für `callee_id=me`,
  status='ringing', 45s-Fenster + Update-Stream je Call).
- IncomingCallPage (Pendant zu IncomingCallScreen.tsx) mit Annehmen/Ablehnen,
  45s-Timeout, periodischer Vibration als Klingel-Substitut.
- OutgoingCallPage (Pendant zu OutgoingCallScreen.tsx) – startet Call,
  wartet via Realtime auf `active`/`declined`, holt LiveKit-Token,
  Auto-Missed nach 45s.
- ActiveCallPage (Pendant zu LiveRoomModal.tsx) mit Mic/Cam/Speaker-Toggles,
  Hangup, Peer-Video-Render, Self-Preview, Anrufdauer-Timer.
- GlobalCallListener (Pendant zu GlobalCallListener.tsx) ist in AppShell
  eingehängt → eingehende Calls öffnen IncomingCallPage automatisch.
- Audio/Video-Buttons in `ConversationPage`-AppBar (Sprach- und Videoanruf).

**Phase 1b – noch offen (Phase 8/Native):**
- Echter Klingelton/Wählton via `audioplayers` (aktuell nur Vibration)
- Call-History-Liste als eigener Tab unter `/dashboard/messages`
- DND-Modus (auto-decline mit `reason='dnd'`)
- Native Full-Screen-Intent auf Android-Lockscreen

**Phase 1c (✅ teilweise abgeschlossen):**
- Community-Chat (`/dashboard/chat`) mit Channels: Channel-Sidebar, Message-Thread,
  Reply-To, Emoji-Reactions (message_reactions), Realtime-Append
- Smart-Match-Widget (`/dashboard/matching`): Match-Liste via get_my_matches RPC,
  Accept/Decline via respond_to_match RPC, Chat-Navigation nach Accept

**Phase 1c – noch offen:**
- Voice-Recorder (Pendant zu VoiceRecorder.tsx)
- Live-Room-Modal (Audio-Räume mit mehreren Teilnehmern via LiveKit)
- Pin-Nachrichten-UI (message_pins Tabelle bereits unterstützt im Repository)

### Phase 2 – Helfen & Finden
Module: `map`, `posts`, `organizations`, `interactions`, `animals`

**Phase 2a (✅ Posts):**
- Post-Repository (`features/posts/posts_repository.dart`) mit Liste, Detail,
  Create, Status-Update, Delete + Geo-Bbox-Filter (Fallback ohne PostGIS-RPC)
- Posts-Liste (`features/posts/posts_page.dart`) mit Type-Filter, Volltext-
  Suche (debounced 350ms), Pagination (20er-Seiten via Range), Pull-to-Refresh
- Post-Detail (`features/posts/post_detail_page.dart`): Header, Author-Block,
  Beschreibung, Media-Strip, Tags, Meta-Card mit klickbaren Kontakten
  (tel:, mailto:, wa.me) + „Anschreiben"-Button (DM via findOrCreateDM)
- Post-Create (`features/posts/create_post_page.dart`): Type-Picker, Titel,
  Beschreibung, Ort, Tags, Dringlichkeit (1–5), Anonym-Schalter

**Phase 2b (✅ Map + Interactions):**
- Karte (`features/map/map_page.dart`) mit `flutter_map` + OSM-Tiles +
  `MarkerClusterLayerWidget` (Cluster-Pattern wie Web), GPS-Permission +
  Recenter-FAB, Radius-Picker (5/10/25/50/100 km), Type-Emoji-Marker
- Interaktions-Repository (`features/interactions/interactions_repository.dart`)
  mit `get_my_interactions`-RPC + respond/start/complete/cancel-Mutationen
- Interaktions-Liste (`features/interactions/interactions_page.dart`):
  Filter-Chips, Status-Badge, Partner-Avatar, Post-Referenz-Block,
  kontextsensitive Action-Buttons (Annehmen/Ablehnen → Starten/Abbrechen
  → Abschließen) + Chat-Sprung

**Phase 2c (✅ Organizations):**
- Organisations-Repository (`features/organizations/organizations_repository.dart`)
  mit `list/fetch/suggest` über `organizations` + `organization_suggestions`
- Liste (`organizations_page.dart`): Volltext-Suche (debounced),
  15 Kategorie-Chips, „Verifiziert"-Filter, Pagination via Range
- Detail (`organization_detail_page.dart`): Cover/Logo, Verified-Badge,
  Beschreibung, klickbare Kontakt-Card (Adresse → Google Maps,
  tel:/mailto:/Web), Services/Zielgruppen/Sprachen-Chips, Öffnungszeiten
- Suggest-Form (`organization_suggest_page.dart`): Kategorie-Picker,
  Pflichtfelder Name/Stadt, optionale Adresse/PLZ/Tel/Mail/Web/Beschreibung,
  Validation, schreibt nach `organization_suggestions` mit `status='pending'`

**Phase 2d (✅ Animals + AI-Assist):**
- Animals-View (`features/animals/animals_page.dart`): Stats-Grid (Vermisst/
  Gefunden/Pflege/Notfälle) + gefilterte Post-Liste (type='animal' oder
  rescue/crisis mit category='animals')
- AI-Assist im Create-Post (`features/posts/create_post_page.dart`):
  Eingabefeld + KI-Button → POST /api/posts/ai-assist (Cloudflare Workers
  AI mit llama-3.3-70b), liefert 3 Titelvorschläge + Beschreibung; Bottom-
  Sheet zur Auswahl, fehlende Felder werden automatisch befüllt
- `posts_repository.aiAssist()` als typed Wrapper über apiClient.post

**Phase 2e – noch offen:**
- Tier-Meldungen mit Foto-Upload via Supabase Storage

### Phase 3 – Notfall & Sicherheit
Module: `crisis`, `mental_support`

**Phase 3 (✅ abgeschlossen):**
- Crisis-Repository (`features/crisis/crisis_repository.dart`):
  list/fetch/create + helpersFor + offerHelp/withdrawHelp + markResolved
- Crisis-Liste (`crisis_page.dart`): zwei Filter-Reihen (Kategorie 11×,
  Dringlichkeit 4×), urgency-coloured Border-Left, Helfer-Counter
- Crisis-Detail (`crisis_detail_page.dart`): Header mit Kategorie/Urgency/
  Status-Chips, Beschreibung, Bilder-Strip, Meta-Card mit Google-Maps-Link,
  Skills/Resources-Chips, Helfer-Liste, Hilfe-anbieten-Dialog mit Message
- Crisis-Create (`crisis_create_page.dart`): Banner mit 112-Hinweis,
  Kategorie-Picker, Dringlichkeit-Pillen, Number-Stepper für Radius/
  Betroffene/Helfer, Anonym-Toggle, rote „Veröffentlichen"-Button
- Crisis-Resources (`crisis_resources_page.dart`): 5 Notruf-Nummern
  (112/110/144/122 + Vergiftung) + 6 Beratungs-Hotlines (TelefonSeelsorge,
  Rat auf Draht, Frauen-Helpline, Hilfetelefon)
- Mental-Support (`mental_support_page.dart`): Hotlines gruppiert nach
  DE/AT/CH (verifizierte Quellen: telefonseelsorge.de/at, 143.ch,
  rataufdraht.at), tap → tel: launch
- Routing: /dashboard/crisis (+ /:id, /create, /resources) und
  /dashboard/mental-support verdrahtet (Mental-Support-Create vorerst Stub)

### Phase 4 – Gemeinschaft
Module: `groups`, `events`, `board`, `challenges`

**Phase 4 (✅ MVP abgeschlossen):**
- Groups (`features/groups/`): models (10 Kategorien), repository
  (list/fetch/join/leave + myGroupIds), Liste mit Kategorie-Filter +
  Beitreten-Buttons, Detail mit Cover/Logo + Beitreten-Action
- Events (`features/events/`): models (8 Kategorien, AttendeeStatus),
  repository (upcoming/fetch/setAttendance/withdraw), Liste gruppiert
  nach Datum + Status-Badges, Detail mit Meta-Card + RSVP-Buttons
  (Bin dabei / Vielleicht / Nein)
- Board (`features/board/`): models (8 Kategorien, 6 Farben), repository
  (list/create/delete), Pinnwand-Grid mit Post-it-Look + Bottom-Sheet
  zum Erstellen mit Farbpicker
- Challenges (`features/challenges/`): models (Difficulty), repository
  mit Check-In-API-Call (POST /api/challenges/[id]/checkin), Liste mit
  Difficulty-Badge + Punkte + Datumsspanne + Mitmachen/Check-In-Buttons
- Routing: alle 4 Module verdrahtet, Create-Pages noch Stubs (folgen)

**Phase 4 – noch offen:**
- Group-Posts (innerhalb einer Gruppe)
- Event-Recurring-Patterns
- Board-Pin/Unpin (Admin-Feature)
- Challenge-Detail mit Progress-Verlauf

### 🚧 Phase 5 – Teilen & Ressourcen
Module: `sharing`, `timebank`, `marketplace`, `supply`, `harvest`, `rescuer`, `housing`, `mobility`, `jobs`
- Listing-Pattern (Liste + Filter + Detail + Erstellen) für jedes Modul
- Zeitbank mit Kontostand (`/api/zeitbank/balance`)
- Farm-Subseiten unter `supply/farm/[slug]`
- Job-Listings (`/api/jobs`)

### 🚧 Phase 6 – Wissen
Module: `wiki`, `knowledge`, `skills`
- Wiki mit Markdown-Rendering (`flutter_markdown`)
- Bildungs-Inhalte
- Skills-Anbieter-Profil

### 🚧 Phase 7 – Mein Bereich
Module: `profile`, `settings`, `invite`, `badges`, `calendar`, `notifications`
- Profil-Bearbeitung mit Avatar-Upload
- Settings mit Push-Toggle, Sprache, Privacy
- Einladungs-Codes
- Badge-Sammlung
- Persönlicher Kalender
- Notifications-Liste mit Mark-as-read

### 🚧 Phase 8 – Native Features
- FCM-Push (`firebase_messaging`)
- Background-Location für Krisen-Alerts
- Barcode-Scanner für Lebensmittel-Warnungen (`/api/foodwarnings`)
- Camera + Gallery-Picker
- Share-Sheet
- Deep-Links (`de.mensaena.app://`)

### 🚧 Phase 9 – Admin
Module: `admin`
- Admin-Dashboard mit User-Mgmt, Moderation, Content-Approval
- Rollen-Check via `app_metadata.role === 'admin'`

### 🚧 Phase 10 – Release
- App-Icon, Splash-Screen
- Signed Release-APK + AAB
- Play Store Listing
- iOS Build-Config
- Beta via TestFlight + Internal Testing

## Mapping: Web-Komponente → Flutter

| Web (React) | Flutter |
|---|---|
| `<button className="btn-primary">` | `BtnPrimary(label: …, onPressed: …)` |
| `<div className="card card-hover">` | `AppCard(onTap: …, child: …)` |
| `<input className="input">` | `TextFormField(decoration: …)` (Theme-aware) |
| `<span className="badge-green">` | `AppBadge(color: BadgeColor.green)` |
| `useRouter().push('/x')` | `context.go('/x')` |
| `createBrowserClient(…)` | `Supabase.instance.client` |
| `useEffect(() => fetchData())` | `FutureProvider` / `StreamProvider` |
| `Zustand store` | `StateNotifier` / `Notifier` |
| `Toast.success(…)` | `Fluttertoast.showToast(…)` |
| `<Image />` (next/image) | `CachedNetworkImage` |
| `<Map />` (Leaflet) | `FlutterMap` |

## Konventionen

- **Pfade in `Routes.*`** halten den Single Source of Truth (entspricht dem `path`-Feld in `navigationConfig.ts`).
- **DB-Spalten/Tabellen** werden niemals umbenannt – Flutter und Web teilen sich dieselbe Supabase-DB.
- **API-Endpoints** in `core/api_client.dart` werden als String-Konstanten oder direkt referenziert; Logik liegt im Backend (`/api/*`), nicht im Client.
- **Strings auf Deutsch**, später per `flutter gen-l10n` lokalisierbar.
- **Keine eigene Business-Logik im Client** – Datenmutationen laufen entweder direkt über `supabase.from()` oder über `/api/*` (für Sachen, die ein Server-Secret brauchen, z. B. LiveKit-Token).

## Was niemals geändert wird

- Supabase-Schema, RLS-Policies, Tabellen, Funktionen
- Cloudflare-Workers-Routen (`/api/*`)
- LiveKit-Cloud-Konfiguration
- DB-Migrationen (`supabase/migrations/`)
- Web-App (`src/app/**`, läuft parallel weiter)
