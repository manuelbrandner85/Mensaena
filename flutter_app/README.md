# Mensaena – Flutter App

Native Flutter-App, die die bestehende Next.js-Web-App **funktional und visuell 1:1** abbildet. Backend bleibt unverändert: Supabase, Cloudflare Workers (`/api/*`-Routes) und LiveKit.

## Architektur-Entscheidungen

| Bereich | Web (Next.js) | Flutter |
|---|---|---|
| State | Zustand-Stores | Riverpod |
| Routing | App Router (`src/app/`) | go_router (`lib/routing/`) |
| Auth/DB | `@supabase/ssr` + RLS | `supabase_flutter` + RLS |
| Realtime | Supabase Realtime | Supabase Realtime (gleicher Channel) |
| API-Routes | `/api/*` auf Cloudflare Workers | unverändert – per Dio-HTTP gerufen |
| Voice/Video | `@livekit/components-react` | `livekit_client` |
| Karte | Leaflet + MarkerCluster | `flutter_map` + `flutter_map_marker_cluster` |
| Push | `@capacitor/push-notifications` | `firebase_messaging` + `flutter_local_notifications` |
| Camera | `@capacitor/camera` | `image_picker` |
| Barcode | `@capacitor-mlkit/barcode-scanning` | `mobile_scanner` |
| Geolocation | `@capacitor/geolocation` | `geolocator` |
| Share | `@capacitor/share` | `share_plus` |
| Filesystem | `@capacitor/filesystem` | `path_provider` |
| Styling | Tailwind | `theme/` mit identischen Tokens |

## Verzeichnisstruktur

```
flutter_app/
├── pubspec.yaml
├── lib/
│   ├── main.dart                  # Entry-Point + ProviderScope
│   ├── config/
│   │   └── env.dart               # Supabase/API/LiveKit Config (--dart-define)
│   ├── theme/
│   │   ├── app_colors.dart        # 1:1 Tailwind-Tokens (primary, ink, stone, …)
│   │   ├── app_typography.dart    # Inter + Playfair Display
│   │   ├── app_shadows.dart       # shadow-soft, shadow-card, shadow-glow
│   │   └── app_theme.dart         # Material3-Theme
│   ├── core/
│   │   ├── supabase.dart          # Supabase-Init + Provider
│   │   ├── api_client.dart        # Dio-Client für /api/*-Calls
│   │   └── livekit.dart           # LiveKit-Service
│   ├── routing/
│   │   ├── routes.dart            # Alle Pfade als Konstanten
│   │   ├── app_router.dart        # go_router-Konfig + Auth-Guard
│   │   └── stub_pages.dart        # Platzhalter für noch zu portierende Module
│   ├── widgets/
│   │   ├── buttons.dart           # btn-primary/secondary/outline/ghost/danger
│   │   ├── cards.dart             # card, card-hover, card-accent
│   │   └── badges.dart            # badge + Notification-Counter
│   ├── navigation/
│   │   ├── nav_config.dart        # Sidebar-Gruppen (= navigationConfig.ts)
│   │   ├── app_shell.dart         # Topbar + Sidebar/BottomNav + Body
│   │   ├── sidebar.dart
│   │   ├── topbar.dart
│   │   └── badge_counts.dart      # Realtime-Badge-Provider
│   └── features/
│       ├── auth/                  # /auth?mode=login|register
│       ├── dashboard/             # /dashboard
│       ├── landing/               # /landing
│       ├── search/                # /search
│       ├── live_ended/            # /live-ended
│       ├── legal/                 # /about, /agb, /datenschutz, …
│       └── …                      # Modul-Stubs (messages, map, crisis, …)
└── .github/workflows/flutter.yml  # CI-Build → Debug-APK Artifact
```

Native Ordner (`android/`, `ios/`) sind in `.gitignore` und werden im CI per `flutter create .` regeneriert. Lokal einmalig:

```bash
cd flutter_app
flutter create --project-name mensaena --org de.mensaena --platforms=android,ios .
flutter pub get
flutter run
```

## Migration-Status (Module)

Module werden iterativ portiert. Status:

- [x] Routing (alle 83 Routen registriert, Sub-Routen mit Parametern)
- [x] Designsystem + Theme + Widgets
- [x] Supabase-Client (Auth, DB, Realtime)
- [x] LiveKit-Service (DM-Calls + Live-Rooms via /api/*-Token)
- [x] API-Client (Dio mit Auto-Bearer)
- [x] Auth-Page (Login/Register)
- [x] App-Shell (Topbar + Sidebar + BottomNav)
- [x] Dashboard-Übersicht (Modul-Grid)
- [ ] Direktnachrichten (DM + LiveKit-Calls)
- [ ] Community-Chat
- [ ] Karte mit Markern + Cluster
- [ ] Hilfe-Posts (Listen, Detail, Erstellen)
- [ ] Krisenberichte (mit RLS-Filter)
- [ ] Veranstaltungen
- [ ] Gruppen
- [ ] Marktplatz / Sharing / Timebank / Housing / Mobility / Jobs
- [ ] Wiki / Knowledge / Skills
- [ ] Profil / Settings / Badges / Calendar
- [ ] Admin-Dashboard
- [ ] Push-Notifications (FCM)
- [ ] Tier-Modul
- [ ] Mental-Support
- [ ] Lebensretter
- [ ] Vorrat / Ernte (Farm-Module)
- [ ] Matching
- [ ] Pinnwand / Challenges

Jedes Modul folgt dem gleichen Muster:
1. **Repository** (`features/<modul>/<modul>_repository.dart`) – kapselt Supabase-Queries, identische Tabellen/Spalten wie Web
2. **Riverpod-Provider** für State + Streams
3. **Page** + **Detail** + **Create** Widgets
4. **Logik 1:1** zur entsprechenden React-Komponente

## Build

```bash
# Lokal (Debug)
flutter run --dart-define=SUPABASE_URL=https://huaqldjkgyosefzfhjnf.supabase.co

# Release-APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=API_BASE_URL=https://www.mensaena.de
```

## Backend bleibt unverändert

- **Supabase**: Projekt `huaqldjkgyosefzfhjnf`, RLS-Policies + Tabellen identisch
- **Cloudflare Workers**: alle 57 `/api/*`-Routen laufen weiter auf `www.mensaena.de`
- **LiveKit**: Token-Generierung über bestehendes Cloudflare-Backend (Secrets nie im Client)
