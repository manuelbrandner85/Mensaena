# MENSAENA – TODO
> Aktualisiert: 2026-04-24 (Deploy + APK + TypeScript-Fixes)
> JEDER Prompt = diese Datei updaten. KEINE AUSNAHME.
> [x]=done []=open [SQL]=User führt SQL aus [!]=kritisch

## CACHE
OPEN=(keine kritischen)
COUNT=200+ (alle kritischen erledigt)
NEXT=Phase 2 Features
LAST_SESSION=2026-04-24
LAST_TASK=Deploy www.mensaena.de (Cloudflare Workers) + Android APK-Build (GitHub Actions) + 64 TypeScript-Fehler behoben + Capacitor Android-Setup

## Sofort-Massnahmen Top 5
- [x] [!] A1 – CreatePostModal: Koordinaten+location_text+Bild-Upload+Rate-Limiting (alle 12+ Module)
- [x] [!] A5 – Umlaut-Korrektur projektweit (~80+ Stellen in 55+ Dateien, 2 Durchläufe, 0 verbleibend) + Runde 4: 185 Unicode-Escapes in 35 Dateien + Runde 5: 13 weitere Umlaute in 9 Dateien (AGB, Settings, Ratings, Matching, Orgs, PostCard, PostDetail, post-types)
- [x] [!] A4 – Navigation-Redesign v2: navConfig.ts exakt 6 Gruppen + Admin, Sidebar interner NavGroup (expanded collapsible + collapsed flyout), BottomNav Custom-Sheet (collapsible SheetGroups, Notification-Badge, auto-close, slide-up 300ms)
- [x] [!] B1+B2 – Admin-Dashboard: Edit-Modals + Kaskaden-Delete + ReportsTab + Detail-Links
- [x] [!] C1+D1 – Moderator-Zugang, Middleware Auth+Admin-Guard, User-Enum-Fix, CSV-Leak-Fix

## A – Kritische Nutzer-Erlebnis-Probleme
- [x] [!] A1.1 ModulePage CreatePostModal: Koordinaten (latitude/longitude via Geolocation) + Standort-Button
- [x] [!] A1.2 ModulePage CreatePostModal: location_text im Insert
- [x] [!] A1.3 ModulePage CreatePostModal: Bild-Upload (post-images Bucket, Vorschau, 10MB Limit)
- [x] [!] A1.4 ModulePage CreatePostModal: Rate-Limiting (checkRateLimit, 2/min, 10/h)
- [x] A2.1 Karte: MapComponent nutzt korrekt post.latitude/post.longitude (verifiziert)
- [x] A2.3 Leaflet-CSS prüfen → OK: @import 'leaflet/dist/leaflet.css' in globals.css
- [x] A3.1 Chat-Tabellen: ChatView Spalten-Fixes (chat_banned_users.expires_at safe select, message_pins ohne conversation_id/created_at, Realtime-Filter angepasst) → [docs/A3_1_CHAT_TABLES.md](docs/A3_1_CHAT_TABLES.md)
- [x] [!] A4 Navigation-Redesign v2: Clean Rewrite – Sidebar.tsx interner NavGroup (expanded/collapsed), BottomNav.tsx Custom-Sheet ohne MobileSheet-Dep, SidebarGroup.tsx nun unused (Logik in Sidebar.tsx)
- [x] [!] A5 Umlaut-Fehler: ~80+ Stellen in 55+ Dateien korrigiert (2 Durchläufe, 0 verbleibend)
- [x] A6 search_posts RPC erstellt (search_posts + search_board_posts in Migration 034) + Fallback im Frontend
- [x] A7 Modul-spezifische Fehler: useDashboard bot_scheduled_messages (content statt message_content, status statt sent, kein user_id); Tiere+Wohnen OK (moduleFilter korrekt) → [docs/A7_MODULE_BUGS.md](docs/A7_MODULE_BUGS.md)
- [x] A8 Profil UseEffect: verifiziert OK (Zustand-Store stabil, eslint-disable korrekt, lädt einmal bei Mount)
- [x] A9 /search Redirect-Seite erstellt, /about+/kontakt+/nutzungsbedingungen existieren (alle 200)
- [x] A10 UI/UX: BottomNav mit Mehr-Sheet in AppShell eingebunden, pb-20 für Content, lg:hidden für Desktop
- [x] A11 Performance: Dashboard Promise.allSettled (15 Queries parallel, OK), Google-Fonts via next/font (OK), bot_scheduled_messages-Query repariert → [docs/A11_PERFORMANCE.md](docs/A11_PERFORMANCE.md)

