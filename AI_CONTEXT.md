# MENSAENA – AI Context
> Aktualisiert: 2026-04-10 | v1.0.0-beta+b1b2b3b4b6b7b8

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
Live: mensaena.pages.dev | Domain: mensaena.de (DNS pending)
SB-ID: huaqldjkgyosefzfhjnf
SB-SQL: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
Owner: Manuel Brandner

## §2 Stack
Next.js 15.3.0 AppRouter 'use client' | React 19 | Tailwind 3.4 | Lucide | react-hot-toast | Zustand 4.5 | Supabase JS 2.43 + SSR 0.3 | Cloudflare Pages @opennextjs/cloudflare 1.6 | Leaflet 1.9.4+MarkerCluster | date-fns 3.6
Deploy: npx opennextjs-cloudflare build && npx wrangler deploy
Auth: createClient() aus @/lib/supabase/client → supabase.auth.getUser()
UI-Text: Deutsch | Code: Englisch | Styling: nur Tailwind | cn() aus @/lib/utils

## §3 Dateien
app/layout.tsx,page.tsx=Landing | login/,register/=Auth
dashboard/layout.tsx=DashboardShell | page.tsx=Home
admin/page.tsx=Admin(10Tabs:Overview,Users,Posts,Chat,Events,Board,Crisis,Orgs,Farms,System)
admin/components/AdminTypes.ts,OverviewTab.tsx,UsersTab.tsx,PostsTab.tsx,EventsTab.tsx,BoardTab.tsx,CrisisTab.tsx,OrgsTab.tsx,FarmsTab.tsx,ChatModTab.tsx,SystemTab.tsx
posts/page.tsx=Feed | create/page.tsx=Erstellen
map/page.tsx=Karte(Leaflet,noSSR) | chat/page.tsx=Chat(?conv=) | profile/page.tsx=Profil
interactions/page.tsx | notifications/page.tsx | settings/page.tsx(5Tabs)
board/page.tsx=Brett | organizations/page.tsx | events/page.tsx | farm-listings/page.tsx
animals/,crisis/,housing/,mobility/,skills/,knowledge/,sharing/,community/,supply/=ModulePages
groups/page.tsx=Gruppen(Create,Join,Leave,Members,10Kategorien)
marketplace/page.tsx=Marktplatz(Listings,Create,Filter,Preis/Tausch/Gratis,10Kategorien)
challenges/page.tsx=Challenges(Create,Join,Progress,Punkte,Schwierigkeit)
badges/page.tsx=Badges(12Default,Raritaet,Punkte,Fortschritt)
wiki/page.tsx=Wissensbasis(knowledge_articles CRUD,Kategorien,Tags,Suche)
shared/ModulePage.tsx(title,desc,icon,color,postTypes,createTypes,categories,emptyText,allowAnonymous,filterCategory,children)
shared/PostCard.tsx | ChatView.tsx | MapView.tsx
lib/supabase/client.ts,server.ts,middleware.ts | lib/utils.ts=cn()
stores/useNotificationStore.ts | useOrganizationStore.ts(v2→v1→direct fallback)
hooks/useBoard.ts(search_board_posts RPC) | useDashboard.ts(v_unread_counts+v_active_posts) | useEvents.ts | useInteractions.ts | useNotifications.ts | useSettings.ts
types/index.ts
lib/rate-limit.ts=checkRateLimit(userId,action,max,window)->bool(fail-open)

## §4 Datenbank

