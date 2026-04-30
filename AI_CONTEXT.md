# MENSAENA – AI Context
> Aktualisiert: 2026-04-30 | v1.0.0-beta | Bug4–7 ChatView Performance + Video-Crash Fix + CI android.yml Fix + LiveKit Auth-Header-Fixes + A1–A3 Admin/Mod LiveKit-Features + #11 Audio-Output-Wechsel

## !! REGELN – LIES DAS BEI JEDER SESSION !!

### R0 LANGZEIT-CHAT
Dieser Chat läuft über viele Sessions. Bei Session-Wechsel (Timeout, Reload, nächster Tag) geht Chat-Kontext verloren. DESHALB:
- Lies bei JEDER neuen Session AI_CONTEXT.md + TODO.md erneut. Das dauert Sekunden und spart Stunden.
- NIEMALS den Chat-Verlauf nach oben durchsuchen – er ist möglicherweise abgeschnitten.
- Deine EINZIGE Wahrheit sind diese 2 Dateien. Was dort nicht steht existiert nicht.
- Der User gibt direkte Prompts ohne Prefix. Du verstehst sie aus den Dateien.
- Wenn du unsicher bist was der aktuelle Stand ist: lies die Dateien, frag NICHT den User.

### R1 JEDER PROMPT = UPDATE
Egal was passiert – Farbänderung, Bugfix, neues Feature, SQL, Config, Text, IRGENDWAS:
a) TODO.md updaten: Task [x] abhaken ODER unter "Ad-hoc" als [x] eintragen
b) AI_CONTEXT.md NUR updaten wenn: neue Datei/Tabelle/RPC/Spalte/Store/Hook/Dependency
c) Datum in beiden Dateien auf heute
d) Beides im selben Commit wie Code
KEINE AUSNAHME. AUCH BEI EINZEILERN.

### R2 FEHLENDE TABELLEN
Tabelle nicht unter §4 "Existierend"?
1. KEINE Migration-Datei im Repo
2. Komplettes SQL als 1 kopierbaren Block ausgeben
3. Darüber: "SQL AUSFÜHREN: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new"
4. SQL = CREATE TABLE+Constraints+Indexes+ENABLE RLS+Policies+updated_at Trigger+Realtime
5. Frontend mit Error-Handling falls Tabelle noch fehlt
6. Tabelle in AI_CONTEXT.md §4 von Fehlend→Existierend verschieben + Schema eintragen
7. Task in TODO.md mit [SQL] markieren

### R3 TOKEN-SPAREN
- NUR Dateien öffnen die du ändern musst
- AI_CONTEXT.md = Referenz (nicht DB/Dateien crawlen)
- TODO.md = Aufgabenquelle (nicht Chat durchsuchen)
- Steering-Files: nur geänderte Zeilen, nicht komplett neu schreiben
- Keine Architektur-Änderung → AI_CONTEXT.md NICHT anfassen
- Patterns nutzen statt Boilerplate:
  P:MODULE = ModulePage.tsx Pattern kopieren, nur Props ändern
  P:ADMIN_TAB = Tabelle+Suche+Pagination+Delete, Tailwind+Lucide
  P:CRUD_HOOK = useState+useEffect+supabase CRUD, Ref: useBoard.ts
  P:SQL_TABLE = CREATE TABLE+Indexes+RLS+Policies+Trigger+Realtime

### R4 SESSION-RECOVERY
Wenn du merkst dass du Kontext verloren hast (User fragt etwas und du weißt nicht wovon er redet, oder du bist unsicher über den Projekt-Stand):
1. Sage dem User: "Session-Wechsel erkannt, lese Steering-Files..."
2. Lies AI_CONTEXT.md + TODO.md
3. Mach weiter als wäre nichts passiert
Das kostet ~2000 Token statt ~50000 wenn du den Chat durchsuchst oder Dateien crawlst.

## §1 Projekt
Repo: github.com/manuelbrandner85/Mensaena (privat)
Live: mensaena.pages.dev | Domain: mensaena.de + www.mensaena.de (aktiv, SSL)
SB-ID: huaqldjkgyosefzfhjnf
SB-SQL: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
Owner: Manuel Brandner

## §2 Stack
Next.js 15.3.0 AppRouter 'use client' | React 19 | Tailwind 3.4 | Lucide | react-hot-toast | Zustand 4.5 | Supabase JS 2.43 + SSR 0.3 | Cloudflare Pages @opennextjs/cloudflare 1.6 | Leaflet 1.9.4+MarkerCluster | date-fns 3.6 | @fontsource/inter (local, kein Google Fonts fetch)
Deploy: npx opennextjs-cloudflare build && npx wrangler deploy
Auth: createClient() aus @/lib/supabase/client → supabase.auth.getUser()
UI-Text: Deutsch | Code: Englisch | Styling: nur Tailwind | cn() aus @/lib/utils