## B – Admin-Dashboard
- [x] [!] B1.1 PostsTab: Edit-Modal (Titel, Status, Dringlichkeit)
- [x] [!] B1.2 EventsTab: Edit-Modal (Titel, Status)
- [x] [!] B1.3 BoardTab: Edit-Modal (Inhalt, Kategorie, Status)
- [x] B1.4 CrisisTab: Edit-Modal (Status, Severity)
- [x] [!] B1.5 OrgsTab: Edit-Modal (Name, Kategorie, Verify-Toggle)
- [x] B1.6 FarmsTab: Edit-Modal (Name, Stadt)
- [x] B1.7 ChatModTab: Lock/Unlock, Ban/Unban, Hard-Delete
- [x] B1.8 UsersTab: Role-Change, Delete
- [x] [!] B2.1 PostsTab: Detail-Link funktioniert (/dashboard/posts/[id] existiert mit SSR Metadata)
- [x] [!] B2.2 Kaskaden-Delete: PostsTab löscht interactions, saved_posts, comments, votes, shares, reports vor Post
- [x] [!] B2.2b EventsTab: Kaskaden-Delete löscht attendees, volunteer_signups, reports vor Event
- [x] B2.4 Spalten-Mismatch behoben: OrgsTab (slug entfernt, verified→is_verified, rating_avg/count→is_active), AdminTypes.AdminOrg angepasst, OrgStore Fallback-Query (cat→category, desc→description, verified→is_verified, slug→id Lookup), CrisisTab war korrekt (category/urgency) → [docs/B2_4_MISSING_COLUMNS.md](docs/B2_4_MISSING_COLUMNS.md)
- [x] Doku: 4 Markdown-Dateien erstellt (docs/A3_1_CHAT_TABLES.md, A7_MODULE_BUGS.md, A11_PERFORMANCE.md, B2_4_MISSING_COLUMNS.md), AI_CONTEXT.md Schema-Korrekturen (chat_banned_users, message_pins, chat_channels, organization_reviews)
- [x] B2.4b organization_reviews.org_id -> organization_id (3 Stellen in useOrganizationStore.ts: loadReviews, loadMoreReviews, createReview)
- [x] [SQL] B2.7 system_cleanup RPC erstellt (Rate-Limits, alte Notifications, Reports, expired Matches)

## C – Moderator-System
- [x] [!] C1.1 Guard prüft admin+moderator, Moderator sieht reduzierte Tabs (kein Users/System)
- [x] C1.2 Rechte-System: Admin sieht alle Tabs, Moderator sieht reduzierte Tabs (implementiert in admin/page.tsx)
- [x] C1.3 Rollen-Dropdown: funktioniert in UsersTab (select mit handleChangeRole, Zeile 182-190)
- [x] C2.1 content_reports Tabelle existiert, ReportsTab im Admin hinzugefügt (11. Tab)
- [x] C2.2 Meld-Button (ReportButton.tsx) in PostCard integriert, schreibt in content_reports
- [x] C2.3 ReportsTab im Admin: Suche, Status-Filter, Detail-Modal, Status-Änderung, Löschen
- [x] C3.1 User-Ban: is_banned, banned_until, ban_reason in profiles; Ban/Unban-Button in UsersTab; visueller Indikator
- [x] [SQL] C4 audit_logs Tabelle + AuditLogViewer im SystemTab (actor, action, target, details, created_at)

