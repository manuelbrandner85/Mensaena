# CLAUDE.md – Mensaena Flutter App

## Projekt
Mensaena Flutter App – Native Mobile Client für die Nachbarschaftshilfe-Plattform mensaena.de
Version 1.0.0-beta | Sprache: Deutsch

## Status
Komplette Neuimplementierung als Flutter-App. Nutzt dasselbe Supabase-Backend wie die Web-App.

## Tech-Stack
- Flutter 3.24+ / Dart 3.5+
- Supabase Flutter SDK (Auth, Realtime, Storage, PostgREST)
- Riverpod 2.x (State Management)
- GoRouter 14.x (Navigation)
- flutter_map + latlong2 (Karten, OpenStreetMap)
- cached_network_image (Bild-Caching)
- firebase_messaging (Push Notifications)

## Architektur
```
lib/
├── main.dart                    # Entry point, Supabase init
├── app.dart                     # MaterialApp, Theme, Router
├── config/
│   ├── supabase_config.dart     # Supabase URL + Anon Key
│   ├── theme.dart               # Design-System (Farben, Fonts, Widgets)
│   └── routes.dart              # GoRouter Konfiguration
├── models/                      # Dart-Klassen mit fromJson/toJson
│   ├── user_profile.dart
│   ├── post.dart
│   ├── conversation.dart
│   ├── message.dart
│   ├── notification.dart
│   ├── board_post.dart
│   ├── event.dart
│   ├── organization.dart
│   ├── crisis.dart
│   ├── interaction.dart
│   ├── match.dart
│   ├── trust_rating.dart
│   ├── farm_listing.dart
│   ├── group.dart
│   ├── challenge.dart
│   ├── timebank_entry.dart
│   ├── knowledge_article.dart
│   ├── skill_offer.dart
│   └── map_pin.dart
├── services/                    # Supabase CRUD + Realtime
│   ├── auth_service.dart
│   ├── post_service.dart
│   ├── chat_service.dart
│   ├── notification_service.dart
│   ├── board_service.dart
│   ├── event_service.dart
│   ├── organization_service.dart
│   ├── crisis_service.dart
│   ├── interaction_service.dart
│   ├── profile_service.dart
│   ├── trust_service.dart
│   ├── map_service.dart
│   ├── matching_service.dart
│   ├── group_service.dart
│   ├── challenge_service.dart
│   ├── timebank_service.dart
│   ├── knowledge_service.dart
│   ├── skill_service.dart
│   ├── farm_service.dart
│   └── dashboard_service.dart
├── providers/                   # Riverpod Providers
│   ├── auth_provider.dart
│   ├── post_provider.dart
│   ├── chat_provider.dart
│   ├── notification_provider.dart
│   ├── dashboard_provider.dart
│   ├── board_provider.dart
│   ├── event_provider.dart
│   ├── organization_provider.dart
│   ├── crisis_provider.dart
│   ├── interaction_provider.dart
│   ├── profile_provider.dart
│   ├── trust_provider.dart
│   ├── map_provider.dart
│   ├── matching_provider.dart
│   ├── group_provider.dart
│   ├── challenge_provider.dart
│   ├── timebank_provider.dart
│   └── settings_provider.dart
├── screens/                     # Alle Screens (1:1 Mapping zur Web-App)
│   ├── auth/
│   ├── dashboard/
│   ├── home/
│   ├── posts/
│   ├── chat/
│   ├── map/
│   ├── profile/
│   ├── notifications/
│   ├── board/
│   ├── events/
│   ├── organizations/
│   ├── crisis/
│   ├── groups/
│   ├── settings/
│   ├── timebank/
│   ├── challenges/
│   ├── matching/
│   ├── interactions/
│   ├── create/
│   ├── messages/
│   ├── knowledge/
│   ├── skills/
│   ├── sharing/
│   ├── supply/
│   ├── marketplace/
│   ├── housing/
│   ├── mobility/
│   ├── animals/
│   ├── badges/
│   ├── calendar/
│   ├── community/
│   ├── mental_support/
│   ├── rescuer/
│   ├── harvest/
│   ├── wiki/
│   └── admin/
└── widgets/                     # Wiederverwendbare Widgets
    ├── module_screen.dart
    ├── post_card.dart
    ├── chat_bubble.dart
    ├── avatar_widget.dart
    ├── badge_widget.dart
    ├── trust_score_badge.dart
    ├── loading_skeleton.dart
    ├── empty_state.dart
    ├── error_state.dart
    └── section_header.dart
```

## Supabase Backend
- Project-ID: huaqldjkgyosefzfhjnf
- URL: https://huaqldjkgyosefzfhjnf.supabase.co
- Anon Key: In config/supabase_config.dart
- KEINE Backend-Änderungen – nur Client-seitige Implementierung

