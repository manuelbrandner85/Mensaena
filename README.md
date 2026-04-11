# Mensaena
**Die Gemeinwohl-Plattform** – Gemeinsam stärker, lokal vernetzt.

---

## URLs
| Umgebung | URL |
|----------|-----|
| **Production** | https://www.mensaena.de |
| **Cloudflare Pages** | https://mensaena.pages.dev |
| **Supabase Dashboard** | https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf |
| **Cloudflare Dashboard** | https://dash.cloudflare.com |

---

## Tech-Stack
- **Frontend:** Next.js 15.3.0, React 19, TypeScript, Tailwind CSS 3.4
- **Backend/DB:** Supabase (PostgreSQL, Auth, Realtime, Storage, RLS)
- **Hosting:** Cloudflare Pages + Workers (@opennextjs/cloudflare)
- **Karten:** Leaflet 1.9.4 + MarkerCluster + OpenStreetMap
- **Icons:** Lucide React
- **State:** React Hooks + Zustand 4.5
- **PWA:** Service Worker, Manifest, Offline-Seite, Push-Subscriptions

---

## Features

### Infrastruktur
- Next.js 15.3 App Router mit SSR über Cloudflare Workers
- Supabase Auth (E-Mail/Passwort), Auto-Profil-Trigger
- 37+ Datenbank-Tabellen mit vollständigen RLS-Policies
- Realtime für Messages, Notifications, Presence
- 8 Storage-Buckets mit 28 RLS-Policies
- Custom Domain mensaena.de + www mit SSL
- pg_cron für tägliche Bereinigung, pg_net für Webhooks

### Frontend (50+ Seiten)
- Landing Page mit Hero, Features, Testimonials
- Auth (Login, Register, Passwort-Reset, Magic-Link)
- Dashboard mit Statistiken, Feed, Schnellzugriffe
- Interaktive Karte (Leaflet, Geo-Filter, Post-Marker)
- Beitrag erstellen (10 Typen, Bild-Upload, Geo, Tags, Medien-URLs)
- Chat (Echtzeit-DM + Community, Channels, Reactions, Pins, Announcements)
- 13+ Modul-Seiten (Tiere, Wohnen, Mobilität, Ernte, Community, Wissen, etc.)
- Gruppen, Marktplatz, Challenges, Badges, Wiki
- Admin-Dashboard (10 Tabs: Übersicht, Users, Posts, Events, Board, Crisis, Orgs, Farms, Chat-Mod, System)
- Profil, Einstellungen, Benachrichtigungen
- PWA mit Offline-Unterstützung

---

## Datenbank (37+ Tabellen)
profiles, posts, interactions, conversations, conversation_members, messages, notifications, trust_ratings, regions, board_posts, board_pins, board_comments, events, event_attendees, organizations, organization_reviews, crises, farm_listings, farm_reviews, chat_announcements, chat_channels, chat_banned_users, message_reactions, message_pins, user_status, content_reports, saved_posts, post_comments, post_votes, post_shares, push_subscriptions, groups, group_members, group_posts, marketplace_listings, challenges, challenge_progress, badges, user_badges, bot_scheduled_messages, timebank_entries, knowledge_articles, skill_offers, volunteer_signups, matches, interaction_updates, rate_limits, user_blocks

---

## Deployment

### Lokal entwickeln
```bash
npm run dev          # Next.js Dev-Server (Port 3000)
```

### Auf Cloudflare Pages deployen
```bash
npx opennextjs-cloudflare build
npx wrangler deploy
```

---

## Projekt-Status
**Version:** 1.0.0-beta
**Deployment:** Aktiv (www.mensaena.de)
**Letzte Aktualisierung:** 11. April 2026
**Offene Audit-Punkte:** 161 (37 kritisch, 35 wichtig, 22 sollte, 4 nice-to-have)