## §3 Dateien
app/layout.tsx,page.tsx=Landing | login/,register/=Auth
dashboard/layout.tsx=DashboardShell | page.tsx=Home
admin/page.tsx=Admin(11Tabs:Overview,Users,Posts,Chat,Events,Board,Crisis,Orgs,Farms,Reports,System)
admin/components/AdminTypes.ts,OverviewTab.tsx,UsersTab.tsx,PostsTab.tsx,EventsTab.tsx,BoardTab.tsx,CrisisTab.tsx,OrgsTab.tsx,FarmsTab.tsx,ChatModTab.tsx,SystemTab.tsx,ReportsTab.tsx
posts/page.tsx=Feed | create/page.tsx=Erstellen(3-Step:Art→Inhalt→Kontakt,Bild-Upload,Geo,Tags,Medien)
map/page.tsx=Karte(Leaflet,noSSR,get_nearby_posts RPC+fallback) | chat/page.tsx=Chat(?conv=) | profile/page.tsx=Profil
interactions/page.tsx | notifications/page.tsx | settings/page.tsx(5Tabs)
board/page.tsx=Brett | organizations/page.tsx | events/page.tsx | farm-listings/page.tsx
animals/,crisis/,housing/,mobility/,skills/,knowledge/,sharing/,community/,supply/=ModulePages
groups/page.tsx=Gruppen(Create,Join,Leave,Members,10Kategorien)
marketplace/page.tsx=Marktplatz(Listings,Create,Filter,Preis/Tausch/Gratis,10Kategorien)
challenges/page.tsx=Challenges(Create,Join,Progress,Punkte,Schwierigkeit)
badges/page.tsx=Badges(12Default,Rarität,Punkte,Fortschritt)
wiki/page.tsx=Wissensbasis(knowledge_articles CRUD,Kategorien,Tags,Suche)
shared/ModulePage.tsx(title,desc,icon,color,postTypes,createTypes,categories,emptyText,allowAnonymous,filterCategory,children,moduleFilter[])
shared/PostCard.tsx | shared/ReportButton.tsx | ChatView.tsx | MapView.tsx
components/navigation/navigationConfig.ts(mainNavItems,navGroups,bottomNavItems)
components/navigation/NotificationBell.tsx(Dropdown,Kategorie-Tabs[Alle/Nachrichten/Interaktionen/System],gelesen/ungelesen,Einzel-Loesch,Settings-Link,Realtime)
components/navigation/Sidebar.tsx(SidebarGroup+SidebarItem,collapsed,openGroups,Cmd+K-Suche,Pinned-Pages,Recent-Pages,Tooltips-collapsed,Krisen-Badge-SOS)
components/navigation/BottomNav.tsx(5 Items,keyboard-hide,Badges in Mehr-Sheet fuer Krisen/Matches/Interaktionen,Krisen-Pulse,breiterer Active-Indicator)
dashboard/DashboardShell.tsx(Toast+Push+Sound bei mensaena-notification Events,isSoundEnabled via localStorage)
components/navigation/MobileMenu.tsx(Suchfeld,Avatar+Initials,Quick-Stats-Bar,Collapsible-Gruppen,Quick-Links-Footer)
components/navigation/SidebarItem.tsx(Tooltip-Overlay collapsed,onContextMenu-Pin,Badge-Anzeige)
lib/supabase/client.ts,server.ts,middleware.ts | lib/utils.ts=cn()
lib/chat-utils.ts(openOrCreateDM,getUnreadDMCount)
lib/rate-limit.ts=checkRateLimit(userId,action,maxPerMinute,maxPerHour)->bool(fail-open)
lib/errors.ts=handleSupabaseError(error)->bool
stores/useNotificationStore.ts | useOrganizationStore.ts(v2→v1→direct fallback)
store/useNavigationStore.ts(sidebarCollapsed,mobileMenuOpen,searchOpen)
hooks/useBoard.ts | useDashboard.ts | useEvents.ts | useInteractions.ts | useNotifications.ts | useSettings.ts | useNavigation.ts
types/index.ts

## §4 Datenbank