## Design-System
- Primary: #1EAAA6 (Teal)
- Dark: #147170
- Light: #d0f5f3
- Background: #EEF9F9
- Trust: #4F6D8A
- Emergency: #C62828
- Text: gray-900 (Titel), gray-700 (Body), gray-400 (Muted)

## Navigation
- Bottom Navigation: Home, Karte, Erstellen, Chat, Mehr
- Drawer: Alle 35+ Module in 7 Kategorien
  1. Kommunikation (DM, Chat, Matching)
  2. Helfen & Finden (Karte, Beiträge, Organisationen, Interaktionen)
  3. Notfall & Sicherheit (Krisen, Mental Support, Rettungsnetz)
  4. Gemeinschaft (Community, Gruppen, Events, Board, Challenges)
  5. Teilen & Versorgen (Teilen, Zeitbank, Marktplatz, Versorgung, Ernte)
  6. Wissen & Engagement (Wiki, Bildung, Skills, Tierhilfe)
  7. Mein Bereich (Profil, Badges, Wohnen, Mobilität, Kalender, Einstellungen)

## Build & Run
```bash
flutter pub get
flutter run
```

## Fortschritt
- [x] Projektstruktur erstellt
- [x] Config (Supabase, Theme, Routes)
- [x] Models (alle gegen echte Supabase-DB verifiziert)
- [x] Services (alle FK-Joins gegen DB geprueft, RPCs statt direkte Queries)
- [x] Providers (Riverpod)
- [x] Widgets (PostCard, ChatBubble, ModuleScreen, RatingDialog, ReportDialog, etc.)
- [x] Auth (Login, Register, Forgot Password + AuthNotifier fuer GoRouter)
- [x] Dashboard Shell + Drawer mit Mensaena-Logo + Gradient-Header
- [x] Home Screen (HeroCard, QuickActions, StatsGrid, CommunityPulse, TrustScore, Onboarding, WeeklyChallenge)
- [x] Posts (10 Typ-Filter, search_posts RPC, Realtime neue Beitraege)
- [x] Create Post (9 Typen, Kategorie-Auswahl, Bild-Upload, Draft Auto-Save)
- [x] Map (flutter_map, Radius-Slider, Pins)
- [x] Chat (DM/Community Tabs, Realtime Messages, Conversation Screen)
- [x] Profile (Gradient-Banner, Stats, Activity Feed, Edit mit Avatar-Upload)
- [x] Public Profile (Banner, Stats, Block/Nachricht Buttons)
- [x] Detail Screens (Event, Crisis, Group, Org, Post, Interaction — alle vollstaendig)
- [x] Organizations (search_organizations_v2 RPC, 203 echte Eintraege)
- [x] Farm/Supply (farm_listings Tabelle, 589 Eintraege, Bio/Verified Badges)
- [x] Marketplace (marketplace_listings Tabelle, Inserat erstellen)
- [x] Board (Schwarzes Brett, Farbige Karten, Aushang erstellen)
- [x] Events (Kategorie-Filter, Event erstellen mit allen Feldern)
- [x] Crisis (Status-Filter, Kategorie-Filter, Krise melden mit Urgency)
- [x] Groups (Suche, Kategorie-Filter, Gruppe erstellen)
- [x] Settings (4 Tabs: Benachrichtigungen, Privatsphaere, Sicherheit, Konto)
- [x] Notifications (Realtime, Datum-Gruppierung, Swipe-to-Dismiss, 16 Typen)
- [x] Matching (get_my_matches + get_match_counts RPCs)
- [x] Timebank (Balance, Eintraege, Stunden eintragen)
- [x] Challenges (Kategorie-Filter, Join/CheckIn)
- [x] Badges (echte Daten aus badges/user_badges Tabellen)
- [x] Calendar (Monats-Grid, Event-Dots)
- [x] Skills (skill_offers Tabelle, Anbieten-Formular)
- [x] Admin (5 Tabs: Uebersicht, Benutzer, Beitraege, Meldungen, Krisen)
- [x] Rating System (RatingDialog nach Interaktionen)
- [x] Content Reports (Melden-Button)
- [x] User Blocks (blockieren/entsperren)
- [x] Alle 82 Supabase-Tabellen referenziert
- [x] Alle FK-Joins gegen echte DB verifiziert
- [x] Android Permissions (Internet, Location, Camera, Storage, Vibrate)
- [x] Mensaena App-Icon + Logo ueberall

