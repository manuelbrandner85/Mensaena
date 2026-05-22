---
name: mensaena-features
description: Feature-Übersicht und Datenbank-Schema
globs: ["src/app/**", "supabase/**"]
---

# Mensaena Features

## 50+ Seiten
- Landing, Auth (Login, Register, Reset, Magic-Link)
- Dashboard mit Statistiken, Feed, Schnellzugriffe
- Interaktive Karte (Leaflet, Geo-Filter, Cluster)
- Beitrag erstellen (10 Typen, Bild-Upload, Geo, Tags)
- Chat (Echtzeit-DM + Community, Channels, Reactions, Pins)
- 13+ Module (Tiere, Wohnen, Mobilität, Ernte, Wissen...)
- Gruppen, Marktplatz, Challenges, Badges, Wiki
- Admin-Dashboard (10 Tabs)
- Profil, Einstellungen, Benachrichtigungen
- PWA mit Offline-Support

## Datenbank (37+ Tabellen, alle mit RLS)
profiles, posts, interactions, conversations, messages,
notifications, trust_ratings, regions, board_posts, events,
organizations, crises, farm_listings, chat_channels,
message_reactions, content_reports, saved_posts, groups,
marketplace_listings, challenges, badges, timebank_entries,
knowledge_articles, skill_offers, volunteer_signups, matches,
rate_limits, user_blocks (+ weitere)

## 8 Storage-Buckets mit 28 RLS-Policies

## Offene Audit-Punkte: 161
- 37 kritisch, 35 wichtig, 22 sollte, 4 nice-to-have
