# MENSAENA – TODO
> Aktualisiert: 2026-06-11 (Phase-1-Bug-Audit-Fixes: Call/Live-Lifecycle, mounted-Sweep, Controller-Leaks)
> JEDER Prompt = diese Datei updaten. KEINE AUSNAHME.
> [x]=done []=open [SQL]=User führt SQL aus [!]=kritisch

## Ad-hoc (2026-06-11)
- [x] Phase-3-UX Batch 1 (i18n + A11y aus UX-Audit): (1) i18n-Verstoesse behoben — 20 neue Keys in ALLEN 7 Sprachdateien (badges.empty, skills.empty, ratings.emptyReceived/emptyGiven, modules.emptyPosts{+Hint}/tryOtherFilters, knowledge.emptyAll/emptyFiltered, timebank.emptyHint, groups.empty/emptyHint, voice.dictStart/dictStop, home.locationDenied/locationSetPrompt/saveFailed, create.urgencyCritical, posts.saveTooltip/voteDownTooltip); 14 hardcodierte DE-Strings in 10 Dateien auf .tr() umgestellt (inkl. Dringlichkeits-Labels im Module-Create + Location-Onboarding-Fehlertexte); Wiederverwendung bestehender Keys (search.noResultsShort, posts.resetFilter, groups.create, create.locationUnavailable, common.share, profile.report, events.shareLink, errors.loadFailed). (2) Touch-Targets auf 48dp: crisis_create _StepBtn (war 34dp — Krisen-Kontext!) + board_create Farb-Picker (war 36dp), Visual unveraendert, Hit-Area vergroessert. (3) post_detail _ActionIcon: neuer tooltip-Param (Tooltip + Semantics button-Label) an 5 Icon-only-Actions (VoteDown/Save/Share/CopyLink/Report). BEFUND korrigiert: SOS-Flow ist bereits 2 Taps (LocaleCountryService befuellt Land vor) — Audit-Punkt war ueberholt, keine Aenderung.
- [ ] Phase-3 Folge-Batches: CreateFlowMixin + Create-Screen-Keyboard-UX (textInputAction, maxLength-Counter, autovalidateMode), Kontrast-Pass mute->inkSoft, Badge-Diaet (max 3 pro Karte), Error-States M5, Rest-i18n location_onboarding_modal (RichText-Header) + weitere Einzelstrings.
- [x] Phase-2-Refactoring Batch 1 (Architektur-Audit): (1) NEU widgets/shared/app_snackbar.dart — zentraler SnackBar-Helper (success/error/info, surface+body-13-Styling, eingebauter context.mounted-Guard); Migration der ~180 Altaufrufe haeppchenweise pro Modul, Exemplar: challenge_create_screen. (2) sb.from-Sweep aus UI-Schicht: settings_screen (6 Zugriffe -> 0: NotificationsRepository.insertSelfTest, SettingsRepository.gdprRowsSingle/gdprRowsDual/unsubscribeEmail/getConsentFlags, ProfilesRepository.update) + call_screen (7 -> 0: DmCallService.fetchCall/watchCall/markActive/markMissed/conversationIdOf, MessagesRepository.insertSystemNote [bewusst OHNE updated_at-Touch], ProfilesRepository.getById). (3) NEU scripts/check_ui_supabase.py — CI-Ratchet-Guard gegen NEUE direkte Supabase-Zugriffe in screens/widgets (Baseline 113 Zugriffe/61 Dateien eingefroren, darf nur sinken); in flutter.yml als Step "UI-Supabase Guard" verdrahtet.
- [ ] Phase-2 Folge-Batches: AppSnackBar-Migration pro Modul (~180 Stellen), CreateFlowMixin (mit Phase-3-Create-UX), extra_repositories.dart (34 Klassen) fachlich aufteilen, settings_screen/call_screen God-File-Zerlegung, FilterableListScreen/DetailActionsMixin, sb.from-Baseline abbauen.
- [x] [!] Phase-1-Bug-Audit-Fixes (Senior-Review aller Screens): (K1) live_room_screen: Connect-Fehler (25s-Timeout) ließ CallBusyState.inStream=true + LiveAudioService laufen → alle eingehenden Anrufe dauerhaft "besetzt" + Akku-Drain; neu _abortConnect() räumt Busy-State/Foreground-Service/Room im catch- UND !mounted-Pfad auf. (K2) voice_dictation_button: dispose() mit _stt.cancel() + mounted-Guards in onError/onStatus/_toggle (setState-after-dispose beim Verlassen während Diktat). (K3) call_screen._watchCallStatus: _callStatusSub?.cancel() vor neuem .listen() (Reattach via Mini-Player stapelte Subscriptions). (K4) chat_screen._setupPresence: alten Typing-Channel via removeChannel abmelden vor Re-Init (Channel-Leak-Klasse des 4.1.x-OOM). (M1) mounted-Checks nach await: call_screen _toggleMic/_toggleSpeaker, group_create nach Cover-Upload, marketplace_create + event_create zwischen Upload und create(), location_onboarding_modal _useGps/_save. (M3) Dialog-TextEditingController-Leaks disposed: post_detail._editComment, map_screen._promptSavePin. (M4) location_onboarding_modal: _ctrl.dispose() ergänzt. (M6) incoming_call_overlay: _listenerAttached-Flag wird bei Attach-Fehler zurückgesetzt. Cleanup: 2 obsolete Legacy-Re-Export-Shims gelöscht (screens/dashboard/{chat_screen,dashboard_home_screen}.dart, 0 Importe); rohes NUL-Byte in chat/chat_screen.dart durch \u0000-Escape ersetzt (Datei war für grep/Tooling "binär"). Reine Dart-Fixes → OTA.
- [ ] Audit-Folgepakete: M5 Error-States (StreamBuilder/Provider ohne hasError-Branch: chat_live_banner, notifications, livestream_chat, global_search), M7 Effekt-Performance (Offscreen-Ticker bloom/light_leaks, fehlende RepaintBoundary atmospheric_layers, Paint-Caching in paint()), i18n-Verstöße (8+ hardcodierte DE-Strings: badges/skills/ratings_hub/module_posts/knowledge/timebank/groups/voice_dictation_button + location_onboarding_modal) → mit Phase-3/5-Umsetzung.