## Dateistatistik
- 22.259 Zeilen Screen-Code (47 Screens)
- 2.241 Zeilen Service-Code (20 Services)
- 2.474 Zeilen Model-Code (19 Models)
- 2.343 Zeilen Widget-Code (15 Widgets)
- 0 Compile-Fehler, 0 Stubs, 0 Placeholders

## RPCs verwendet (statt direkte Queries)
- search_posts (Volltext + Geo + Urgency)
- search_organizations_v2 (Org-Suche)
- get_my_matches / get_match_counts / respond_to_match (Matching)
- open_or_create_dm (Chat)

## Design System
- Editorial Header Widget (§ Nummer / Sektion) für jede Seite
- MensaenaCard Widget (3px Gradient-Streifen, soft shadow)
- Farben: Primary #1EAAA6, Warm BG #f5f0eb, Ink #1a1a1a, Border #e7e5e4
- TextStyles: metaLabel (10px uppercase), pageTitle (28px w500), pageSubtitle (14px)
- timeago Deutsch initialisiert

## Query-Fixes (gegen Web-App verifiziert)
- Alle profile Joins vereinfacht: profiles(name, avatar_url)
- Posts: urgency DESC, created_at DESC Sortierung
- Board: pinned DESC, created_at DESC Sortierung
- Crisis: urgency DESC, created_at DESC Sortierung
- Events: event_attendees(user_id, status) im Select
- Messages: ascending: true (älteste zuerst)
- Notifications: content statt body (DB-Spaltenname)
- Post authorName: name vor nickname
- Alle Services: try/catch (kein Endlos-Spinner)

## Model-Fixes (gegen echte DB verifiziert)
- PostType-Enum: exakt 10 Werte (help_needed, help_offered, rescue, animal,
  housing, supply, mobility, sharing, crisis, community)
- Post-Klasse: nicht-existente Felder entfernt (imageUrl, isAnonymous, eventDate,
  eventTime, durationHours, moduleSlug, isPinned, reactionCount, mediaUrls, expiresAt)
- Post-Klasse: hat nur noch DB-Spalten (image_urls TEXT[], location_text,
  contact_whatsapp, contact_email, tags TEXT[])
- MessageReaction-Klasse gelöscht (Tabelle message_reactions existiert nicht)
- chat_service: addReaction/removeReaction entfernt
- create_post_screen: is_anonymous und image_url (singular) Insert entfernt
- post_card: _getTypeColor deckt jetzt alle 10 PostTypes ab
- post_detail_screen: Event-Block (eventDate/eventTime/durationHours) entfernt

## Service-Fixes (RPCs & Phantom-Tabellen bereinigt)
- post_service: RPC get_nearby_posts → p_lat/p_lng/p_radius_km/p_limit
- post_service: RPC search_posts → p_query/p_type/p_lat/p_lng/p_radius_km/p_limit/p_offset
- post_service: vote/removeVote/getComments/addComment/addReaction entfernt
  (Tabellen post_votes, post_comments, post_reactions existieren nicht)
- post_service: getDraft/saveDraft/deleteDraft entfernt (post_drafts existiert nicht)
- post_detail_screen: Vote-Section komplett entfernt, durch Share-Row ersetzt
- create_post_screen: Draft-Auto-Save/Load komplett entfernt
- chat_service: getChatChannels/getAnnouncements/setUserStatus entfernt
  (Tabellen chat_channels, chat_announcements, user_status existieren nicht)
- chat_service: addReaction/removeReaction bereits in AUFGABE 1 entfernt
- chat_service: NEU getCommunityConversations(userId) für type='group'|'system'
- chat_provider: chatChannelsProvider nutzt jetzt getCommunityConversations
- dashboard_service: helped_id → user_id (in interactions .or-Filter)
- dashboard_service: trust_ratings Spalte rating → score (konsistent mit Model)
- dashboard_service: NEU _getWeeklyChallenge → results[8] → 'weekly_challenge'
- interaction_service: helped_id → user_id in allen .or-Filtern

## Auth- & Create-Fixes (an Web-Version angeglichen)
- login_screen: Meta-Label "COMMUNITY PLATTFORM" über dem Logo
- login_screen: Lockout-Countdown mit Timer.periodic (Sekunden-Anzeige)
- login_screen: Generische Fehlermeldung bei AuthException
  ("Anmeldung fehlgeschlagen. Bitte überprüfe deine Eingaben.")
- login_screen: Button deaktiviert während Lockout
- register_screen: Meta-Label "KONTO ERSTELLEN" über dem Logo
- register_screen: 3 Text-Checks (Länge, Groß+Klein, Zahl) unter Strength-Bar
- register_screen: Email-Duplicate-Check vor signUp (profiles.email)
- register_screen: _buildCheck Helper-Widget für Grün/Grau-Icons
- create_post_screen: 10 PostTypes (help_needed als erster Typ hinzugefügt)
- create_post_screen: max 4 statt 5 Bilder (_imageBytes.length < 4)
- create_post_screen: contact_whatsapp + contact_email Felder in Step 2
- create_post_screen: Email-Feld hat @-Validator (optional)