### Existierend (46 Tabellen + 1 Audit-Tabelle, verifiziert 2026-04-11)
profiles[id=auth.users.id,name,nickname!,email,location,skills[],avatar_url,bio,trust_score,impact_score,trust_level,trust_score_count,role{user|admin|moderator},latitude,longitude,location_text,radius_km,is_banned,banned_until,ban_reason,is_crisis_volunteer,crisis_banned_until,crisis_skills[]]
posts[id,user_id>profiles!,type,category,title,description,image_urls[],latitude,longitude,urgency,contact_phone,contact_whatsapp,contact_email,status,media_urls[],location_text,tags[],availability_start,availability_end,is_anonymous,event_date,event_time,duration_hours,created_at,updated_at]
interactions[id,post_id>posts!,helper_id>profiles!,status,message,UQ(post_id,helper_id),created_at,updated_at]
conversations[id,type{direct|group|system},title,post_id,is_locked,created_at,updated_at]
conversation_members[id,conversation_id>conversations!,user_id>profiles!,last_read_at,UQ,created_at]
messages[id,conversation_id>conversations!,sender_id>profiles!,receiver_id>profiles,content,reply_to_id,deleted_at,created_at,read_at,edited_at]
notifications[id,user_id>profiles!,type,title,body,link,read_at,read,category,actor_id,metadata,scheduled_for,deleted_at,created_at]
trust_ratings[id,rater_id,rated_id,score,comment,interaction_id,categories[],helpful,would_recommend,response,reported,created_at]
regions[id,name!,slug!,lat,lng,radius_km,created_at]
board_posts[id,author_id,content,category,color,image_url,contact_info,expires_at,pinned,pin_count,comment_count,lat,lng,region_id,status,created_at,updated_at]
board_pins[id,user_id,board_post_id,UQ,created_at]
board_comments[id,board_post_id,author_id,content,created_at,updated_at]
events[id,author_id,title,description,category,start_date,end_date,location_name,address,lat,lng,region_id,image_url,max_attendees,cost,status,attendee_count,is_online,online_url,created_at,updated_at]
event_attendees[id,event_id,user_id,status,reminder,UQ,created_at]
organizations[id,name,category,description,address,zip_code,city,state,country,latitude,longitude,phone,email,website,opening_hours,services[],tags[],is_verified,is_active,source_url,fts,created_at,updated_at]
organization_reviews[id,organization_id,user_id,rating,comment,helpful_count,created_at,updated_at] ACHTUNG: organization_id (NICHT org_id!)
crises[id,creator_id,title,description,category,urgency,status,location_text,latitude,longitude,radius_km,affected_count,image_urls[],contact_phone,contact_name,is_anonymous,is_verified,verified_by,verified_at,resolved_at,resolved_by,helper_count,needed_helpers,needed_skills[],needed_resources[],created_at,updated_at]
farm_listings[id,owner_id,name,slug!,description,category,address,lat,lng,phone,email,website,products[],certifications[],delivery_options[],image_urls[],opening_hours,rating_avg,rating_count,status,region_id,created_at,updated_at]
farm_reviews[id,farm_id,user_id,rating,comment,helpful_count,created_at,updated_at]
chat_announcements[id,conversation_id,author_id,content,type,is_active,created_at]
chat_channels[id,name,description,emoji,slug,is_default,is_locked,locked_by,locked_at,locked_reason,sort_order,created_at,conversation_id]
chat_banned_users[id,user_id,banned_by,reason,expires_at] ACHTUNG: KEIN created_at!
message_reactions[id,message_id,user_id,emoji,created_at]
message_pins[id,message_id,conversation_id,pinned_by,pinned_at]
user_status[id,user_id,status,last_seen,created_at]
content_reports[id,reporter_id,content_type,content_id,reason,status,created_at]
saved_posts[id,user_id,post_id,created_at]
post_comments[id,post_id,user_id,parent_id,content,is_edited,created_at,updated_at]
post_votes[id,post_id,user_id,vote,UQ,created_at]
post_shares[id,post_id,user_id,platform,created_at]
push_subscriptions[id,user_id,endpoint!,p256dh,auth,user_agent,created_at,last_used]
groups[id,name,slug!,description,category,is_private,image_url,member_count,post_count,creator_id,created_at,updated_at]
group_members[id,group_id,user_id,role,UQ,joined_at]
group_posts[id,group_id,user_id,content,image_url,created_at]
marketplace_listings[id,title,description,price,price_type,category,condition_state,image_urls[],location_text,lat,lng,seller_id,status,created_at,updated_at]
challenges[id,title,description,category,difficulty,points,max_participants,participant_count,start_date,end_date,status,creator_id,created_at]
challenge_progress[id,challenge_id,user_id,status,progress_pct,completed_at,UQ,joined_at]
badges[id,name,description,icon,category,requirement_type,requirement_value,points,rarity,created_at] +12 Seeds
user_badges[id,user_id,badge_id,UQ,earned_at]
bot_scheduled_messages[id,message_type,title,content,target_audience,scheduled_for,sent_at,status,created_by,created_at] ACHTUNG: KEIN user_id, KEIN sent, KEIN message_content
timebank_entries[id,user_id,partner_id,hours,description,type,created_at]
knowledge_articles[id,author_id,title,content,category,tags[],status,created_at,updated_at]
skill_offers[id,user_id,title,description,category,level,created_at]
volunteer_signups[id,user_id,event_id,crisis_id,status,message,created_at]
matches[id,user_id,matched_user_id,post_id,score,score_breakdown,status,created_at]
interaction_updates[id,interaction_id,actor_id,action,message,created_at]
rate_limits[id,user_id,action,created_at]
user_blocks[id,blocker_id,blocked_id,created_at]
crisis_helpers[id,crisis_id>crises!,user_id>auth.users!,status{offered|accepted|on_way|arrived|completed|withdrawn},message,skills[],eta_minutes,latitude,longitude,UQ(crisis_id,user_id),created_at,updated_at]
crisis_updates[id,crisis_id>crises!,author_id>auth.users!,content,update_type{info|status_change|resource_update|helper_update|resolution|warning|official},image_url,is_pinned,created_at]
emergency_numbers[id,country{DE|AT|CH},category,label,number,description,is_24h,is_free,sort_order] +24 Seeds
match_preferences[id,user_id!>auth.users!,matching_enabled,max_distance_km,preferred_categories[],excluded_categories[],min_trust_score,max_matches_per_day,notify_on_match,auto_accept_threshold,created_at,updated_at]
organization_review_helpful[id,review_id>organization_reviews!,user_id>auth.users!,UQ(review_id,user_id),created_at]
organization_suggestions[id,user_id>auth.users!,name,description,category,address,city,country,phone,email,website,status{pending|approved|rejected},admin_notes,created_at]
post_reactions[id,post_id>posts!,user_id>auth.users!,reaction_type{heart|thanks|support|compassion},UQ(post_id,user_id),created_at]
reports[id,reporter_id>auth.users!,content_type{post|user|comment|board_post|event|organization|message},content_id,reason,comment,status{pending|reviewing|resolved|dismissed},resolved_by,resolved_at,created_at]
audit_logs[id,actor_id>auth.users!,action,target_type,target_id,details JSONB,ip_address,created_at]
Views: v_post_comment_counts, v_post_vote_scores, v_post_share_counts, v_active_posts, v_unread_counts, v_active_crises