## Ad-hoc (2026-06-06)
- [x] [!] Speicher-/Cache-Audit + Fix (vor Marketing/KI-Reaktivierung, gegen "App wird langsam & crasht"): (1) Image-Cache-Limits ergaenzt wo ganz fehlend — image_lightbox (memCacheWidth 1600), wikipedia_box (150), story_viewer (1080), nasa_apod (1000); bewusst NUR Breite (beide Maße + BoxFit.cover = Verzerrung). Bereits gecappte (chat_message_bubble/similar_posts/barter = memCacheWidth) bleiben korrekt. (2) CallScreen Post-Call-Note: TextEditingController war im builder erzeugt + nie disposed -> jetzt ausserhalb + try/finally dispose. (3) NEU services/memory_watchdog_service.dart: Timer 60s Soft-Evict (clearLiveImages ab 80% Byte-Limit) + didHaveMemoryPressure (full clear) + onAppPaused (clearLiveImages) + clearAll() fuer manuellen Reset; global in MensaenaApp.initState gestartet/dispose gestoppt. (4) Settings "Cache leeren"-Button (settings.clearCache/clearCacheDone/sections.storage, 7 Sprachen). AUDIT-BEFUND: Pagination (admin_users RPC, crash_logs .limit, organizations .limit) bereits ok; Realtime-Channels (presence/chat) bereits mit Cleanup; LiveLocationService start() ruft stop() zuerst (kein Leak); LiveRoom dispose() sauber. PaintingBinding-Limits in main.dart (200/64MB, Lite 100/32MB) bestaetigt korrekt. Reiner Dart-Fix.
- [x] Marketing-Admin Phase 1 (Flutter, Route /dashboard/admin/marketing): Uebersicht (RPC marketing_dashboard_stats) + E-Mail-Kampagnen (Liste/Create/Send via send-email-campaign Edge Function -> nutzt send-email pro Empfaenger, Audit in email_sends) + Push-Kampagnen (send-push-campaign -> notifications + Trigger-Push, notify_guard pro Empfaenger) + Segmente (live counts via marketing_segment_counts) + Notbremse (set_marketing_paused RPC). send-email um Resend-Pfad (optional) + Pflicht-Footer erweitert; SMTP Lima-City bleibt Default (DNS bereits via Cloudflare konfiguriert -> docs/MAIL_SETUP.md). Bugfix reactivate-dormant: profiles.region statt region_id. i18n marketing.* in 7 Sprachen.
- [x] Marketing Phase 2: Vorlagen-Editor (message_templates) + Empfehlungs-Uebersicht (marketing_referrals_overview) + Region-Manager (marketing_regions_overview, signal-Farben). i18n 7 Sprachen. Bugfix referrals.inviter_id/status=accepted.
- [x] Marketing Phase 3 (Automatik, Backend): C13 Eskalation 7/21/45 in reactivate-dormant + reactivation_log; C12 auto-milestones-dates (Cron 09:30, Jubilaeen + Hilfe-Schwellen); C14 award_referral_milestones-Trigger (3/5/10 -> Karma+Badge+Gratulation); C17 region-ignite-alert (Cron 10:00, >=20 aktiv -> Admin+KI-Tipp). testimonials um rating/interaction_id/consent_public erweitert. Alle 4 Cron-Jobs aktiv.
- [x] Marketing Phase 3 Rest: C16 auto-winback (verbleibender erlaubter Kanal sparsam, marketingGuard, Cron Mi 15:00). C19 feedback-after-help (Cron taegl. 16:00, Bitte um Erfahrungsbericht nach completed interaction, Dedupe via metadata.interaction_id).
- [x] Marketing Phase 4: B9 Content-Planer (Flutter 9. Tab, content_plan-CRUD, share_plus, manuelles Veroeffentlichen) + C15 auto-smart-timing (best_hour aus campaign_events -> send_time_pref) + C18 auto-social-content (KI->teilbare Posts als Entwurf, kein Auto-Posting) + C20 auto-health-report (KI-Wochenbericht -> Admin-Notif + optional Owner-Mail). [SQL] content_plan/send_time_pref/campaign_events (Migration 20260606170000, RLS admin). pg_cron-SQL in docs/MARKETING.md. i18n marketing.{tab_content,cp_*} 7 Sprachen.
- [ ] Marketing pg_cron-Jobs fuer Phase-4-Functions im SQL-Editor anlegen (SQL in docs/MARKETING.md) + optional Secret MAIL_OWNER/app_settings.owner_email fuer Health-Report-Mail.
- [x] Marketing/Retention-System (DSGVO, Flutter-fokussiert): notify_guard.ts (Notbremse+Opt-out+Frequenz+stille Zeiten), reactivate-dormant (Cron 17:00 UTC), ai-weekly-recap +share_text, Settings-Opt-out-Toggles, WeeklyRecapWidget Teilen-Button. [SQL] profiles opt-in-Spalten + email_confirmations + community_recaps.share_text + marketing_paused. docs/MARKETING.md.
- [ ] Marketing OFFEN: E-Mail-Willkommensserie (send-welcome-email/confirm-email + Double-Opt-in-Toggle + Mailtexte 7 Sprachen), Meilenstein-Feier-Sheet (CelebrateBurst -> Teilen/Einladen), Next.js Region-Landingpages /regionen/[slug] + sitemap.
- [x] [!] Fix Wiki-Generator 'Veroeffentlichen geht nicht': ai-wiki-draft setzte keinen slug (NOT NULL ohne Default) -> Insert scheiterte -> Entwurf kam mit id=null -> Publish-Button no-op. slug aus Titel + Suffix ergaenzt. Reiner Server-Fix (Function-Redeploy via supabase.yml), kein APK noetig.
- [x] Shorebird-Workflow-Cleanup: ungueltigen `shorebird-version`-Input aus allen 3 Workflows entfernt (Action hat ihn ignoriert -> Warning). `--platforms=android` (Plural, ungueltig) in shorebird_release.yml und shorebird_patch.yml auf `--platform=android` (Singular) korrigiert. Update-Pipeline ab jetzt 100% gyquj. Funnel ab 4.0.0 verifiziert: UpdateGate sieht latest=4.1.4 mandatory in gyquj -> alle 4.0.x/4.1.x-Nutzer werden forciert; Alt-Nutzer (huaqld) ueber 4.1.3-Bruecke nach gyquj.
- [x] [!] Shorebird-OTA-Bug gefunden+gefixt: `releases list --platforms` (Plural) war ungueltig -> Patch wurde IMMER uebersprungen (OTA lieferte nie). Jetzt --platform. Versions-Pin-Input wird von setup-shorebird ignoriert (CLI driftet) -> offen/Hinweis.
- [x] [force-update] release 4.1.4+40104 — liefert KI-Features (Assistent + 8 Funktionen + 6 UI-Buttons + Wiki-Generator + Chat-Translate) als Pflicht-APK an gyquj.
- [x] Update-Pipeline gyquj-only: huaqld-Dual-Write aus flutter.yml entfernt; Patches+Pflichtupdates gehen ab jetzt NUR nach gyquj. shorebird_patch.yml ohnehin 0 huaqld. Einmalige 4.1.3-Pflichtzeile in huaqld bleibt als Funnel fuer Altnutzer.
- [x] KI-Zusatzfunktionen (8) auf gemeinsamer Fallback-Kette: _shared/ai.ts (callAiChain) + _shared/util.ts; chat-ai refactored. ai-improve-post/classify-post/translate/moderate/wiki-draft/crisis-summary/match-reason/weekly-recap. Flutter ai_features_repository.dart (lokale Heuristik für Klassifikation+Moderation zuerst, Kostenschutz)
- [x] [SQL] crises.ai_summary+ai_summary_at, ai_chat_analytics.feature, community_recaps (auf gyquj angewandt)
- [ ] [!] pg_cron-Job für ai-weekly-recap anlegen (SQL siehe unten / Antwort) — 1x/Woche Mo 9:00
- [x] UI A "Mit KI verbessern" im Module-Create-Screen (Dialog Übernehmen/Verwerfen, i18n assistant.improve_* in 7 Sprachen)
- [x] UI C "Übersetzen" an PostCard (inline, Original-Toggle), F Krisen-Summary, G Match-Begruendung — i18n 7 Sprachen
- [x] UI E KI-Wiki-Generator (Admin-Screen + Route /dashboard/admin/wiki-ai + Quick-Action-Button) und H KI-Community-Recap im WeeklyRecapWidget (liest community_recaps). Alle 6 KI-Buttons (A/C/F/G/E/H) verdrahtet.
- [x] C Uebersetzen auch an Chat-Nachrichten (TranslateInlineButton in chat_message_bubble, nur fremde Texte)
- [x] KI-Wiki-Generator umgebaut: Solo-Admin-Screen entfernt -> wiederverwendbares Sheet (showAiWikiGenerator) mit "Direkt veroeffentlichen"/"Als Entwurf"; Admin-only FAB in KnowledgeScreen (= Wiki UND Bildung) + Button im Admin-Dashboard
- [x] Shorebird-Patch-Guard: skippt bei Versions-Bump (Patch nur fuer Dart-only-Commits ohne Bump). shorebird_patch+release bereits 100% gyquj (0 huaqld)
- [x] [!] Update-Bug behoben: Bestandskunden zeigten auf huaqld, app_releases-Pflichtzeile lag aber nur in gyquj. Brücke: 4.1.3 mandatory in huaqld nachgetragen + flutter.yml schreibt jetzt Dual (gyquj+huaqld, optional SUPABASE_SERVICE_ROLE_KEY_HUAQLD). OTA-Patch-Befund: jeder Push bumpt Version -> shorebird_patch patcht brandneue Version ohne Nutzerbasis -> Patches erreichen niemanden (Architektur, nicht Reihenfolge)
- [x] Supabase-Migration huaqld → gyquj komplett (DB 161 Tab./49 Logins, Storage 15 Buckets, private-Schema, 9 Edge Functions, Cron, URL-Rewrites) + App-Cutover (PR #583 gemergt, Web live + APK 4.1.3 Pflicht-Update)
- [x] Mensa KI-Assistent von Grund auf: Edge Function chat-ai (4-Provider-Fallback) + chat_ai_repository + chat_ai_provider + mensaena_assistant_fab (in dashboard_scaffold, ersetzt MensaenaBotButton) + i18n assistant.* in 7 Sprachen
- [x] [SQL] ai_chat_analytics + ai_chat_feedback (auf gyquj angewandt, RLS aktiv)
- [ ] Mensa: optionaler einmaliger Pulse-Hinweis beim ersten Öffnen komplexer Screens (Karte/Beitrag) via flutter_secure_storage — offen
- [ ] Canva-Connector für Agent-Session freigeben (Asset-Generierung), aktuell nicht durchgereicht

## CACHE — Mega-Prompt v2.1 Status (2026-05-27)
OPEN=Phase 0 + 1 + 2 (8/8) + 3 (4/5: F12+F13 done, iOS-PiP defer) + 5 + 6 (ZUSATZ-4 done) + 7 + 8 + 9 + 10 (Sektionen+E3/E4/E6/E9/E10) + 11 PiP + 12 (S8 done) + 14. 40+ Commits.
COUNT=v2.1 spezifisch (seit Session-Start): L1 reports + L5/L8/L9/L11/L12 constraints + F13 Cap 10 + S8 create_post raus + Books-Widget raus + QuickActions ohne Posten + ZUSATZ-4 Friends + ZUSATZ-3 PiP (Call+Group+Livestream) + Phase-10 6-Sektionen + E3/E4/E6/E9/E10 Widget-Konsolidierung + F38 Post-Reactions + F50 Streak-Freeze.
NEXT=Verbleibende Defer-Items größerer Brocken: F12 Screen-Share + F13 Group-Calls (Android-Permissions/Architektur), F28 Message-Requests-für-Fremde (UX-Design), F22 Notification-Grouping (Backend-Rollup), F38 Scheduled Posts (DB+UI+Cron), F76 Chat-Summarization (ML), F52 Vorlesefunktion (Package-Add). Phase 11 P22 R8/ProGuard war früher deaktiviert (Crash-Risiko).
LAST_SESSION=2026-05-27
LAST_TASK_PHASE0=L3+L4+L6+L7+L8+L13+L15+L16+L18+L23+L24+L25+L26+L34+L35+L44+L45+L48+L51+L55+L56 live
LAST_TASK_PHASE1=BUG1+BUG2+BUG3+F26+F27 live. F28 defer.
LAST_TASK_PHASE2=F4+F5+F6+F7+F8+F9+F10+F25 alle live ✅
LAST_TASK_PHASE3=F11+F14+F15 live. F12+F13 defer.
LAST_TASK_PHASE5=F23+F30+F32+F33 live. F22+F24+F31 defer.
LAST_TASK_PHASE6=F34+F35+F36+F37+F71 live. F59 da, F69 da, F74 defer.
LAST_TASK_PHASE7=F39+F42+F56+F60+F64+F66+F70+F75+F77+F80 als existing verifiziert. F38+F40+F41+F67+F76 offen.
LAST_TASK_PHASE8=F43+F44+F45 alle live ✅
LAST_TASK_PHASE9=F46+F47+F48 existieren (Leaderboard, daily_challenges, badges).
LAST_TASK_PHASE10=Foundation (DashboardWidgetConfig + WidgetGridSettings + DisabledWidgetsBar + DashboardEditBanner) da. DW-A Long-Press-Jiggle nicht im dashboard_home_screen verdrahtet.
LAST_TASK_PHASE11=P21 effectiveReduceMotion auf CelebrateBurst durchgereicht (war auf Basis-Toggle). P22 R8 historisch deaktiviert wegen Crash, nicht reaktiviert.
LAST_TASK_PHASE12=F53 SeniorMode in A11yPrefs, F54 weekly_recap_widget, F55 community_pulse, F58 UpdateGate, F72 sleep_reminder, F83 OLED-dark — alles existing. F52 Vorlesefunktion offen (braucht flutter_tts).
SPLASH=Dauer 2.6s → 4.2s erhöht.
LAST_TASK=feat(modul-audit Sprint 5): WikipediaBox-Widget (Post-Detail bei Animal/tags), TranslateInlineButton (LibreTranslate für Chat-Messages, Auto-Detect + Toggle), Event-Detail-1-Tap In-Kalender-Button (add_2_calendar) + .ics-Fallback, BetterFeedback (shake_to_report-Style via 3-Finger-Long-Press, Submit → error_logs mit Screenshot-Bytes). Total Modul-Audit (5 Sprints): 35+ Items live, 10+ neue Services, 5+ neue Widgets, 9 neue Packages.

## Flutter-Migration
- [x] Phase 1 – Setup (Theme, Router, 48 Models, 12 Services, Landing+Auth) — flutter analyze 0 issues, APK 18.3 MB
- [x] Phase 3.1 – Dashboard-Home + Scaffold:
  - [x] DashboardHomeScreen (Greeting + 4 Stats parallel via Future.wait + Quick-Actions + Feed)
  - [x] DashboardScaffold (AppBar mit NotificationBell, AppDrawer mit 6 Gruppen + Admin, BottomNav 5 Items)
  - [x] ProfilesRepository, PostsRepository (get_nearby_posts RPC + Fallback), NotificationsRepository (Realtime), InteractionsRepository
  - [x] notificationsStreamProvider + unreadNotificationCountProvider
  - [x] PostCard mit Typ-Badge (13 Typen) + relative Zeit
  - [x] StatCard mit Loading-Skeleton
  - [x] flutter analyze 0 issues, APK 19.0 MB
- [x] Phase 3.2 – Map-Screen: flutter_map + MarkerClusterLayerWidget + OSM-Tiles + get_nearby_posts RPC + Radius-Slider (5/10/25/50/100km) + GPS-Recenter-FAB + Bottom-Sheet auf Marker-Tap (13 Typ-Emoji + Cinema-Farben)
- [x] Phase 3.3 – Create-Post 3-Step Wizard: Art (13 Typen Grid) → Inhalt (Titel + Beschreibung + Bilder via image_picker + Tags + Anonym-Toggle + Intent-Classifier-Hint) → Kontakt (Standort mit GPS-Button + Telefon/Email/WhatsApp + Privacy-Toggles + Urgency 0-4). Bild-Upload nach post-images Bucket. check_rate_limit (2/min, 10/h). Direkt-Insert in posts, dann context.go(/dashboard/posts/[id])
- [x] Phase 3.4 – Posts-List (Filter-Chips fuer 11 Typen + 'Alle', FAB→Create) + Post-Detail (Hero mit Bild-Carousel + Typ-Badge + Tags + Stats, Helfen-Button → interactions INSERT, Vote Up/Down toggle, Save toggle, Share → share_plus, Report → Bottom-Sheet mit 6 Gruenden, Comments threaded mit Inline-Input)
- [x] Phase 3.5 – Chat-Screen (Realtime via Supabase Stream auf messages, gefiltert nach conversation_id, mark_read on open, Send-Button + Enter, Bubble-Layout mit mine/other)
- [x] Phase 3.6 – Messages-Screen (Konversations-Liste sortiert nach updated_at, Avatar + Title + Zeit, Tap → /messages/[id])
- [x] Phase 3.7 – Notifications-Screen (notificationsStreamProvider, Tabs: Alle/Ungelesen/Nachrichten/Interaktionen/System, Tap markiert gelesen + navigiert zu .link, Cinema-Farbe + Icon pro Kategorie)
- [x] Phase 3.8 – Profile-Screen (eigenes oder fremdes via userId, Avatar + Trust-Badge + Stats-Grid Impact/Punkte/Spenden + Bio + Skills-Chips)
- [x] Phase 3.9 – Settings-Screen (5 TabBar-Tabs: Account/Privatsphaere/Benachrichtigungen/Standort/Konto, Privacy 5 BoolTiles + Visibility-Pills public/neighbors/private, Notif 7 BoolTiles, Region Radius-Slider 1-150km, Danger Logout + DSGVO-Hinweis)
- [x] Phase 3.10 – Interactions-Screen (aktive Interactions pending/accepted/on_way/arrived, StatusBadge mit Cinema-Farbe)
- [x] Phase 4.1 – Crisis-Modul (lebensrettend, hoechste Prioritaet):
  - [x] models: crisis_helper, crisis_update, emergency_number
  - [x] crisis_repository mit Realtime-Streams (watchHelpers, watchUpdates), offerHelp, addUpdate
  - [x] CrisisDashboardScreen — Liste aktiver Krisen mit Urgency-Borders + Helper-Count + Notruf-CTA
  - [x] CrisisDetailScreen — Live Helper-Count (crisisHelpersStreamProvider), Update-Feed (crisisUpdatesStreamProvider), Contact-Block mit Anruf-Button, 'Ich helfe'-Bottom-Sheet mit Message+ETA
  - [x] CrisisCreateScreen — 6 Kategorien + 4 Urgency-Stufen + GPS-Button + 112-Hinweis-Banner
  - [x] CrisisResourcesScreen — emergency_numbers nach Kategorie gruppiert, Tap → tel:
- [x] Phase 4.2 – NINA-Warnungen + Lebensmittelwarnungen:
  - [x] WarnungenScreen: NINA-API via nina_service (15min Cache), Severity-sortiert, Detail-Sheet mit Handlungsempfehlung
  - [x] FoodWarningsScreen: direkter BVL-API-Fetch, Link → externer Browser
- [x] Phase 4.3 – Zeitbank:
  - [x] timebank_repository (listMine, balance, create, confirm, reject, watchUnseenNotifications Realtime-Stream)
  - [x] zeitbank_notification model
  - [x] TimebankScreen: Balance-Card (given/received/balance/pending), Historie mit Bestätigen/Ablehnen Inline-Buttons fuer Empfänger
- [x] Phase 4.4 – Auth-Reset-Mode (2026-05-24): `_AuthMode.reset` + PASSWORD_RECOVERY-Listener + Confirm-Field + sb.auth.updateUser → signOut → back-to-login. Email-Enumeration-Schutz im forgot-Submit (generische Message). 1:1 zu Web src/app/auth/page.tsx.
- [x] Phase 4.5 – Chat-Pinned-Messages (2026-05-24): MessagesRepository.watchPinnedMessages + togglePin + listAnnouncements. _PinnedMessagesPanel als Stream-Widget oben im Channel. Pin-Action im Bubble-Long-Press-Sheet (nur Channels). 1:1 zu Web ChatView.tsx PinnedMessages.
- [x] Phase 4.6 – Admin-Tabs Schema-Fix (R6) (2026-05-24): crisis_situations→crises, farm_listings.is_bio entfernt, contact_messages/bot_feedback/marketing_campaigns gegen organization_suggestions/bot_scheduled_messages/audit_logs ersetzt (echte Tabellen aus AI_CONTEXT §4). Admin-Dashboard-Tiles entsprechend updated.
- [x] Phase 5.1 – Chat: @-Mention-Autocomplete (2026-05-24): _detectMention mit 150ms-Debounce, _loadMentionSuggestions via profiles.or(nickname/name/display_name.ilike), Dropdown-List ueber Composer mit Avatar+Name+@nick, _insertMention ersetzt @token im Cursor-Bereich
- [x] Phase 5.2 – Chat: Voice-Recorder (2026-05-24): record:^5.1.2 + audioplayers:^6.0.0 Packages (R7-Begruendung: 1:1 zu Web VoiceRecorder.tsx — keine Alternative); VoiceRecorderService (start/stop/cancel/upload/encode/decode); chat-voice-messages Storage-Bucket mit RLS (own-folder INSERT, public READ); VoiceMessageBubble mit Play/Pause + Pseudo-Waveform (16 vertical bars + Progress); _VoiceRecorderButton im Composer (Tap startet, Stop/Cancel waehrend Aufnahme); Message-Format `[VOICE:url:seconds]`
- [x] Phase 5.3 – Chat: In-Chat-Search (2026-05-24): _ChatHeaderBar mit Search-Toggle, AnimatedSize slide-in TextField, lokaler msg.content.contains(query) Filter ueber Stream-Daten
- [x] Phase 5.4 – Trust-Ratings-Flow (2026-05-24): TrustRatingsRepository.rate + myPendingToRate + getBreakdown; TrustRatingModal (5 Sterne + Kategorien-Chips + Comment + Helpful/Recommend-Toggles + Submit mit calculate_trust_score RPC); _RateButton in interactions_screen wenn status='completed' + partner not yet rated
- [x] Phase 5.5 – Account-Deletion + Data-Export (2026-05-24): _DangerTab umgebaut zu StatefulWidget; _exportData parallel-fetch von profile/posts/comments/messages/interactions/trust_ratings/notifications/saved_posts/badges → JSON via Share.shareXFiles (DSGVO Art. 20); _deleteAccount 3-Stage-Flow (Warning → typed "LOESCHEN" → RPC delete_my_account mit Fallback auf is_banned/anonymize)
- [x] Phase 5.6 – Multi-Image-Carousel in PostCard + Post-Detail (2026-05-24): ImageCarousel-Widget (PageView + Index-Counter top-right + animated Indicator-Dots bottom + Tap-zur-Lightbox); Post-Model um imageUrls erweitert (image_urls[] Spalte) + allImageUrls Getter (image_urls + media_urls merged); PostCard zeigt Carousel zwischen Description und Action-Bar; Post-Detail Hero nutzt jetzt shared ImageCarousel statt eigenes PageView
- [x] Phase 5.7 – Comments-Reply-Nested (2026-05-24): _buildCommentTree depth-1 (Roots + indented Replies via parent_id-Map); _CommentTile.onReply setzt _replyToParentId+_replyToAuthor; Reply-Banner ueber _CommentInput mit Author-Name + X zum Abbrechen; PostCommentsRepository.add nimmt parentId
- [x] Mega-Prompt 80+Features Phase-2-12 (2026-05-27): Foundation + Kernfeatures gepusht.
  - **SQL**: 19 neue Tabellen/Spalten in einer Migration. Stories+story_views, user_follows, profile_views, post_polls+_votes, dm_calls(ended_at,duration_seconds), event_photos, events(recurrence_rule,parent_event_id), mentorships, thank_you_cards, community_polls+_votes, livestream_messages+_gifts+_polls+_votes+_clips, profiles(is_verified,verified_at,neighborhood_group_id), live_rooms(scheduled_for,recording_url,category,description,thumbnail_url,viewer_count,max_viewers), daily_challenges, live_locations, messages.auto_delete_at, conversation_members.vanish_mode, posts.scheduled_for.
  - **Foundation Flutter**: mega_models.dart + mega_repositories.dart (FollowsRepo, ProfileViewsRepo, DailyChallengesRepo mit Auto-Pool, ThankYouCardsRepo, CommunityPollsRepo, StoriesRepo, MentorshipsRepo, LivestreamMessagesRepo Stream, LivestreamGiftsRepo, LeaderboardRepo) + mega_providers.dart (13 Provider).
  - **Phase 5 F23 NotificationRouter**: zentrale Map type/category/metadata → go_router. NotificationsScreen + PushNotificationService nutzen es. rootRouter aus app.dart.
  - **Phase 6**: VerifiedBadge (F35), FollowButton (F36), ProfileViewsRepository.recordView (F37), LeaderboardScreen mit Podest (F46), DailyChallengesWidget mit 7-Pool-Auto-Generator (F47), CommunityPollsScreen mit Voting+Live-Balken (F72).
  - **Phase 4**: LivestreamChat mit Realtime-Subscription, Reactions, Gifts (Karma-Trigger).
  - **Phase 11**: StoriesRing oben im Dashboard (Bronze-Gradient + Galerie-Upload), StoryViewer Fullscreen mit Progress-Bars + Tap-Navigation. F83 oledMode + F53 seniorMode in A11yPrefs.
  - **R17 Block-Check**: UserBlocksRepository.isBlockedEitherWay (beidseitig).
  - **Crash-Fix Biometric**: Auto-Prompt entfernt (Endlos-Loop bei stickyAuth=true).
  - Offen für nächste Sessions: PiP-Modus (F29), Group-Calls (F13), Stream-Recording/Clips Egress (F18/F86), Co-Host Hand-heben (F20), Quick-Actions FAB-Menu (F33), Swipe-Gesten (F30), Pull-to-Refresh-Branding (F31), Voicemail (F15), Vanish-Mode-UI (F10), Typing-Indicator (F4), Read-Receipts UI (F5), Message-Forward+Quote (F7), Heatmap-Map-Layer (F43), Live-Location-Sharing UI (F45), QR-Profil-Share (F34), Mentoring-Screen UI (F69), Thank-You-Card-Sender UI (F71), Stories-Camera-Capture (F59-erweitert), Recurring-Events UI (F63), Event-Check-In QR (F61), Event-Photos-Gallery (F62), Daily-Digest-Notification (F74), Offline-Queue (F56), Crash-Analytics-Boundary (F81).
- [x] Mega-Contact-System (2026-05-26): Intent-basiertes Kontakt-System fuer Posts. SQL-Migration: posts.post_intent + post_contact_preferences + post_contact_requests + Trigger (notify_contact_request, contact_completed_karma). Models PostIntent (10 Werte) / PostContactPreference / PostContactRequest. Repository PostContactRepository mit R7-Datenschutz (getRevealedContactInfo) + R17 Duplikat-Schutz. 7 Providers (FutureProvider.family). UI: PostIntentSelector + ContactPreferenceSelector + PostContactActions (10 Intent-Layouts) + ContactRequestsManager + ContactRequestsScreen + AppDrawer-Badge. Route /contact-requests. i18n contact.* + post_intent.* in DE+EN (5 weitere fallen auf DE zurueck).
- [x] Phase 4 Mega-Roadmap KOMPLETT (2026-05-26): 28 Features ueber 4 Sub-Phasen — Quick-Wins, Core Community, Karten/APIs, Module. Alle on-device wo moeglich (Streak/Detox/Karma/Gratitude/Heatmap/QuickNote/Affirmation/MoonPhase/SavedPins) — keine DB-Migrationen noetig. i18n in allen 7 Sprachen (de/en/es/fr/it/ru/tr). flutter analyze = 0 issues durchgehend.
  - **Phase 1 Quick-Wins (6):** F4 Micro-Interactions/Konfetti · F7 Skeletonizer-Migration · F15 Biometric App-Lock · F20 Accessibility-Suite (TextScale + ReduceMotion + HighContrast) · F38 Login-Streak · F41 Digital Detox
  - **Phase 2 Core Community (8):** F30 Gratitude Journal · F31 Karma Points System (5 Levels: Nachbar/Helfer/Stuetze/Anker/Leuchtturm) · F33 Activity-Heatmap (12-Wochen Contribution-Grid) · F40 Wochenrueckblick (7d vs 7d-davor) · F45 Quick-Note (Sticky-Note) · F46 Personal-Best Lifetime-Spitzenwerte · F47 Tages-Affirmation (7er-Pool) · F48 Release-Notes-Sheet
  - **Phase 3 Karten/APIs (6):** F50 Help-Streak (Tage in Folge mit Hilfe) · F60 Mondphase-Widget (Astro-Math) · F61 Air-Quality-Layer (Open-Meteo PM2.5/PM10/O3/NO2/SO2/CO) · F62 Map-Tile-Style-Toggle (Auto/Voyager/Topo) · F63 Sun-Path-Sheet (Halbkreis-Diagramm) · F64 Saved-Pins (Long-Press → User-Marker)
  - **Phase 4 Module (12):** F70 Activity-Heatmap im Profile-Screen · F80 Mood-Streak Badge · F81 Profile-Share-Button · F82 Post-Copy-Link · F83 Read-Time-Chip (≥60 Worte) · F84 Notification-Tab persistent · F85 Posts-Filter persistent · F86 Today-Events-Widget · F87 Chat-Char-Counter · F88 Settings Bug-Report mailto · F89 Posts-Empty-State CTA · F90 Map-Pin-Hint
  - **Infra-Fixes (2):** flutter.yml + shorebird_patch.yml Retry-Backoff 5x bei 5xx/Network-Errors fuer app_releases-Insert; src/app/sitemap.ts Per-Query AbortController 20s + Limit 5000→1000 — verhindert dass langsame Supabase-Edge den Build crasht
- [x] Phase 6 – LiveKit-Secrets Setup (2026-05-24): User hat KEY+SECRET aus /opt/livekit/docker-compose.yaml via `docker compose config | awk '/keys:/{f=1;next}/redis:/{f=0}f'` extrahiert (Key APImsn6f2c8fd70b21c369, Secret 40-char). Verifikation gegen wss://livekit.mensaena.de: HMAC-Signature wird akzeptiert (Permission-denied bei CreateRoom ist erwartet, da Token nur roomJoin hat — fuer echte Calls reicht das). INSERT in private.push_config; Edge-Function-Diagnose zeigt has_key:true, has_secret:true.

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

- [x] feat(ui): C3 — Mobile-Header: Search/CommandPalette-Button ergänzt (openCommandPalette + Search Icon) — Desktop hatte SearchBar+⌘K, Mobile hatte keinen Zugang
- [x] fix(calls): LiveKit VPS-Credentials (SELF_URL/KEY/SECRET) zurück in wrangler.toml [vars] — in 42a621c entfernt aber Cloudflare Secrets nie gesetzt → pickServer() warf "not configured" → 500
- [x] fix(calls): Live-Room /api/live-room/token + /notify: export const runtime = 'nodejs' ergänzt — livekit-server-sdk JWT-Signing braucht Node-Crypto, Edge-Runtime nicht kompatibel → "Verbindung fehlgeschlagen" behoben
- [x] fix(chat): TS-Fehler — ConnectionQuality[quality] Enum-Reverse-Lookup → explizites Label-Mapping (LiveRoomModal); ?? || Klammern (ChatView + MessageGroup) → Community-Livestream Runtime-Error behoben
- [x] fix(ui): C2 — Safe-Area-Inset für Capacitor: Header inline-style env(safe-area-inset-top), main pt-[calc(3.75rem_+_var(--sai-top))] md:pt-0, BottomNav inline-style env(safe-area-inset-bottom)
- [x] fix(calls): #27 — Chat-Scroll im LiveRoom: chatContainerRef+isChatNearBottomRef, onScroll-Handler, scrollIntoView nur wenn nahe am Ende (< 60px)
- [x] fix(calls): #23 — Kamera-Wechsel Schwarzbild: Pause 200→100ms, isFlipping-Prop in ParticipantTile, SwitchCamera-Spinner als Platzhalter
- [x] perf(chat): B7 — Supabase-Queries parallelisiert: loadAnnouncements als useCallback extrahiert, loadChannels+loadConversations+loadAnnouncements via Promise.all beim Mount statt sequentiell
- [x] perf(chat): B5 — LiveRoomModal lazy laden: loading-Spinner ergänzt in ChatView.tsx + GlobalCallListener.tsx (dynamic import mit ssr:false war bereits vorhanden)
- [x] feat(calls): #43 — Android Foreground Service: useCallForegroundService Hook, AndroidManifest Permissions+Service+Receiver, ic_stat_call Drawable, LiveRoomModal+GlobalCallListener Integration, Auflegen-Button in Notification
- [x] fix(calls): #40 — Spezifischer Fallback bei LiveKit-Ausfall: Netzwerkfehler-Erkennung (fetch/network/Failed) → "Sprachanrufe nicht verfügbar, bitte Text-Chat nutzen" (6s), sonst msg-Detail (4s); in OutgoingCallScreen + IncomingCallScreen
- [x] fix(calls): #41 — Countdown statt Hochzählen: "Klingelt noch Xs" + Rot-Warnung <10s in IncomingCallScreen + OutgoingCallScreen
- [x] fix(calls): #33 — Einheitliche System-Call-Nachrichten: end-Route Dauer optional, cancel-active 'abgebrochen' statt 'beendet', alle 4 Routes vereinheitlicht
- [x] fix(calls): #21 — Bestätigungsdialog vor Anruf: confirmCall-State, createPortal-Dialog mit Backdrop-Click+Abbrechen+Anrufen-Button
- [x] fix(calls): #19+#22 — DM-Header Anruf-Buttons prominent: rounded-full bg-primary-50 min-44px, separater Video-Button mit w-5 h-5 Icon
- [x] fix(calls): #14 — PhoneOff rotate-[135deg] aus Ablehnen-Button entfernt
- [x] fix(calls): #10 — CallTimer ab answeredAt: LiveRoomModal+ActiveCallState+activeDMCallSession um answeredAt erweitert, Timer berechnet Sekunden aus Date.now()-answeredAt bei Remount
- [x] fix(calls): #9+#34 — [SYSTEM_CALL]-Karten: zentrierte Karte mit Icon+Label, Zurückrufen-Button bei verpassten eingehenden Anrufen, parseSystemCallMessage-Helper
- [x] fix(calls): #8 — visibilitychange Call-Status-Check: IncomingCallScreen + OutgoingCallScreen fragen DB bei Tab-Rückkehr ab, schließen Screen wenn ended/declined/missed/cancelled
- [x] fix(calls): #6 — Verbindungs-Feedback nach Annehmen: Loader2-Spinner + Text während Token-Fetch, Buttons ausgeblendet
- [x] fix(calls): #39 — skipWaiting() wartet auf Client-Signal: self.skipWaiting() aus install entfernt, message-Handler SKIP_WAITING ergänzt
- [x] fix(calls): #38 — Push-Notification Auto-Close: incoming=null→SW close(tag=incoming-call), sw.js schließt Call-Notification bei nicht-call Push
- [x] fix(calls): #30 — Push-Accept/Decline URL-Parameter in ChatView verarbeiten: action=accept→answer-API→activeDMCallSession, action=decline→decline-API+toast, URL sofort bereinigt
- [x] fix(calls): #18 — Klingelton-Fallback bei gesperrtem Audio: Vibration+500ms-Retry in ringtone+dial-tone, AudioContext-Priming in GlobalCallListener
- [x] fix(calls): #32 — Decline auf Callee beschränkt: or()-Query→eq(callee_id), in(['ringing']) Status-Guard
- [x] fix(calls): #31 — Cancel bei gleichzeitiger Annahme: active-Call-Fallback, Duplikat-Check Systemnachricht, alreadyEnded 200 statt 404
- [x] fix(calls): #28 — Gebannte User können keine Anrufe mehr starten: isBanned in Phone+Video-Buttons (+ outgoingCallState), server-seitiger Ban-Check in /api/dm-calls/start
- [x] fix(calls): #16 — Stale-Cleanup killt keine aktiven Calls mehr: STALE_CUTOFF 120_000ms, nur 'ringing' bereinigen, ACTIVE_CUTOFF 4h für Zombie-active-Calls, initialCallId-Guard verhindert Push-Accept 404, load-Query auf ACTIVE_CUTOFF umgestellt

- [x] fix(chat): Bug4 — Input-Freeze behoben: DB-Query aus handleInputChange entfernt (broadcastTyping(myDisplayName)), @mention-Detection in useEffect mit 150ms Debounce verschoben, handleInputChange synchron
- [x] ci(android): cap add android überspringt wenn android/ im Repo liegt, F-Droid rebase setzt android/ zurück vor git rebase
- [x] fix(chat): Bug5+B1 — LiveCountdown-Komponente isoliert 1s-setInterval; now-State+setInterval aus ChatView entfernt; Auto-Scroll auf Container-Scroll; Input-Formulare sticky bottom-0
- [x] fix(chat): Bug6+B2+B3 — MemoizedMessageGroup=memo(MessageGroup); useTransition für Realtime-Inserts (community+DM messages, conversations); verhindert Input-Freeze bei neuen Nachrichten
- [x] fix(video): Video-Crash — ReferenceError: seconds is not defined in InnerRoom behoben; connectedAtRef-Pattern ersetzt direkten seconds-Zugriff; updateCallForegroundService läuft wieder
- [x] fix(chat): Bug7 — Optimistic Update für sendMessage: setNewMessage('')+setReplyTo(null)+setIsTyping(false) vor await checkRateLimit; Wiederherstellung des Texts bei Rate-Limit-Hit oder DB-Insert-Fehler
- [x] feat(livestream): A1 — Admin/Mod-Rolle ins LiveKit-Token: profiles.role als metadata=JSON.stringify({role}) in AccessToken; live-room/token/route.ts (Community) + lib/livekit/token.ts + dm-calls/answer/route.ts (DM-Calls) aktualisiert
- [x] feat(livestream): A2 — Admin/Mod-Badge im Livestream: getParticipantRole() Helper; ParticipantTile zeigt 🛡️ Admin (rot) / ⚔️ Mod (amber) als Overlay-Badge + Namens-Label
- [x] feat(livestream): A3 — Admin/Mod-Sortierung in Teilnehmerliste: rolePriority() admin=0/mod=1/user=2 vor bestehender Hand/Speaking-Sortierung; Rollen-Badge in Listeneintrag
- [x] feat(calls): #11 — Audio-Output-Wechsel: speakerActive-State; ControlButton enumerateDevices→filter audiooutput→switchActiveDevice; Lautsprecher/Ohrhörer-Toggle in Steuerleiste
- [x] feat(calls): #12 — Anrufhistorie-Komponente: CallHistory.tsx (dm_calls + profiles Query, 30 Einträge, Dauer/Zeit-Format, Anrufen-Button); Clock-Button im DM-Tab-Header; onCall öffnet DM + startet Anruf
- [x] feat(calls): #13 — Video-Preview vor Videoanruf: VideoPreviewModal.tsx (getUserMedia, Mirror-Spiegelung, Kamera-Stop bei Confirm/Cancel); Bestätigungsdialog leitet Videoanrufe durch Preview
- [x] feat(calls): #20 — Anruf-läuft-Banner bei Navigation: showLiveRoom-State; pathname-Effect verbirgt Modal statt Call zu beenden; grünes Banner mit Zurück-Button; onClose resettet showLiveRoom
- [x] feat(calls): #25 — Anruf-Ende-Sound: end-tone.ts (Web Audio API, 2×400Hz Beep, 0.12 Gain); playEndTone() in OutgoingCallScreen (decline/missed/cancel/timeout/visibility), IncomingCallScreen (timeout/ended/declined/visibility/handleDecline), LiveRoomModal.leave()

## Zeit
B1-B8: ~85h | Audit-Fixes: ~20-30h | Session G (2026-04-24): ~3h | Session H (2026-04-30): ~3h

## Mensaena-Flutter Welle 1-5 (2026-05-26)
- [x] feat(P1): Intent-Kontaktsystem (10 Intents, anonymisiert) – live
- [x] feat(P4): Livestream-Chat realtime + Reactions + Karma-Gifts
- [x] feat(P6): Follow/Profile-Views/Verifizierung/Polls/Leaderboard/Daily-Challenges/QR-Share
- [x] feat(P7): Marketplace-Preis-Indikator, Drafts-Screen, Scheduled/Expires-Posts
- [x] feat(P8): Live-Location-Share im Chat (15/30/60min)
- [x] feat(P9): Event QR-Check-in (Organisator zeigt / Attendee scannt)
- [x] feat(P10): Karma-History-Screen, Mentorship-Übersicht, Status-Text auf Profil
- [x] feat(P11): Stories (24h), OLED-Mode, Senior-Mode, Sleep-Reminder (zonedSchedule)
- [x] feat(P12): Account-Deletion (14-Tage-Frist + Cancel), JSON-Daten-Export (GDPR), Offline-Queue mit Connectivity-Auto-Flush, Cron-Jobs für scheduled/delete
- [x] feat(P5): Daily-Digest opt-in (pg_cron stündlich aggregiert)
- [x] DB: posts.scheduled_at/expires_at, profiles.status_text/emoji/until, event_checkins, user_streaks, karma_log, stream_clips, account_deletion_requests, crash_logs (alle mit RLS)
- [x] DB-Cron: publish_scheduled_posts_5m, execute_account_deletions_hourly, daily_digest_hourly
- [x] CI-Resilience: flutter.yml + shorebird_patch.yml 5x retry bei 5xx/Network
- [x] Bugfix-Welle: Map-GPS-Drift, Module-Filter-Default-On, 8+ Schema-Mismatches, Mundraub/E-Auto nwr-Query
- [x] Crash-Fix: Biometric Endlos-Loop entschärft (kein auto-prompt mehr)