## Posts Screen — exakt Web-Version
- TypeFilters: 9 Typen (ohne help_needed/help_offered), Labels exakt von Web
  (rescue='🧡 Hilfe/Retten', sharing='🔄 Teilen/Skills', etc.)
- Popular Tags: '#hilfe', '#notfall', '#tauschen', '#wien', '#graz',
  '#österreich', '#lebensmittel', '#wohnen', '#transport'
- GPS-Button: geolocator ^12.0.0, "📍 Meinen Standort verwenden",
  Geolocator.getCurrentPosition, auto _radius=25, "Standort erkannt ✓",
  Zurücksetzen-Button, GPS-Active als Filter-Chip
- Quick-Radius-Buttons: 5, 10, 25, 50, 100 km (zusätzlich zum Slider)
- Debounced Search: Timer 400ms auf _searchController, 500ms auf _locationController
- Section-Nummer: §02 (nicht §03)
- Grid/List Toggle + Urgency Filter beibehalten (Flutter > Web)

## Screen-Erweiterungen (Posts, Board, Map an Web angeglichen)
- posts_screen: EditorialHeader (§ 02 / Beiträge)
- posts_screen: zweites Suchfeld für Ort (location filter)
- posts_screen: Erweiterte-Filter-Panel mit AnimatedCrossFade
  (Radius-Slider 5-200 km, beliebte Tags als FilterChips, Reset-Button)
- posts_screen: Active-Filter-Chips unter Typ-Filtern (Suche, Ort, Tag, Radius)
- posts_screen: Pagination mit PAGE_SIZE=20 ("Mehr laden" Button)
- posts_screen: PostCard onTap → /dashboard/posts/:id
- board_screen: EditorialHeader (§ 03 / Aushänge)
- board_screen: Create-Modal um Bild-Upload, Kontaktinfo, Ablaufdatum erweitert
- board_screen: Tap auf Card öffnet DraggableScrollableSheet Detail-View
  (voller Content, Bild, Autor, Kontakt, Ablauf, Pin-Count, Kommentare, Edit/Delete)
- board_screen: Pin-Toggle auf jeder BoardCard (Icon + Pin-Count)
- board_screen: Bearbeiten-Funktion mit vorausgefüllten Feldern
- board_service: NEU updateBoardPost(postId, data) Methode
- board_service: NEU uploadImage(bytes, fileName) für Board-Bilder
- map_screen: Slider-Parameter korrigiert (min: 5, max: 200, divisions: 39)
- map_screen: Realtime-Channel 'map:posts:realtime' mit debounced (300ms) refresh
- map_screen: Pin-Farben für alle 10 PostTypes + 'organization' gemappt

## Dashboard-Erweiterungen (Home, Profile, Notifications an Web angeglichen)
- home_screen: ConsumerStatefulWidget mit ScrollController + ScrollToTop FAB
- home_screen: RatingPromptBanner unter HeroCard (vor QuickActions), mit RatingModal
  2s-Delay auto-Popup bei pending ratings (einmal pro Session)
- home_screen: SmartMatchWidget nutzt get_nearby_posts RPC + user.seekTags Filter
  (Typ-Emoji, Titel, Autor pro Match-Karte, Tap → /dashboard/posts/:id)
- home_screen: Widget-Reihenfolge exakt Web: HeroCard → RatingPrompt → QuickActions
  → SmartMatch → Onboarding → Challenge → NearbyPosts → UnreadMessages → Stats
  → ActivityFeed → MiniMap → TrustScore → CommunityPulse → BotTip
- home_screen: ScrollToTop FAB (AnimatedOpacity, ab 300px Scroll)
- home_screen: ActivityFeed (letzte 5 Einträge aus dashboardData['recent_activity'])
- home_screen: MiniMap (flutter_map mit Nachbar-Pins, Tap → /dashboard/map)
- home_screen: BotTipCard (dashboardData['bot_tip'] oder 4 Fallback-Tipps)
- dashboard_service: member_since_days Berechnung in _getUserStats
- profile_service: NEU hours_received-Berechnung aus timebank_entries (receiver_id)
- profile_screen: _OfferSeekTags Widget (gruene "Ich biete" + blaue "Ich suche" Chips)
- profile_screen: _StatsGrid auf 5 Karten erweitert (Stunden gegeben + erhalten)
- notification_provider: NEU unreadCountsByTypeProvider
- notifications_screen: EditorialHeader (§ 08 / Benachrichtigungen) im Body
- notifications_screen: Unread-count-Badges pro Typ im Filter-Popup
- notifications_screen: Alle-loeschen-Button mit Bestaetigungs-Dialog
- notifications_screen: NotificationPreferences-Link am Listenende