### Existierend
profiles[id=auth.users.id,name,nickname!,email,location,skills[],avatar_url,bio,trust_score,impact_score,ts.+trust_level,+trust_score_count,+role{user|admin|moderator},+lat,+lng,+location_text]
posts[id,user_id>profiles!,type{help_needed|help_offered|rescue|animal|housing|supply|mobility|sharing|crisis|community},cat{food|everyday|moving|animals|housing|knowledge|skills|mental|mobility|sharing|emergency|general},title(5-120),desc(min20),image_urls[],lat,lng,urgency{low|medium|high|critical},contact_phone/whatsapp/email,status{active|fulfilled|archived|pending},ts.+media_urls[],+location_text,+tags[],+availability_start/end,+anonymous]
interactions[id,post_id>posts!,helper_id>profiles!,status{pending|accepted|completed|cancelled},message,UQ(post_id,helper_id),ts]
conversations[id,type{direct|group|system},title,created_at]
conversation_members[id,conv_id>conversations!,user_id>profiles!,UQ,created_at]
messages[id,conv_id>conversations!,sender_id>profiles!,receiver_id>profiles,content(min1),created_at,read_at.+deleted_at]
notifications[id,user_id>profiles!,type,title,body,link,read_at,created_at.+read,+category{message|interaction|trust_rating|post_nearby|post_response|system|bot|mention|welcome|reminder},+actor_id>profiles,+metadata{},+scheduled_for,+deleted_at]
trust_ratings[id,rater_id>profiles!,rated_id>profiles!,score(1-5),comment,UQ(rater_id,rated_id),created_at.+interaction_id,+categories[],+helpful,+would_recommend,+response,+reported]
regions[id,name!,slug!,lat,lng,radius_km,created_at]
board_posts[id,author_id>profiles,content,cat{general|gesucht|biete|event|info|warnung|verloren|fundbuero},color{yellow|green|blue|pink|orange|purple},image_url,contact_info,expires_at,pinned,pin_count,comment_count,lat,lng,region_id>regions,status{active|expired|hidden|deleted},ts]
board_pins[id,user_id>profiles,board_post_id>board_posts,UQ,created_at]
board_comments[id,board_post_id>board_posts,author_id>profiles,content,ts]
events[id,author_id>profiles!,title,desc,category,start_date,end_date,location_name,address,lat,lng,region_id>regions,image_url,max_attendees,cost,status,attendee_count=0,ts.+is_online,+online_url]
event_attendees[id,event_id>events!,user_id>profiles!,status,reminder,UQ(event_id,user_id),created_at]
organizations[id,name,slug!,cat,desc,address,phone,email,website,lat,lng,services[],tags[],verified,image_url,rating_avg,rating_count,region_id>regions,ts]
organization_reviews[id,org_id>organizations,user_id>profiles,rating,comment,helpful_count,ts]
crises[id,title,desc,type,severity,lat,lng,status,reporter_id>profiles,region_id>regions,ts]
farm_listings[id,owner_id>profiles!,name,slug!,desc,cat,address,lat,lng,phone,email,website,products[],certifications[],delivery_options[],image_urls[],opening_hours{},rating_avg,rating_count,status,region_id>regions,ts]
farm_reviews[id,farm_id>farm_listings!,user_id>profiles!,rating,comment,helpful_count,ts]
chat_announcements[id,conv_id,author_id,content,type,created_at]
timebank_entries[id,user_id>profiles,partner_id>profiles,hours,desc,type,created_at]
knowledge_articles[id,author_id>profiles,title,content,cat,tags[],status,ts]
skill_offers[id,user_id>profiles,title,desc,cat,level,created_at]
volunteer_signups[id,user_id>profiles,event_id,crisis_id,status,message,created_at]
matches[id,user_id>profiles,matched_user_id>profiles,post_id>posts,score,score_breakdown{},status,created_at]
interaction_updates[id,interaction_id>interactions,actor_id>profiles,action,message,created_at]

### Mig031 (ausgefuehrt)
post_comments[id,post_id>posts!,user_id>profiles!,parent_id>self,content(1-2000),is_edited,ts]
post_votes[id,post_id>posts!,user_id>profiles!,vote{-1|1},UQ(post_id,user_id),created_at]
post_shares[id,post_id>posts!,user_id>profiles,platform{link|whatsapp|email|native|copy},created_at]
push_subscriptions[id,user_id>profiles!,endpoint!,p256dh,auth,user_agent,created_at,last_used]
Views: v_post_comment_counts, v_post_vote_scores, v_post_share_counts

