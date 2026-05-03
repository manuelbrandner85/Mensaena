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

### 🚧 Phase 1 – Kommunikation
Module: `messages`, `chat`, `matching`
- Direktnachrichten-Liste + Conversation-Detail
- Realtime-Subscription auf `direct_messages`
- LiveKit-Integration für 1:1-Calls (Audio + Video)
- Community-Chat mit Channels
- Smart-Match-Widget

### 🚧 Phase 2 – Helfen & Finden
Module: `map`, `posts`, `organizations`, `interactions`, `animals`
- Leaflet-Pendant mit `flutter_map` + `flutter_map_marker_cluster`
- Hilfe-Posts (Liste + Detail + Erstellen + AI-Assist via `/api/posts/ai-assist`)
- Organisationen mit Detail-Seite + Suggest-Form
- Interaktions-Anfragen (Annehmen/Ablehnen)
- Tier-Meldungen mit Foto-Upload via Supabase Storage

### 🚧 Phase 3 – Notfall & Sicherheit
Module: `crisis`, `mental-support`
- Krisenberichte mit Geo-Radius-Filter (PostGIS)
- Krisen-Ressourcen-Seite
- Mental-Support-Anfragen (vertraulich, nur eingeloggte User)

### 🚧 Phase 4 – Gemeinschaft
Module: `groups`, `events`, `board`, `challenges`
- Gruppen mit Membership-Flow
- Veranstaltungen + Kalender-Integration
- Pinnwand
- Challenges + Check-In via `/api/challenges/[id]/checkin`

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