## Modul-Erweiterungen (Events, Crisis, Interactions, Settings, Admin an Web angeglichen)
- events_screen: SegmentedButton Liste/Kalender/Karte-Umschalter (AppBar bottom)
- events_screen: Suchfeld (filtert title/description/location)
- events_screen: _AttendanceControl mit 3 Status (going/interested/declined)
  Toast-Nachrichten: "Du nimmst teil!" / "Als interessiert markiert" / "Absage eingetragen"
- events_screen: _EventSkeleton (Shimmer-Effekt, 4 Cards statt CircularProgressIndicator)
- events_screen: Refresh-Button in AppBar (animiert während Refresh)
- events_screen: Pull-to-Refresh auf Liste + Kalender-View
- events_screen: EditorialHeader §05 (nicht §07)
- events_screen: _CalendarView (7-Spalten-Grid mit Dot-Markern, Tag-Auswahl)
- events_screen: _MapView (FlutterMap mit Markern, Tap → Detail)
- crisis_screen: SOS-Button oben (rot, öffnet SOS-Modal mit 112/110/Telefonseelsorge)
- crisis_screen: _SOSButton Widget für SOS-Modal Einträge (tel:-Launch)
- crisis_screen: _CrisisDashboardStats (Aktiv/In Bearbeitung/Gelöst aus crisisStatsProvider)
- crisis_screen: Suchfeld "Krisen suchen..." mit Client-Side Filter
- crisis_screen: Urgency-Filter (Alle/Kritisch/Hoch/Mittel/Niedrig) als Chips
- crisis_screen: Active-Crisis-Alert-Banner (ALLE active+in_progress, nicht nur critical)
- crisis_screen: SegmentedButton Liste/Karte (AppBar bottom)
- crisis_screen: _EmergencyNumbersCard am Listenende (5 Tiles mit tel:-Launch)
  Polizei 110, Feuerwehr 112, Telefonseelsorge 0800 111 0 111, Giftnotruf 030 19240, Frauennotruf 08000 116 016
- crisis_screen: _CrisisMapView (Marker-Farbe nach Urgency)
- crisis_screen: "Ressourcen & Hilfsangebote" Link am Listenende
- crisis_screen: EditorialHeader §16 (nicht §08)
- interaction_provider: NEU interactionStatsProvider
- interactions_screen: _InteractionStatsCard (Gesamt/Erfolgreich/Storniert)
- interactions_screen: EditorialHeader §06 (nicht §09)
- interactions_screen: _StatusFlowBar (Angefragt→Angenommen→Aktiv→Fertig→Bewertet)
- interactions_screen: _BadgeCounterRow (Neue/Aktive/Bewertung)
- interactions_screen: _StatusFilterChips (Alle/Angefragt/Angenommen/Aktiv/Abgeschlossen)
- interactions_screen: _InteractionCard mit Action-Buttons je Status
  requested+Owner → Annehmen/Ablehnen, accepted → Starten, in_progress → Abschließen,
  completed+Owner → Bewerten (via RatingDialog + trustService.createRating)
- settings_screen: 5 Tabs (Profil/Standort als erster Tab)
- settings_screen: _ProfileLocationSettings (Name, Bio, Standort, Radius-Slider,
  Telefon, Homepage, Speichern-Button → profileService.updateProfile)
- settings_screen: _ChangePasswordDialog (funktional, supabase.auth.updateUser)
- admin_screen: Von 5 auf 10 Tabs erweitert
- admin_screen: NEU _adminEventsProvider + _EventsTab (Status/Delete)
- admin_screen: NEU _adminBoardProvider + _BoardTab (Pin/Status/Delete)
- admin_screen: NEU _adminOrgsProvider + _OrgsTab (Verify/Active/Delete)
- admin_screen: NEU _adminFarmsProvider + _FarmsTab (Verify/Public/Delete)
- admin_screen: NEU _adminTimebankProvider + _TimebankTab (Confirm/Reject/Delete)

## Finaler Polish-Pass (Bot, Onboarding, Auth-DE, PostCard)
- mensaena_bot.dart: Neues Widget — FAB unten links im DashboardShell,
  öffnet BottomSheet mit letzten 5 Bot-Tips aus bot_scheduled_messages,
  Platzhalter-Input "Bald verfügbar"