## D – Sicherheit
- [x] [!] D1.1 Supabase-Anon-Key: Security-Kommentar hinzugefügt (public key by design, RLS controls access)
- [x] D1.2 Storage-RLS: 28 aktive Policies (verifiziert via AI_CONTEXT.md); chat-images private, rest public
- [x] D1.3 Middleware: Server-Side Auth für /dashboard/* (redirect to /auth wenn nicht eingeloggt)
- [x] D1.4 Admin-Prüfung server-seitig: Middleware prüft /dashboard/admin → nur admin/moderator
- [x] D1.5 Rate-Limit Fail-Open: Dokumentiert in rate-limit.ts (design decision, Supabase RLS enforces)
- [x] D1.6 Login User-Enumeration: Generische Fehlermeldung ("E-Mail oder Passwort falsch")
- [x] D1.7 Passwort vergessen: `/auth?mode=forgot` + `/auth?mode=reset` (resetPasswordForEmail, updateUser, PASSWORD_RECOVERY Listener, Bestätigung, Stärke-Checks, E-Mail-Enumeration-Schutz, Redirects /passwort-vergessen + /passwort-zuruecksetzen)
- [x] D1.9 CSV-Export-Leck: Telefon+E-Mail aus Export entfernt, nur öffentliche Betriebsdaten

## E – Code-Qualität
- [x] E1 React 19 vs @types/react: @types/react+@types/react-dom auf ^19 aktualisiert
- [x] E2 Playwright: von dependencies nach devDependencies verschoben
- [x] E3 Error-Boundary: app/error.tsx + dashboard/error.tsx existieren (verifiziert)
- [x] E4 Zwei State-Systeme: Dokumentiert in useStore.ts (design decision, verschiedene Verantwortungen)
- [x] [SQL] E5 8+1 Tabellen: crisis_helpers, crisis_updates, emergency_numbers (24 Seeds), match_preferences, organization_review_helpful, organization_suggestions, post_reactions, reports, audit_logs. 7 RPCs: search_posts, search_board_posts, check_rate_limit, admin_delete_post/event/board_post/crisis, run_scheduled_cleanup. Migration: 034_missing_tables.sql

## F – Zeitbank Phase 1 (2026-04-14)
- [x] F1.1 Zeitbank-Seite komplett neu (ohne ModulePage): HilfeForm, HilfeHistorie, Zeitkonto
- [x] F1.2 Migration: help_date DATE + Backfill, zeitbank_notifications Tabelle + RLS + Indexes
- [x] F1.3 API: GET/POST /api/zeitbank/entries, PATCH /confirm + /reject, GET /balance, GET /notifications
- [x] F1.4 src/lib/supabase/api-auth.ts: getApiClient() + err-Helfer für alle API-Routes
- [x] F1.5 ZeitbankConfirmationBanner: globales Banner in DashboardShell, Realtime-Subscribe, Bestätigen/Ablehnen inline
- [x] F1.6 Dual-Notification beim Eintragen: zeitbank_notifications (Banner) + notifications (Toast/Push/Sound)
- [x] PHASEN.md erstellt mit Phase 1 vollständig abgehakt

## G – Session 2026-04-24 (TypeScript + Deploy + Android)
- [x] G1 TypeScript: 64 Fehler behoben – `npx tsc --noEmit` Exit 0, `npm run build` sauber
  - G1.1 Echter Bug: undefinierte `searchUrl` in api/social-media/images konstruiert
  - G1.2 Echter Bug: nicht existentes `display_name` in UsersTab durch `name` ersetzt
  - G1.3 Echter Bug: `navigator.share` → `'share' in navigator` (korrekter Feature-Check)
  - G1.4 Supabase-Query `.catch()` → `try/catch` (5 Stellen: emails/track, crisis, farm, AppShell)
  - G1.5 Lucide-Icon `title` → `aria-label` (BoardCard, BoardCardDetail, groups, ChatView)
  - G1.6 React 19 `useRef<T>()` → `useRef<T | undefined>(undefined)` (5 Stellen)
  - G1.7 PostCardPost/Leaflet Default via `unknown` gecastet, VoiceInputButton SpeechRecognition-Types
  - G1.8 middleware.ts + api-auth.ts: `cookiesToSet` mit `CookieOptions` typisiert
  - G1.9 tsconfig: supabase/functions (Deno) + .next + out ausgeschlossen
  - G1.10 src/types/globals.d.ts: Leaflet CSS-Module deklariert, @types/pg installiert
- [x] G2 Features (in vorherigen Sessions auf Branch):
  - WeatherWidget + Luftqualität (OpenAQ) + Sonnenzeiten (PR #121, gemergt)
  - Barrierefreiheits-Layer Wheelmap/OSM (PR merged)
  - Spracheingabe (VoiceInputButton) für Beitrag erstellen
  - Erfolgsgeschichten-System + Danke-System
  - WeeklyDigest Karte in Dashboard-Sidebar
  - NINA-Warnungen + NinaWarningBanner
- [x] G3 Android/Capacitor-Setup: capacitor.config.ts, android.yml CI (build auf main-push + tags)
- [x] G4 Deploy www.mensaena.de: Cloudflare Workers via GitHub Actions (deploy.yml, push auf main)
- [x] G5 Android APK: Debug-APK via android.yml auf main-push ausgelöst (GitHub Actions Artefakt)
- [x] G6 PR #124 gemergt (TypeScript-Fixes) → main ist aktuell, `tsc --noEmit` sauber

## Done (Archiv)
- [x] Schema 001 (10 Tabellen,RLS,Trigger)
- [x] Board (board_posts,pins,comments)
- [x] Events (events,attendees,trigger,storage)
- [x] Orgs (organizations,reviews,50 seeds)
- [x] Krisen (crises)
- [x] Farms (010a-g komplett)
- [x] Erweitert (chat_announcements,post_tags,timebank,knowledge,crisis_reports,skills,volunteers)
- [x] Mig029 (CASCADE,Admin-RPCs,Such-RPCs)
- [x] Mig030 (Audit,Views,RateLimit,Triggers,GIN)
- [x] DROP-Script + read-Fix + Matches+Updates
- [x] Frontend komplett (alle Seiten,13+ Module)
- [x] Storage Buckets (6 Stück)
- [x] B1 Sicherheit komplett (1.1-1.4)
- [x] B8 DB-Clean komplett (8.1-8.4)
- [x] B3 Performance komplett (3.1-3.5) + Deploy
- [x] B4 Features komplett (4.1-4.11) + Deploy
- [x] B5 Infra komplett (5.1-5.10)
- [x] B6 Polish komplett (6.1-6.6)
- [x] B7 Neue Module komplett (7.1-7.7)
- [x] Intelligente Modul-Zuordnung (ModulePage.moduleFilter[])
- [x] DM-System repariert (UUID, RLS, FK, Fallback)
- [x] Rate-Limit Signatur angepasst (p_max_per_hour, p_max_per_minute)
- [x] Build-Warnungen behoben (Fax-Icon, console.warn)
- [x] CrisisTab: Edit-Modal für Status+Severity
- [x] v1.0.0-beta package.json
- [x] Batch3: 8+1 fehlende Tabellen (034_missing_tables.sql), 30+ Umlaute Runde 3, BottomNav AppShell, 7 RPCs, User-Ban, Audit-Logs, Rollen-Dropdown verifiziert
- [x] Echtzeit-Notification-Center: NotificationBell Dropdown mit Kategorie-Tabs (Alle/Nachrichten/Interaktionen/System), gelesen/ungelesen Markierung, Einzelloesch-Button, Settings-Link
- [x] Push-Notifications: DashboardShell sendet Browser-Push bei Nachrichten/Interaktionen/Krisen (wenn Tab nicht fokussiert), Sound-Benachrichtigung (respektiert localStorage Praeferenz)
- [x] Sound-Sync: NotificationSettings synct notify_sound in localStorage, DashboardShell liest von dort (kein DB-Call)
- [x] Echtzeit-Badges: AppShell Supabase Realtime Channels fuer notifications (INSERT+UPDATE), messages (INSERT), crises (*), interactions (*) mit Badge-Dekrement bei Gelesen-Markierung
- [x] Kontaktadressen: Uwe Vetter (Via d'Ascoli 25, I-93021 Aragona) + Manuel Brandner (Im Wahlsberg 10, 55545 Bad Kreuznach) + info@mensaena.de in Impressum, AGB, Datenschutz, Nutzungsbedingungen, Haftungsausschluss, Community-Guidelines
- [x] Profil-Radius: Bereits auf 150km erweiterbar (ProfileLocationSettings + NotificationSettings Slider max=150)
- [x] CSS: ring Keyframe-Animation fuer Bell-Icon, fadeOut Animation fuer Toasts
- [x] Navigationsleiste-Overhaul: Sidebar (Cmd+K Suche, Pinned-Pages localStorage, Recent-Pages localStorage, Tooltips collapsed, Krisen-Badge SOS, Total-Badge collapsed Logo), Topbar (Chat-Badge, Map-Shortcut, Mini-Breadcrumb-Trail), BottomNav (Badges fuer Krisen/Matches/Interaktionen in Mehr-Sheet, Krisen-Pulse, breiterer Active-Indicator), MobileMenu (Suchfeld, Avatar+Initials, Quick-Stats-Bar, Collapsible-Gruppen, Quick-Links Footer), AppShell (Hamburger-Button links, Avatar rechts, badge-pop Animation, blaue Chat-Badges), useNavigation (6 neue Seitentitel: Badges, Matching, Interaktionen, Farm-Listings, Suche, Admin-Dashboard), SidebarItem (Tooltip-Overlay bei Hover im Collapsed-Modus, onContextMenu-Support)
- [x] Handels-Checkbox: Pflicht-Checkbox "Kein Handel / kein Geldgeschäft" in allen Create-Forms (Posts, Krisen, Events, Board) mit §4 AGB-Verweis; Submit nur bei checked
- [x] AGB/Haftungsausschluss: §4 Handelsverbot + §7 Haftungsklausel hinzugefügt
- [x] Telefonnummern entfernt: kontakt/page.tsx, impressum, AGB, Landing-Page bereinigt
- [x] SOS-Button: In grünen Header verschoben (mobile + desktop), rechteckig mit sosBlink-Animation; SOSModal via createPortal für korrektes z-index-Verhalten; Backdrop-Click + X-Button + Escape schließen zuverlässig
- [x] Bot-Repositionierung: MensaenaBot von oben-rechts nach unten-rechts verschoben (bottom-20 mobile, bottom-6 desktop, z-30)
- [x] Logo: mensaena-logo.png in Landing-Navbar und Footer eingebunden
- [x] Umlaut-Korrekturen: 33 Fixes in 16 Dateien (ae→ä, oe→ö, ue→ü, ss→ß)

- [x] fix(calls): #16 — Stale-Cleanup killt keine aktiven Calls mehr: STALE_CUTOFF 120_000ms, nur 'ringing' bereinigen, ACTIVE_CUTOFF 4h für Zombie-active-Calls, initialCallId-Guard verhindert Push-Accept 404, load-Query auf ACTIVE_CUTOFF umgestellt

## Zeit
B1-B8: ~85h | Audit-Fixes: ~20-30h | Session G (2026-04-24): ~3h | Session H (2026-04-30): ~1h
