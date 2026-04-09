# MENSAENA – TODO
> Aktualisiert: 2026-04-09
> JEDER Prompt = diese Datei updaten. KEINE AUSNAHME.
> [x]=done []=open [SQL]=User führt SQL aus

## CACHE
OPEN=4.1-4.11,5.1-5.7,6.1-6.6,7.1-7.6
COUNT=30
NEXT=B4
LAST_SESSION=2026-04-09
LAST_TASK=B3 Performance komplett + Deploy

## Done
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
- [x] B3 Performance komplett (3.1-3.5) + Deploy auf Cloudflare

## Ad-hoc

## B1 Sicherheit (~3h) DONE
- [x] 1.1 admin/page.tsx+ChatView.tsx: hardcoded Emails entfernt, nur role==='admin'
- [x] 1.2 Rate-Limit: checkRateLimit() in create/page,useBoard,ChatView,useEvents + lib/rate-limit.ts
- [x] 1.3 Chat: admin_hard_delete_message RPC mit soft-delete Fallback
- [x] 1.4 Cleanup: Admin-Button→run_scheduled_cleanup mit Toast

## B2 Admin-Dashboard (~10h) DONE
- [x] 2.1 Stats: get_admin_dashboard_stats→14 Cards mit Fallback-Queries
- [x] 2.2 Users: admin_get_users+change_role+delete_user mit Suche/Pagination
- [x] 2.3 Posts: Liste+Filter(Status,Typ)+admin_delete_post mit Pagination
- [x] 2.4 Orgs: Liste+Verifizierung-Toggle+admin_delete_organization
- [x] 2.5 Events: Liste+Filter+admin_delete_event
- [x] 2.6 Krisen: Liste+Filter+admin_delete_crisis
- [x] 2.7 Board: Liste+Kategorie-Filter+admin_delete_board_post
- [x] 2.8 Farms: Liste+Suche+Verifiziert/Public Toggle+admin_delete_farm
- [x] 2.9 Chat-Mod: Lock/Unlock+Ban/Unban+Suche+admin_hard_delete_message
- [x] 2.10 System: run_scheduled_cleanup+System-Info+Quick-Links

## B3 Performance (~5h) DONE
- [x] 3.1 posts/page: search_posts RPC + fallback, hasMore Bug fix
- [x] 3.2 useBoard: search_board_posts RPC + fetchBoardFallback
- [x] 3.3 useOrgStore: search_organizations_v2→v1→direct fallback chain
- [x] 3.4 Dashboard: v_unread_counts+v_active_posts views mit Fallback
- [x] 3.5 map/page: get_nearby_posts RPC + profile geo + fallback

## B4 Features (~14h)
- [ ] 4.1 Create: +location_text
- [ ] 4.2 Create: Bild-Upload→post-images,image_urls
- [ ] 4.3 Create: +media_urls,+availability_start/end
- [ ] 4.4 Events: +is_online,+online_url
- [ ] 4.5 Profil: trust_level+score_count+impact Badges
- [ ] 4.6 Interactions: Timeline aus interaction_updates
- [ ] 4.7 Matching: score_breakdown Visualisierung
- [ ] 4.8 Timebank: CRUD-UI
- [ ] 4.9 Skills/Knowledge/Volunteer: eigene UIs
- [ ] 4.10 Klärung: posts.tags vs post_tags
- [ ] 4.11 Klärung: crisis_reports vs crises

## B5 Infra (~3h) MANUELL
- [ ] 5.1 DNS: CNAME mensaena.de+www→pages.dev (beim Registrar)
- [ ] 5.2 Auth URLs: Site=mensaena.de,Redirects=/** (Supabase Dashboard)
- [ ] 5.3 Email-Templates einfügen (Supabase Dashboard)
- [x] 5.4 Storage RLS: 004_storage_policies.sql → User muss SQL ausführen
- [ ] 5.5 pg_cron aktivieren (Supabase Extensions)
- [ ] 5.6 pg_net aktivieren (Supabase Extensions)
- [ ] 5.7 Secrets: supabase_url+service_role_key

## B6 Polish (~7h)
- [ ] 6.1 [SQL] post_comments+UI
- [ ] 6.2 [SQL] push_subscriptions+SW+VAPID
- [ ] 6.3 PWA: manifest+SW+Offline
- [ ] 6.4 Notifications: Bot-Filter
- [ ] 6.5 [SQL] post_votes+Vote-UI
- [ ] 6.6 Sharing-Tracking

## B7 Neue Module (~40h)
- [ ] 7.1 [SQL] Groups: 3 Tabellen+UI
- [ ] 7.2 [SQL] Marketplace: 1 Tabelle+UI
- [ ] 7.3 [SQL] Challenges: 2 Tabellen+UI
- [ ] 7.4 [SQL] Badges: 2 Tabellen+UI
- [ ] 7.5 Wiki: knowledge_articles CRUD (existiert)
- [ ] 7.6 [SQL] Bot: 1 Tabelle+UI

## B8 DB-Clean (~3h) DONE
- [x] 8.1 crisis_reports: nicht im Frontend → DROP empfohlen (Duplikat von crises)
- [x] 8.2 post_tags: nicht im Frontend → DROP empfohlen (Duplikat von posts.tags[])
- [x] 8.3 distance_km: nur in search_posts RPC intern → kein Handlungsbedarf
- [x] 8.4 Orgs: Tabelle+50 Seeds existieren, Frontend nutzt noch v1 Suche → B3.3

## Zeit
B1:3h B2:10h B3:5h B4:14h B5:3h B6:7h B7:40h B8:3h = ~85h

## Reihenfolge
1→B5(manuell)  2→B2(DONE)  3→B3(DONE)  4→B4  5→B6  6→B7