- onboarding_tour.dart: Neues Widget — 5-Schritt PageView Tour für neue User
  (Willkommen, Beiträge, Erstellen, Chat, Fertig), Überspringen-Button,
  setzt onboarding_completed=true in profiles
- dashboard_shell: Bot + OnboardingTour als Stack-Layer integriert
- Auth-Screens: Deutsche Fehlermeldungen erweitert:
  'Invalid login credentials' → 'E-Mail oder Passwort ist falsch'
  'Password should be at least' → 'Passwort muss mindestens 8 Zeichen haben'
  'not confirmed' → 'Bitte bestätige zuerst deine E-Mail'
  Fallback → 'Ein Fehler ist aufgetreten. Bitte versuche es erneut.'
- PostCard: Long-Press Context Menu (Speichern, Teilen via share_plus,
  Kontakt aufnehmen, Melden, eigene: Bearbeiten/Löschen)
- PostCard: Kontakt-Modal mit vorausgefüllter Nachricht + open_or_create_dm
- PostCard: Report-Dialog mit 4 Meldegründen → content_reports Insert

## EditorialHeaders + PostCard (UI-Polish)
- EditorialHeaders auf 20+ Screens hinzugefügt:
  Animals §22, Housing §20, Mobility §21, Sharing §17, Community §25,
  Rescuer §27, Supply §18, Harvest §28, Marketplace §19, Skills §16,
  Knowledge §15, Wiki §29, Challenges §13, Timebank §11, Badges §23,
  Calendar §24, Matching §14, Groups §10, Interactions §09, Crisis §08
  (zusätzlich zu bestehenden: Posts §03, Board §04, Events §07,
  Notifications §12, MentalSupport §26)
- PostCard: _getTypeColor exakt an Web angeglichen (helpOffered→primary,
  rescue→orange, animal→brown.600, housing→indigo, supply→green.700,
  mobility→blue, sharing→purple)
- PostCard: Bilder-Layout für 1/2/3/4 Bilder (1=full, 2=50/50,
  3=2/3+2×1/3 gestapelt, 4=2×2 Grid)

## Settings, Admin, Create-Post (Ergänzungen)
- settings_screen: _ProfileLocationSettings erweitert um Nickname, Adresse,
  Stadt, PLZ, Region-Dropdown (9 AT-Bundesländer + DE/CH/Sonstige)
- admin_screen: Von 10 auf 11 Tabs erweitert (_GroupsTab hinzugefügt:
  Name, Kategorie, Mitglieder, Status, Archivieren/Aktivieren/Löschen)
- create_post_screen: Umlaut-Fix Gespraech → Gespräch

## Map, Profile, Events, Crisis, Interactions (Verifikation + Ergänzungen)
- events_screen: EditorialHeader § 07 "Events & Treffen" hinzugefügt
- profile_edit_screen: Offer/Seek Tags Bearbeitung (kommagetrennte Eingabe,
  Speichern als offer_tags/seek_tags Array, grüne/orange Icons)
- Verifikation: map_screen (Realtime ✅, Slider 5-200/39 ✅, 10+1 Pin-Farben ✅,
  Debounce ✅), profile_screen (hours_received ✅, OfferSeekTags ✅),
  events_screen (3 Views ✅, Suche ✅, Attendance ✅), crisis_screen (SOS ✅,
  EmergencyNumbers ✅, Alert-Banner ✅, Map-Toggle ✅), interactions_screen
  (FlowBar ✅, BadgeCounters ✅, FilterChips ✅, Action-Buttons ✅)

## Screen-Erweiterungen (Posts, Board, Chat an Web angeglichen)
- posts_screen: Grid/List Toggle (IconButton in AppBar, _CompactPostCard für Grid)
- posts_screen: Urgency-Filter im erweiterten Filter-Panel (Alle/Niedrig/Mittel/Hoch/Kritisch)
- posts_screen: Beliebte Tags aktualisiert (Einkauf, Begleitung, Garten, Handwerk, etc.)
- posts_screen: EditorialHeader § 03 "Beiträge in deiner Nähe" aktualisiert
- posts_screen: "Weitere Beiträge laden" statt "Mehr laden"
- board_screen: Bereits komplett (Detail-Sheet, Kommentare, Edit, Delete, Pin)
- board_screen: Kommentar löschen via Long-Press + delete-Icon (eigene Kommentare)
- board_screen: Refresh-Button in AppBar
- board_service: NEU deleteComment(commentId) Methode
- conversation_screen: Message Edit (Long-Press → Bearbeiten, _editingMessageId, _saveEdit)
- conversation_screen: Message Delete (Long-Press → Löschen mit soft-delete deleted_at)
- conversation_screen: Image Upload (attach_file Button, ImagePicker, Supabase Storage
  chat-attachments Bucket, message_type='image')