### WICHTIG: Spalten-Mismatch
- posts: latitude/longitude (NICHT lat/lng!)
- board_posts, events, farm_listings, regions: lat/lng
- organizations: latitude/longitude (NICHT lat/lng!)
- crises: latitude/longitude (NICHT lat/lng!)
- profiles: latitude/longitude

### Storage
avatars post-images event-images board-images chat-images crisis-images group-images marketplace-images organization-images – alle public (ausser chat-images)
RLS: 31 Policies aktiv (SELECT/INSERT/DELETE pro Bucket) – 9 Buckets

### Hilfsfunktion
exec_sql(sql_text TEXT)->VOID SECURITY DEFINER – führt beliebiges SQL aus (nur service_role)

## §5 RPCs
ADMIN: get_admin_dashboard_stats()->JSON26+ | admin_get_users(search,role,limit,offset) | admin_change_user_role(uid,role) | admin_delete_[user|post|organization|event|crisis|board_post|farm](id) | admin_hard_delete_message(id) | run_scheduled_cleanup()->JSON
SUCHE: search_posts(q,type,cat,lat,lng,radius,limit,offset)->+distance_km | search_board_posts(q,cat,limit,offset) | search_organizations_v2(q,cat,verified,lat,lng,radius)
COMMUNITY: get_nearby_posts(lat,lng,radius=10,limit=10)->JSON | get_community_pulse()->JSON | check_rate_limit(uid,action,max_per_minute,max_per_hour)->BOOL
CRISIS: get_crisis_stats()->TABLE | mobilize_nearby_helpers(crisis_id,radius_km)
ORG: increment_helpful(review_id) | decrement_helpful(review_id)
TRUST: calculate_trust_score(uid) | get_trust_breakdown(uid)
VIEWS: v_active_posts | v_unread_counts | v_active_crises

## §6 Typen
PostType:help_needed|help_offered|rescue|animal|housing|supply|mobility|sharing|crisis|community
PostCat:food|everyday|moving|animals|housing|knowledge|skills|mental|mobility|sharing|emergency|general
Status:active|fulfilled|archived|pending
NotifCat:message|interaction|trust_rating|post_nearby|post_response|system|bot|mention|welcome|reminder|comment
BoardCat:general|gesucht|biete|event|info|warnung|verloren|fundbuero

## §6b Dokumentation (docs/)
- docs/A3_1_CHAT_TABLES.md – Chat-Tabellen Schema-Fixes (chat_banned_users, message_pins, chat_channels)
- docs/A7_MODULE_BUGS.md – Modul-Bugs (bot_scheduled_messages, Tiere, Wohnen)
- docs/A11_PERFORMANCE.md – Performance (Dashboard-Queries, Google Fonts, Bot-Query)
- docs/B2_4_MISSING_COLUMNS.md – Spalten-Mismatch (OrgsTab, AdminTypes, OrgStore, CrisisTab)
- supabase/B5_INFRA_ANLEITUNG.md – Infra-Setup (DNS, Auth, Templates, Storage, pg_cron)