### Mig032 (ausgefuehrt) + Mig033 Fix (ausgefuehrt)
groups[id,name,slug!,description,category,is_private,image_url,member_count,post_count,creator_id>profiles!,ts]
group_members[id,group_id>groups!,user_id>profiles!,role{admin|moderator|member},UQ(group_id,user_id),joined_at]
group_posts[id,group_id>groups!,user_id>profiles!,content,image_url,created_at]
marketplace_listings[id,title,description,price,price_type{fixed|negotiable|free|swap},category,condition_state,image_urls[],location_text,lat,lng,seller_id>profiles!,status,ts]
challenges[id,title,description,category,difficulty{leicht|mittel|schwer},points,max_participants,participant_count,start_date,end_date,status,creator_id>profiles!,created_at]
challenge_progress[id,challenge_id>challenges!,user_id>profiles!,status,progress_pct,completed_at,UQ(challenge_id,user_id),joined_at]
badges[id,name,description,icon,category,requirement_type,requirement_value,points,rarity{common|uncommon|rare|epic|legendary},created_at] +12 Seeds
user_badges[id,user_id>profiles!,badge_id>badges!,UQ(user_id,badge_id),earned_at]
bot_scheduled_messages[id,message_type,title,content,target_audience,scheduled_for,sent_at,status,created_by>profiles,created_at]

### Gedroppt (2026-04-09)
crisis_reports (Duplikat crises), post_tags (Duplikat posts.tags[])

### Hilfsfunktion
exec_sql(sql_text TEXT)->VOID  SECURITY DEFINER – fuehrt beliebiges SQL aus (nur service_role)

### Fehlend (SQL manuell)
(keine – alle Tabellen in Mig031+032+033 abgedeckt, alle verifiziert 13/13 OK)

### Storage
avatars(5MB) post-images(10MB) event-images(5MB) board-images(5MB) farm-images(5MB) org-images(5MB) – alle public
RLS: supabase/004_storage_policies.sql NOCH AUSFÜHREN

## §5 RPCs
ADMIN: get_admin_dashboard_stats()->JSON26+ | admin_get_users(search,role,limit,offset) | admin_change_user_role(uid,role) | admin_delete_[user|post|organization|event|crisis|board_post|farm](id) | admin_hard_delete_message(id) | run_scheduled_cleanup()->JSON
SUCHE: search_posts(q,type,cat,lat,lng,radius,limit,offset)->+distance_km | search_board_posts(q,cat,limit,offset) | search_organizations_v2(q,cat,verified,lat,lng,radius)
COMMUNITY: get_nearby_posts(lat,lng,radius=10,limit=10)->JSON | get_community_pulse()->JSON | check_rate_limit(uid,action,max,window)->BOOL
TRUST: calculate_trust_score(uid) | get_trust_breakdown(uid)
VIEWS: v_active_posts | v_unread_counts | v_active_crises

## §6 Typen
PostType:help_needed|help_offered|rescue|animal|housing|supply|mobility|sharing|crisis|community
PostCat:food|everyday|moving|animals|housing|knowledge|skills|mental|mobility|sharing|emergency|general
Status:active|fulfilled|archived|pending
NotifCat:message|interaction|trust_rating|post_nearby|post_response|system|bot|mention|welcome|reminder|comment
BoardCat:general|gesucht|biete|event|info|warnung|verloren|fundbuero

