# MENSAENA – TODO
> Aktualisiert: 2026-04-10
> JEDER Prompt = diese Datei updaten. KEINE AUSNAHME.
> [x]=done []=open [SQL]=User führt SQL aus

## CACHE
OPEN=5.2(Dashboard),5.3(Dashboard),5.5(Dashboard),5.6(Dashboard)
COUNT=31
NEXT=B5.2-5.6 manuell im Supabase Dashboard (Anleitung: supabase/B5_INFRA_ANLEITUNG.md)
LAST_SESSION=2026-04-10
LAST_TASK=B5 Infra teilweise (DNS OK, Auth-Redirect+Templates+Deploy erledigt, 4 Dashboard-Schritte offen)

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
- [x] B4 Features komplett (4.1-4.11) + Deploy auf Cloudflare

## Ad-hoc
- [x] Intelligente Modul-Zuordnung: ModulePage.moduleFilter[] (type+categories Regeln),
      Posts erscheinen NUR in passenden Modulen (z.B. Wohnungssuche nur unter Wohnen,
      Tier-Notfall nur unter Tierhilfe, Mental nur unter Mentale Unterstuetzung).
      Betroffene Dateien: ModulePage.tsx (ModuleFilterRule Export), housing/, rescuer/,
      animals/, mobility/, sharing/, community/, mental-support/, timebank/,
      skills/, knowledge/, harvest/. Widget-Queries ebenfalls angepasst.

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

## B4 Features (~14h) DONE
- [x] 4.1 Create: +location_text (speichert in DB als location_text + lat/lng via Geolocation)
- [x] 4.2 Create: Bild-Upload→post-images mit Vorschau + Supabase Storage
- [x] 4.3 Create: +media_urls (bis 5 Links), +availability_start/end Datumsfelder
- [x] 4.4 Events: +is_online Toggle, +online_url Eingabefeld (Zoom/Meet/etc.)
- [x] 4.5 Profil: Trust-Tier Badge (Neu/Einsteiger/Aufbauend/Vertrauenswuerdig/Vorbildlich) + Impact-Held
- [x] 4.6 Interactions: Timeline existiert (InteractionTimeline.tsx mit UPDATE_ICONS, Add-Note)
- [x] 4.7 Matching: score_breakdown Visualisierung existiert (MatchScore.tsx mit SVG-Ring + Balken)
- [x] 4.8 Timebank: CRUD-UI existiert (TimebankWidget + SkillCategoriesWidget via ModulePage)
- [x] 4.9 Skills/Knowledge/Volunteer: eigene UIs existieren (TopSkillsWidget, LatestGuidesWidget)
- [x] 4.10 Klaerung: post_tags Tabelle in B8 als Duplikat entfernt, posts.tags[] ist Standard
- [x] 4.11 Klaerung: crisis_reports in B8 als Duplikat entfernt, crises ist Standard

## B5 Infra (~3h) MANUELL
- [x] 5.1 DNS: mensaena.de+www.mensaena.de aktiv auf Cloudflare Pages mit SSL
- [ ] 5.2 Auth URLs: Site=https://www.mensaena.de, Redirects=mensaena.de/**+pages.dev/**+localhost/** (Supabase Dashboard)
- [ ] 5.3 Email-Templates einfuegen: 4 HTML-Templates in supabase/templates/ (Supabase Dashboard)
- [x] 5.4 Storage RLS: 004_storage_policies.sql
- [ ] 5.5 pg_cron aktivieren (Supabase Extensions Dashboard) + cron.schedule SQL
- [ ] 5.6 pg_net aktivieren (Supabase Extensions Dashboard)
- [x] 5.7 Secrets: SUPABASE_SERVICE_ROLE_KEY bereits als CF Worker Secret, env vars in wrangler.toml
- [x] 5.8 Auth: emailRedirectTo im signUp-Code gesetzt (auth/page.tsx)
- [x] 5.9 Email-Templates erstellt (4 Dateien: confirm_signup, reset_password, magic_link, invite_user)
- [x] 5.10 Deploy: mensaena.de + www.mensaena.de live

## B6 Polish (~7h) DONE
- [x] 6.1 [SQL] post_comments: Tabelle+RLS+Trigger+UI (CommentsSection mit Reply-Tree, Edit, Delete, Author-Badge)
- [x] 6.2 [SQL] push_subscriptions: Tabelle+RLS, SW Push (sw-push.js) schon vorhanden, VAPID=manuell
- [x] 6.3 PWA: manifest.json+SW+offline.html existierten, Icons generiert (72-512px + maskable + apple-touch)
- [x] 6.4 Notifications: Bot-Filter existierte, +comment Kategorie (Typ, Icon, Farbe, Label, Filter-Tab)
- [x] 6.5 [SQL] post_votes: Tabelle+RLS+Unique, Vote-UI in PostCard (ThumbsUp/Down+Score) + PostDetailPage
- [x] 6.6 [SQL] post_shares: Tabelle+RLS, Share-Tracking in ShareMenu (copy/whatsapp/email/native) + Zaehler

## B7 Neue Module (~40h) DONE
- [x] 7.1 [SQL] Groups: groups+group_members+group_posts Tabellen+RLS+UI (Erstellen,Beitreten,Verlassen,10 Kategorien)
- [x] 7.2 [SQL] Marketplace: marketplace_listings Tabelle+RLS+UI (Anzeigen,Preis/Tausch/Gratis,10 Kategorien)
- [x] 7.3 [SQL] Challenges: challenges+challenge_progress Tabellen+RLS+UI (Erstellen,Teilnehmen,Fortschritt,Punkte)
- [x] 7.4 [SQL] Badges: badges+user_badges Tabellen+RLS+12 Seeds+UI (Raritaet,Punkte,Profil)
- [x] 7.5 Wiki: knowledge_articles CRUD UI (9 Kategorien,Tags,Volltextsuche,Artikel-Detail)
- [x] 7.6 [SQL] Bot: bot_scheduled_messages Tabelle+RLS (UI folgt spaeter als Admin-Feature)
- [x] 7.7 [SQL] Mig033 DB-Fix: group_members/group_posts RLS Rekursion behoben, user_badges+bot_scheduled_messages erstellt, badges Policy+Seeds, exec_sql() Hilfsfunktion

## B8 DB-Clean (~3h) DONE
- [x] 8.1 crisis_reports: nicht im Frontend → DROP empfohlen (Duplikat von crises)
- [x] 8.2 post_tags: nicht im Frontend → DROP empfohlen (Duplikat von posts.tags[])
- [x] 8.3 distance_km: nur in search_posts RPC intern → kein Handlungsbedarf
- [x] 8.4 Orgs: Tabelle+50 Seeds existieren, Frontend nutzt noch v1 Suche → B3.3

## Zeit
B1:3h B2:10h B3:5h B4:14h B5:3h B6:7h B7:40h B8:3h = ~85h

## Reihenfolge
1→B5(manuell)  2→B2(DONE)  3→B3(DONE)  4→B4(DONE)  5→B6  6→B7