## §7 Log
| Datum | Was | Dateien |
|---|---|---|
| 2026-04-30 | feat(calls): #43 — Android Foreground Service: @capawesome-team/capacitor-android-foreground-service, useCallForegroundService Hook, AndroidManifest Permissions+Service+Receiver, ic_stat_call Drawable, LiveRoomModal+GlobalCallListener Integration | src/hooks/useCallForegroundService.ts, android/app/src/main/AndroidManifest.xml, android/app/src/main/res/drawable/ic_stat_call.xml, LiveRoomModal.tsx, GlobalCallListener.tsx |
| 2026-04-30 | fix(calls): #41 — Countdown statt Hochzählen: "Klingelt noch Xs" mit Rot-Warnung unter 10s in Incoming+OutgoingCallScreen | src/components/chat/IncomingCallScreen.tsx, OutgoingCallScreen.tsx |
| 2026-04-30 | fix(calls): #33 — Einheitliche System-Call-Nachrichten: end ohne Dauer wenn kein answered_at, cancel-active→'abgebrochen' statt 'beendet', alle Routes kommentiert | src/app/api/dm-calls/{end,cancel,decline,missed}/route.ts |
| 2026-04-30 | fix(calls): #21 — Bestätigungsdialog vor Anruf: confirmCall-State, createPortal-Dialog mit Backdrop-Click, Buttons öffnen Dialog statt direkt starten | src/components/chat/ChatView.tsx |
| 2026-04-30 | fix(calls): #19+#22 — DM-Header Anruf-Buttons: rounded-full, bg-primary-50, min-44px touch-target, w-5 h-5 Icons; separater Video-Button | src/components/chat/ChatView.tsx |
| 2026-04-30 | fix(calls): #14 — PhoneOff rotate-[135deg] aus Ablehnen-Button entfernt | src/components/chat/IncomingCallScreen.tsx |
| 2026-04-30 | fix(calls): #10 — CallTimer startet ab answeredAt: LiveRoomModalProps+ActiveCallState+activeDMCallSession um answeredAt erweitert, CallTimer berechnet Sekunden aus Date.now()-answeredAt | src/components/chat/LiveRoomModal.tsx, ChatView.tsx, GlobalCallListener.tsx |
| 2026-04-30 | fix(calls): #9+#34 — [SYSTEM_CALL]-Nachrichten als zentrierte Karte (Icon+Label+Zurückrufen-Button bei verpasst+eingehend), parseSystemCallMessage-Helper | src/components/chat/ChatView.tsx |
| 2026-04-30 | fix(calls): #8 — visibilitychange-Handler in IncomingCallScreen + OutgoingCallScreen: bei Tab-Rückkehr DB-Abfrage, Screen schließen wenn ended/declined/missed/cancelled | src/components/chat/IncomingCallScreen.tsx, src/components/chat/OutgoingCallScreen.tsx |
| 2026-04-30 | fix(calls): #6 — Loader2-Spinner + Text nach Tippen auf „Annehmen", Buttons ausgeblendet während Token-Fetch | src/components/chat/IncomingCallScreen.tsx |
| 2026-04-30 | fix(calls): #39 — skipWaiting wartet auf SKIP_WAITING Client-Message statt sofort beim install | public/sw.js |
| 2026-04-30 | fix(calls): #38 — Push-Notification Auto-Close: incoming=null→getNotifications(tag=incoming-call).close(), sw.js schließt Call-Notification bei nicht-call Events | src/components/chat/GlobalCallListener.tsx, public/sw.js |
| 2026-04-30 | fix(calls): #30 — Push-Accept/Decline URL-Parameter: useEffect([])) in ChatView verarbeitet action=accept/decline+callId, URL sofort bereinigt | src/components/chat/ChatView.tsx |
| 2026-04-30 | fix(calls): #18 — Klingelton-Fallback bei gesperrtem Audio: Vibration+Retry in startRingtone/startDialTone, AudioContext-Priming in GlobalCallListener | src/lib/audio/ringtone.ts, src/lib/audio/dial-tone.ts, src/components/chat/GlobalCallListener.tsx |
| 2026-04-30 | fix(calls): #32 — Decline auf Callee beschränkt: or()-Query→eq(callee_id), in('status',['ringing']) Guard | src/app/api/dm-calls/decline/route.ts |
| 2026-04-30 | fix(calls): #31 — Cancel bei gleichzeitiger Annahme: active-Call-Fallback + Duplikat-Check Systemnachricht, alreadyEnded-Kurzschluss | src/app/api/dm-calls/cancel/route.ts |
| 2026-04-30 | fix(calls): #28 — Gebannte User können keine Anrufe mehr starten: isBanned in Phone+Video-Buttons, server-seitiger Ban-Check in /api/dm-calls/start | src/components/chat/ChatView.tsx, src/app/api/dm-calls/start/route.ts |
| 2026-04-30 | fix(calls): #16 — Stale-Cleanup killt keine aktiven Calls mehr: STALE_CUTOFF 120_000, nur 'ringing' aufräumen, separater ACTIVE_CUTOFF 4h für Zombie-Calls, if (!initialCallId) Guard verhindert Push-Accept 404, load-Query nutzt ACTIVE_CUTOFF statt STALE_CUTOFF | src/components/chat/ChatView.tsx |
| 2026-04-30 | fix(livestream): Auth-Header-Fixes + LiveKit-Credentials als Cloudflare Secrets (LIVEKIT_SELF_URL/KEY/SECRET): Authorization Bearer in OutgoingCallScreen+IncomingCallScreen+ChatView+chat/page.tsx; wrangler.toml [vars] temporär, dann Secrets gesetzt | src/components/chat/OutgoingCallScreen.tsx, IncomingCallScreen.tsx, ChatView.tsx, dashboard/chat/page.tsx |
| 2026-04-30 | feat(livestream): A1 — Admin/Mod-Rolle als LiveKit-Token-Metadata: profiles.role → metadata=JSON.stringify({role}) in AccessToken für Community (live-room/token) + DM-Calls (dm-calls/answer + lib/livekit/token.ts) | src/app/api/live-room/token/route.ts, src/lib/livekit/token.ts, src/app/api/dm-calls/answer/route.ts |
| 2026-04-30 | feat(livestream): A2 — Admin/Mod-Badge im Livestream: getParticipantRole() parst participant.metadata; ParticipantTile zeigt 🛡️ Admin (bg-red-500) / ⚔️ Mod (bg-amber-500) als Overlay-Badge oben-links + farbiges Namens-Label | src/components/chat/LiveRoomModal.tsx |
| 2026-04-30 | feat(livestream): A3 — Admin/Mod-Sortierung in Teilnehmerliste: rolePriority() admin=0/mod=1/user=2 vor Hand/Speaking-Sortierung; farbige Rollen-Badges (bg-red-500/20, bg-amber-500/20) in Teilnehmer-Listeneintrag | src/components/chat/LiveRoomModal.tsx |
| 2026-04-30 | feat(calls): #11 — Audio-Output-Wechsel: speakerActive State; ControlButton enumerateDevices→filterAudioOutput→switchActiveDevice; Lautsprecher/Ohrhörer-Toggle in Steuerleiste von InnerRoom | src/components/chat/LiveRoomModal.tsx |
| 2026-04-12 | feat(auth): Passwort-vergessen-Flow – AuthMode erweitert um `forgot`+`reset`, resetPasswordForEmail mit redirectTo `/auth?mode=reset`, PASSWORD_RECOVERY Listener setzt recoverySession (kein Dashboard-Redirect in reset-Mode), updateUser({password}) nach Stärke-Check+Bestätigung, "Passwort vergessen?" Link unter Login-Passwortfeld, E-Mail-Enumeration-Schutz (immer generische Erfolgsmeldung), signOut nach erfolgreichem Reset, Redirects /passwort-vergessen + /forgot-password + /passwort-zuruecksetzen + /reset-password in next.config.js | src/app/auth/page.tsx,next.config.js |
| 2026-04-12 | fix: @fontsource/inter ersetzt next/font/google (Build offline-kompatibel), --font-inter CSS-Var in :root, layout.tsx bereinigt | layout.tsx,globals.css,package.json |
| 2026-04-12 | fix: Modul-Logik verbessert – 18 Umlaute in 10 Dateien (Unterstützung,Gefährdung,Lösung,benötigt,wähle,rückgängig,Schließen,verfügbar,möglich), help_offer→help_offered in Zeitbank+Kalender+Community+Create, Rate-Limiting in Marketplace/Gruppen/Challenges/Wiki, Escape-Close alle Modals, Beschreibungs-Validierung, Duplikat-Schutz Gruppen+Challenges, setSaving-Fix | PostDetailPage,DashboardShell,MatchSuggestionDetail,DeleteAccountModal,EmergencyContacts,NotificationSettings,RatingModal,ProfileView,Modal,marketplace,groups,challenges,wiki,timebank,calendar,community,create,errors,ModulePage,PostCard |
| 2026-04-12 | fix: Modul-Bugs – PostCard+PostDetailPage Urgency text→number URGENCY_MAP (low/medium/high/critical→0/1/2/3), ModulePage CreatePostModal Handels-Checkbox, post-types.ts help_offer→help_offered+Mobilität, 13 Umlaute in 9 Dateien (AGB,Settings,Ratings,Matching,Orgs,PostCard,PostDetail) | ModulePage.tsx,PostCard.tsx,PostDetailPage.tsx,post-types.ts,agb/page.tsx,NotificationSettings.tsx,DeleteAccountModal.tsx,AccountSettings.tsx,settings/page.tsx,RatingModal.tsx,PreferencesModal.tsx,SuggestionForm.tsx |
| 2026-04-12 | fix(sos): SOSModal via createPortal in document.body (z-index fix), Handels-Checkbox in CrisisCreateForm+EventCreateForm+BoardCreateForm+CreatePostForm, acceptedNoTrade Server-Validierung | SOSModal.tsx,GlobalSOSButton.tsx,CrisisCreateForm.tsx,EventCreateForm.tsx,BoardCreateForm.tsx,create/page.tsx,TODO.md |
| 2026-04-12 | feat: Handels-Checkbox Posts, SOS-Header-Button, Bot-Repos, Logo, Telefonnummern entfernt, AGB §4+§7 | create/page.tsx,GlobalSOSButton.tsx,SOSButton.tsx,haftungsausschluss.tsx,kontakt.tsx,LandingNavbar.tsx,LandingFooter.tsx,nutzungsbedingungen.tsx,MensaenaBot.tsx,AppShell.tsx,Topbar.tsx,tailwind.config.ts |
| 2026-04-13 | design: Umfassende Design-Verbesserungen – emerald→primary (90+ Dateien), Landing Hero Glow+Sterne, Dashboard Datum+Gradient+QuickActions, Sidebar Indikator animiert, Chat Pill-Input, Event Datumkästchen, Krisen Urgency-Borders+left-4, GroupCard Privat-Badge, SOS sosRing Keyframe, Zeitbank Pending-Banner, Auth Rate-Limit+Passwort-Stärke, tabIndex Barrierefreiheit, tailwind glowPulse+sidebarGlow auf teal, CLAUDE.md erstellt | src/styles/globals.css,tailwind.config.ts,90+ src/** |
| 2026-04-13 | fix: PostDetailPage lat/lng→latitude/longitude in .select()+Interface, post-types.ts PostCardPost lat/lng→latitude/longitude, DashboardShell vibrate as NotificationOptions (TS-Fix), CrisisTab .catch()→try/catch, doppelte Claude.md entfernt | src/app/dashboard/posts/[id]/PostDetailPage.tsx,src/lib/post-types.ts,src/app/dashboard/DashboardShell.tsx,src/app/dashboard/admin/components/CrisisTab.tsx |
| 2026-04-12 | fix(umlaut): 185 literal \\uXXXX Unicode-Escape-Sequenzen in 35 Dateien durch echte UTF-8 ersetzt (Dashboard, Krisen, Settings, Mobile, PostCard, ProfileView, Landing, trust-score, utils) | 35 Dateien |
| 2026-04-12 | docs: 4 Doku-MDs (A3.1,A7,A11,B2.4) in docs/, AI_CONTEXT Schema-Korrektur (chat_banned_users, message_pins, chat_channels, organization_reviews), TODO.md Doku-Referenzen, Fix org_id->organization_id in OrgStore (3 Stellen) | docs/*.md,AI_CONTEXT.md,TODO.md,useOrganizationStore.ts |
| 2026-04-12 | A3.1+A7+A11+B2.4 Fix: ChatView (chat_banned_users safe select, message_pins ohne conversation_id/created_at), useDashboard (bot_scheduled_messages content statt message_content, status statt sent), OrgsTab+AdminTypes (is_verified statt verified, kein slug/rating_avg, is_active statt Bewertung), OrgStore (Fallback category/description/city/is_verified, ID statt slug Lookup) | ChatView.tsx,useDashboard.ts,OrgsTab.tsx,AdminTypes.ts,useOrganizationStore.ts |
| 2026-04-11 | Nav-Redesign v2 Clean Rewrite: navConfig exakt 6 Gruppen+Admin (Übersicht entfernt), Sidebar.tsx interner NavGroup (Expanded: collapsible header+chevron+auto-open; Collapsed: icon+flyout-menü), BottomNav.tsx Custom-Sheet ohne MobileSheet (Overlay+blur, slide-up 300ms, drag-handle, 70vh, collapsible SheetGroups, Notification-Badge, auto-close bei Route), SidebarGroup.tsx jetzt unused | navigationConfig.ts,Sidebar.tsx,BottomNav.tsx |
| 2026-04-11 | Navigationsleiste-Overhaul v1: Sidebar (Cmd+K Suche, Pinned/Recent Pages, Tooltips collapsed, Total-Badge, SOS-Badge), Topbar (Chat-Badge, Map-Shortcut, Mini-Breadcrumb), BottomNav (Krisen/Matches/Interaktions-Badges in Mehr-Sheet, active-Indicator), MobileMenu (Suchfeld, Avatar, Quick-Stats, Collapsible-Gruppen), AppShell Mobile-Header (Hamburger links, Avatar rechts), SidebarItem Tooltip+ContextMenu, useNavigation 6 neue Seitentitel | Sidebar.tsx,SidebarItem.tsx,Topbar.tsx,BottomNav.tsx,MobileMenu.tsx,AppShell.tsx,useNavigation.ts |
| 2026-04-11 | Echtzeit-Notification-Center: NotificationBell Dropdown mit Kategorie-Tabs, gelesen/ungelesen, Einzel-Loesch, Settings-Link; DashboardShell Push+Sound+Toast; Sound-Sync localStorage; AppShell Realtime Channels (INSERT+UPDATE notifications, INSERT messages, * crises, * interactions); Kontaktadressen alle Legal-Pages; ring+fadeOut CSS | NotificationBell.tsx,DashboardShell.tsx,NotificationSettings.tsx,AppShell.tsx,globals.css,agb/page.tsx,datenschutz/page.tsx,nutzungsbedingungen/page.tsx,haftungsausschluss/page.tsx,community-guidelines/page.tsx |
| 2026-04-11 | Batch4: next/font Performance, parallelisierte AppShell-Queries, animals location_text, CrisisTab Spalten-Fix, organization-images Bucket, cleanup-RPC-Name | layout.tsx,globals.css,AppShell.tsx,animals/page.tsx,CrisisTab.tsx,004_storage_policies.sql,20260411_missing_tables.sql |
| 2026-04-11 | Batch3: 8+1 fehlende Tabellen (034_missing_tables.sql), 30+ Umlaute R3, BottomNav+AppShell, 7 RPCs, User-Ban, Audit-Logs | 20260411_missing_tables.sql,034_missing_tables.sql,AppShell.tsx,UsersTab.tsx,SystemTab.tsx,AdminTypes.ts,19 Umlaut-Dateien |
| 2026-04-11 | A4 BottomNav Mehr-Sheet: 5.Item durch Mehr-Button ersetzt, MobileSheet mit allen navGroups | BottomNav.tsx |
| 2026-04-11 | A5 Rest-Umlaute: 21+ weitere Stellen in 18 Dateien (admin,settings,groups,kontakt,landing,legal,errors,privacy,trust,profile,PostCard) | 18 Dateien |
| 2026-04-11 | B2 Kaskaden-Delete: PostsTab+EventsTab löschen abhängige Daten vor Haupteintrag | PostsTab.tsx,EventsTab.tsx |
| 2026-04-11 | C2 Reports: ReportsTab.tsx (Suche,Filter,Detail,Status,Löschen), ReportButton.tsx in PostCard | ReportsTab.tsx,ReportButton.tsx,PostCard.tsx,admin/page.tsx |
| 2026-04-11 | D1 Security: Server-Side Admin-Guard middleware, User-Enumeration-Fix, CSV-Leak-Fix, Rate-Limit-Doku | middleware.ts,auth/page.tsx,supply/page.tsx,rate-limit.ts |
| 2026-04-11 | A1 CreatePostModal: +latitude/longitude+location_text+Bild-Upload+Rate-Limiting in ModulePage | ModulePage.tsx |
| 2026-04-11 | A5 Umlaut-Fix: ~60 Stellen in 39 Dateien (admin,create,orgs,interactions,matching,settings,legal) | 39 Dateien |
| 2026-04-11 | B1 Admin Edit-Modals: alle 8 Tabs haben Bearbeitungs-Modals (Posts,Events,Board,Crisis,Orgs,Farms,Chat,Users) | admin/components/*.tsx |
| 2026-04-11 | C1 Moderator: Tabs eingeschränkt (kein Users/System), Guard prüft admin+moderator | admin/page.tsx |
| 2026-04-11 | D1 Security: Middleware Auth für /dashboard/*, Client-Key Security-Kommentar | middleware.ts,client.ts |
| 2026-04-11 | Audit 161 Punkte integriert, TODO.md+AI_CONTEXT.md+README.md aktualisiert | TODO.md,AI_CONTEXT.md,README.md |
| 2026-04-11 | DM+RateLimit+Build-Fix: pendingConv, post_id FK retry, Rate-Limit Signatur, Fax→Printer | chat-utils.ts,ChatView.tsx,rate-limit.ts,useBoard.ts,create/page.tsx,useEvents.ts |
| 2026-04-10 | B5 Infra komplett (Auth URLs, Templates, pg_cron, pg_net, Storage RLS) | auth/page.tsx,templates/*,004_storage_policies.sql |
| 2026-04-10 | B7 DB-Fix Mig033 (group RLS recursion, badges, exec_sql) | 033_fix_group_rls_badges.sql |
| 2026-04-09 | B1-B8 alle komplett | div. Dateien |