- conversation_screen: Edit-Banner über Eingabefeld wenn Nachricht bearbeitet wird
- chat_bubble: Image-Support (CachedNetworkImage wenn messageType=='image',
  Tap → Fullscreen InteractiveViewer)
- chat_bubble: "Diese Nachricht wurde gelöscht" (kursiv, grau)
- chat_service: sendMessage akzeptiert optionalen messageType Parameter
- Message Model: messageType Feld hinzugefügt (default 'text')

## DashboardShell + Notifications (an Web-Version angeglichen)
- notification_snackbar.dart: Eigenständiges Widget extrahiert
  (Avatar via FutureBuilder, Titel, Body 2 Zeilen, timeago, "Anzeigen",
  6s Dauer, dismissDirection: down, nicht auf /dashboard/notifications)
- dashboard_shell: WidgetsBindingObserver für Lifecycle-Erkennung
- dashboard_shell: Notification-Sound via audioplayers (Volume 0.3,
  nur im Vordergrund, SharedPreferences 'mensaena_notify_sound')
- dashboard_shell: Nutzt showRichNotificationSnackbar() + HapticFeedback
- dashboard_shell: ZeitbankConfirmationBanner oben im Shell
  (gelbes Banner, status='pending_confirmation' mit Fallback confirmed=false)
- dashboard_shell: Firebase Messaging Basis-Setup (requestPermission,
  Token in profiles.push_token + fcm_token speichern, try/catch)
- dashboard_shell: MensaenaBot FAB + OnboardingTour Overlay als Stack-Layer
- mensaena_bot.dart: Bot-Tips aus bot_tips (Fallback: bot_scheduled_messages,
  Fallback: 5 hardcoded Tipps), Input-Platzhalter
- onboarding_tour.dart: 5-Schritt PageView Tour für neue User,
  setzt onboarding_completed=true
- notifications_screen: EditorialHeader §12 Mitteilungen aktualisiert
- pubspec: audioplayers ^6.0.0, shared_preferences ^2.3.3,
  firebase_messaging ^15.1.5, firebase_core ^3.8.1
- assets/sounds/notification.mp3 Platzhalter erstellt

## Finale Modul-Überarbeitung (AUFGABE 7/7)
- mental_support_screen: Komplett neu — EditorialHeader, 4 HotlineCards
  (Telefonseelsorge 0800 111 0 111, Krisenchat krisenchat.de, Hilfetelefon
  Frauen 08000 116 016, Notrufnummer 112), danach Community-Beiträge zum Thema
  mental/seele/psyche, FAB für neuen Beitrag
- harvest_screen: Komplett neu — nutzt farm_listings statt posts
  (FarmService), Kategorie-Filter, Suche, FarmCard mit Bio/Saisonal/Verified
  Badges und Produkt-Tags, Tap öffnet Website via url_launcher
- Umlaut-Fix (global sed sweep):
  Aufraeumaktion→Aufräumaktion, Loeschen→Löschen, aendern/Aendern→ändern/Ändern,
  Geloest→Gelöst, rueckgaengig→rückgängig, geloescht→gelöscht,
  Oeffentliches→Öffentliches, Privatsphaere→Privatsphäre, Fundstueck→Fundstück,
  Fundbuero→Fundbüro, Uebersicht→Übersicht, waehlen→wählen,
  zusaetzlicher→zusätzlicher, fuer→für, koennen→können, Geraet→Gerät,
  oeffnen→öffnen, Naehe→Nähe, Notfaelle→Notfälle, fuehren→führen,
  benoetigt→benötigt, zurueck→zurück, Ueber→Über, Bestaetigung→Bestätigung,
  Moechtest/moechtest→Möchtest/möchtest, verfuegbar→verfügbar, zaehlt→zählt,
  Bestaetigt→Bestätigt, erhaelt→erhält, Erzaehl→Erzähl

## Implementierungs-Status — Komplett

### Models (19 Dateien) ✅
- [x] Post (10 PostTypes, korrekte DB-Felder, location_text, contact_whatsapp, contact_email, tags)
- [x] UserProfile (Settings, offer_tags, seek_tags, crisis-Felder)
- [x] BoardPost + BoardPostCategory (Fundbüro korrigiert)
- [x] Event + EventCategoryConfig (10 Kategorien, Aufräumaktion korrigiert)
- [x] Conversation + ConversationMember + Message (ohne MessageReaction)
- [x] AppNotification + NotificationCategory
- [x] Crisis + CrisisCategory + CrisisUrgency + CrisisHelper + CrisisUpdate
- [x] Interaction + InteractionStatus (8 Werte)
- [x] TrustRating + TrustScoreData
- [x] MapPin (fromPost + fromOrganization)
- [x] Alle weiteren Models (FarmListing, Match, Group, Challenge,
  TimebankEntry, KnowledgeArticle, SkillOffer)