## §7 Log
| Datum | Was | Dateien |
|---|---|---|
| 2026-04-09 | Steering-Files erstellt | AI_CONTEXT.md,TODO.md,AI_PROMPTS.md |
| 2026-04-09 | B1 Sicherheit: hardcoded admin emails entfernt, rate-limit integriert, admin hard-delete, cleanup-btn | admin/page.tsx,ChatView.tsx,create/page.tsx,useBoard.ts,useEvents.ts,lib/rate-limit.ts |
| 2026-04-09 | B8 DB-Clean: crisis_reports+post_tags=DROP empfohlen, distance_km=nur RPCs OK, orgs=Frontend noch nicht angebunden | - |
| 2026-04-09 | B2 Admin-Dashboard komplett: 10 Tabs (Overview+RPC Stats, Users CRUD+role, Posts+Events+Board+Crisis+Orgs+Farms mit Suche/Pagination/Delete, Chat-Mod, System Cleanup+Links) | admin/page.tsx, admin/components/*.tsx |
| 2026-04-09 | B3 Performance: search_posts RPC in posts/page, search_board_posts in useBoard, search_organizations_v2 chain in orgStore, v_unread_counts+v_active_posts in dashboard, get_nearby_posts in map/page, hasMore Bug fix | posts/page.tsx,useBoard.ts,useOrganizationStore.ts,useDashboard.ts,map/page.tsx |
| 2026-04-09 | B4 Features: Create form erw. um location_text+lat/lng+Bild-Upload+media_urls+availability_start/end; Events erw. um is_online+online_url; Profil erw. um Trust-Tier Badge+Impact-Held; Bestehende UIs verifiziert (InteractionTimeline,MatchScore,Timebank,Skills,Knowledge) | create/page.tsx,EventCreateForm.tsx,useEvents.ts,ProfileView.tsx |
| 2026-04-09 | Intelligente Modul-Zuordnung: ModulePage erhaelt moduleFilter (ModuleFilterRule[]) – Posts werden nur in Modulen angezeigt wo sie thematisch hingehoeren. type+category Kombination bestimmt Zuordnung. Widget-Queries in allen Modulen angepasst (housing,rescuer,animals,mobility,sharing,community,mental-support,timebank,skills,knowledge,harvest) | ModulePage.tsx,housing/page.tsx,rescuer/page.tsx,animals/page.tsx,mobility/page.tsx,sharing/page.tsx,community/page.tsx,mental-support/page.tsx,timebank/page.tsx,skills/page.tsx,knowledge/page.tsx,harvest/page.tsx |
| 2026-04-09 | B6 Polish komplett: (1) post_comments Tabelle+RLS+Trigger+UI in PostDetailPage mit Reply-Tree, Edit, Delete, Author-Badge. (2) post_votes Tabelle+RLS+Unique+Vote-UI in PostCard (ThumbsUp/Down+Score) und PostDetailPage. (3) Notifications: comment Kategorie hinzugefuegt (Typ,Icon,Farbe,Label,Filter-Tab), Bot-Filter existierte bereits. (4) post_shares Tabelle+Share-Tracking in ShareMenu (copy/whatsapp/email/native)+Zaehler. (5) PWA: Icons generiert (72-512px+maskable+apple-touch), SW+manifest+offline existierten. (6) push_subscriptions Tabelle+RLS, SW Push Handler existierte. SQL: 031_post_comments.sql (post_comments,post_votes,post_shares,push_subscriptions,Views) | PostDetailPage.tsx,PostCard.tsx,useNotificationStore.ts,NotificationFilters.tsx,NotificationItem.tsx,notifications.ts,types/index.ts,031_post_comments.sql,public/icons/* |
| 2026-04-10 | B7 DB-Fix: Mig033 – group_members/group_posts RLS infinite recursion gefixt (DISABLE→DROP ALL→ENABLE→simple policies), fehlende Tabellen user_badges+bot_scheduled_messages erstellt, badges SELECT-Policy repariert, 12 Badge-Seeds eingefuegt+Duplikate bereinigt, exec_sql() Hilfsfunktion erstellt. Verifizierung: 9/9 Tabellen OK, 3/3 Views OK, 12/12 Badges OK = 13/13 | 033_fix_group_rls_badges.sql,fix_all_b7.sql |
| 2026-04-09 | B7 Neue Module: (1) Groups – Gruppen erstellen/beitreten/verlassen (10 Kategorien, privat/oeffent., Mitglieder-Zaehler). (2) Marketplace – Marktplatz mit Anzeigen (Kauf/Tausch/Gratis, 10 Kategorien, Zustand, Filter). (3) Challenges – Community-Challenges mit Punkten, Schwierigkeit, Fortschritt. (4) Badges – 12 Default-Badges (common→legendary), Raritaet, Punkte, Profil-Integration. (5) Wiki – knowledge_articles CRUD mit 9 Kategorien, Tags, Volltextsuche. Navigation: comingSoon entfernt, neue Gruppe 'Gruppen & Mehr'. SQL: 032_b7_new_modules.sql (groups, group_members, group_posts, marketplace_listings, challenges, challenge_progress, badges, user_badges, bot_scheduled_messages + 12 Badge Seeds) | groups/page.tsx,marketplace/page.tsx,challenges/page.tsx,badges/page.tsx,wiki/page.tsx,navigationConfig.ts,032_b7_new_modules.sql |