### Services (20 Dateien) ✅
- [x] PostService (korrekte RPC-Params, keine Phantom-Tabellen)
- [x] ChatService (keine Phantom-Tabellen, getCommunityConversations)
- [x] DashboardService (9 parallele Queries, WeeklyChallenge)
- [x] BoardService (CRUD + Pins + Comments + Update)
- [x] EventService (CRUD + Attendance + Calendar + Volunteers + Rideshares)
- [x] CrisisService (CRUD + Helpers + Updates + Stats + Resources)
- [x] InteractionService (CRUD + Status-Updates + Stats + Updates)
- [x] NotificationService (CRUD + Realtime + CountsByType)
- [x] ProfileService (CRUD + Avatar + Stats + Activity + Block + hours_received)
- [x] FarmService, OrganizationService, MapService, MatchingService
- [x] GroupService, ChallengeService, TimebankService
- [x] KnowledgeService, SkillService, TrustService, AuthService

### Screens (35+ Ordner) ✅
- [x] Auth (Login + Register + Forgot Password) — Rate-Limiting, Stärke-Anzeige
- [x] Home/Dashboard — Hero, QuickActions, Rating, Activity, MiniMap, BotTip,
  Challenge, Stats, Trust, Pulse
- [x] Posts — Filter, Tags, Ort, Pagination, Realtime
- [x] Board — Detail, Comments, Pin, Image, Edit, Delete
- [x] Chat — DM + Community + Conversation mit Realtime
- [x] Map — Realtime, 10 Farben, korrekter Slider
- [x] Profile — OfferSeekTags, hours_received, Activity
- [x] Notifications — Delete-all, Counts, Preferences-Link
- [x] Events — 3 Views (Liste, Kalender, Karte), Attend
- [x] Crisis — SOS, EmergencyNumbers, Alert-Banner, Map-Toggle
- [x] Interactions — Flow-Bar, Badges, Filter, Status-Action-Buttons
- [x] Settings — 5 Tabs (Profil/Standort, Benachrichtigungen, Privatsphäre,
  Sicherheit, Konto), funktionales Passwort-Ändern
- [x] Admin — 10 Tabs (Übersicht, Benutzer, Beiträge, Meldungen, Krisen,
  Events, Aushänge, Organisationen, Höfe, Zeitbank)
- [x] Create Post — 10 Types, 4 Bilder, alle Kontaktfelder
- [x] Modul-Screens (19): Animals, Housing, Mobility, Supply (farm_listings),
  Sharing, Community, Rescuer, Mental Support (Hotlines), Harvest (farm_listings),
  Marketplace, Skills, Knowledge, Wiki, Challenges, Timebank, Badges, Calendar,
  Matching, Groups

### Navigation ✅
- [x] BottomNavigationBar: Home, Karte, Erstellen, Chat, Mehr
- [x] AppDrawer: 6 Gruppen, 35+ Module, Admin für berechtigte Rollen
- [x] GoRouter: Alle Routen mit Detail-Screens

### Globale Features ✅
- [x] Realtime Notification Toasts in DashboardShell
- [x] Unread-Badges auf Chat und Notifications
- [x] Deutsche Texte mit korrekten Umlauten (global sed sweep durchgeführt)
- [x] RefreshIndicator + LoadingSkeleton + EmptyState auf allen Listen-Screens
- [x] EditorialHeader auf Haupt-Screens (Posts §02, Board §03, Events §05,
  Interactions §06, Crisis §16, Animals §10, Housing §11, Mobility §12,
  Supply §13, Sharing §14, Community §15, Marketplace §17, Knowledge §18,
  Challenges §19, Groups §20, Matching §21, Notifications §22,
  Timebank §23, Calendar §24, Badges §25, MentalSupport §26, Skills §27,
  Rescuer §28, Harvest §29, Wiki §30)

## Status: IN PRODUKTION
Die App nutzt dasselbe Supabase-Backend und dieselben RLS-Policies.
APK wird automatisch via GitHub Actions gebaut (retention 3 Tage).

## Nächste Schritte
- Editorial Header auf allen Screens einbauen
- MensaenaCard auf allen Listen-Screens nutzen
- Lokalisierung (DE, EN, IT)
- Offline-Cache
- Splash Screen konfigurieren (native Android)
- App-Icon und Splash Screen konfigurieren
- App Store / Play Store Deployment vorbereiten
