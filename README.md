# Mensaena – die Gemeinwohl Plattform

> Menschen verbinden. Hilfe organisieren. Ressourcen nachhaltig teilen.

---

## Projektübersicht

**Mensaena** ist eine moderne, vollständig responsive Gemeinwohl-Webseite, die Menschen lokal miteinander verbindet, Hilfe organisiert und nachhaltige Ressourcennutzung fördert.

### Technologie-Stack

| Schicht | Technologie | Zweck |
|---|---|---|
| Frontend | Next.js 14 (App Router) + React + TypeScript | Moderne, typsichere Webseite |
| Styling | Tailwind CSS | Utility-First Design System |
| Daten / Auth | **Supabase** | Authentifizierung, Datenbank, Echtzeit |
| Infrastruktur | **Cloudflare** | CDN, WAF, Caching, DDoS-Schutz |
| Deployment | Vercel (empfohlen) | Edge-Deployment mit Next.js-Optimierung |

---

## Architektur-Entscheidung: Cloudflare vs. Supabase

### Cloudflare (Infrastruktur & Sicherheit)
- **DNS & SSL** – Verwaltung und automatische Zertifikate
- **CDN** – Globale Auslieferung statischer Assets (Bilder, JS, CSS)
- **WAF** – Web Application Firewall schützt vor OWASP Top 10
- **Bot-Schutz** – Turnstile (optional) für Login/Register-Formulare
- **Rate Limiting** – Schutz vor Brute-Force und API-Missbrauch
- **DDoS-Schutz** – Automatischer Schutz auf Layer 3/4/7
- **Performance** – Minification, Caching, HTTP/3

### Supabase (Daten & Authentifizierung)
- **Auth** – Registrierung, Login, Sessions, E-Mail-Bestätigung
- **PostgreSQL** – Alle persistenten Daten (Posts, Profile, Nachrichten)
- **RLS** – Row Level Security schützt Datenzugriffe
- **Realtime** – Live-Updates für Chat und Karten-Pins
- **Storage** – Profilbilder und Post-Medien
- **Triggers** – Automatische Profil-Erstellung bei Registrierung

---

## Features

### Öffentlicher Bereich
- ✅ Professionelle Landingpage mit Hero, Features, How-It-Works
- ✅ Login mit E-Mail und Passwort
- ✅ Registrierung mit Passwort-Validierung
- ✅ Automatische Weiterleitung ins Dashboard nach Login
- ✅ Impressum und Datenschutz

### Dashboard (nach Login)
- ✅ Persönliche Übersicht mit Statistiken und Quick-Actions
- ✅ Permanente Desktop-Sidebar (immer offen)
- ✅ Mobile Drawer-Navigation
- ✅ Interaktive Leaflet-Karte mit farbigen Pins und Filtern
- ✅ Beiträge erstellen (10 Typen, Kategorien, Dringlichkeit, Standort)
- ✅ Alle Beiträge mit Kontaktoptionen
- ✅ Realtime-Chat mit Direktnachrichten und Gruppen
- ✅ Profil-Seite mit Edit-Modus
- ✅ Einstellungen (Benachrichtigungen, Datenschutz)
- ✅ 12 Fachmodule (Retter, Tiere, Wohnen, Versorgung, etc.)

---

## Routing

### Öffentlich
```
/              → Landingpage
/login         → Anmeldung
/register      → Registrierung
/impressum     → Impressum
/datenschutz   → Datenschutz
```

### Geschützt (requires Auth)
```
/dashboard                  → Übersicht & Feed
/dashboard/map              → Interaktive Karte
/dashboard/create           → Beitrag erstellen
/dashboard/chat             → Nachrichten
/dashboard/posts            → Alle Beiträge
/dashboard/profile          → Mein Profil
/dashboard/settings         → Einstellungen
/dashboard/rescuer          → Retter-System
/dashboard/animals          → Tierbereich
/dashboard/housing          → Wohnen & Alltag
/dashboard/supply           → Regionale Versorgung
/dashboard/knowledge        → Bildung & Wissen
/dashboard/mental-support   → Mentale Unterstützung
/dashboard/skills           → Skill-Netzwerk
/dashboard/mobility         → Mobilität
/dashboard/sharing          → Teilen & Tauschen
/dashboard/community        → Community
/dashboard/crisis           → Krisensystem
```

---

## Datenmodell (Supabase PostgreSQL)

| Tabelle | Zweck |
|---|---|
| `profiles` | Erweiterte Nutzerprofile (linked zu auth.users) |
| `posts` | Alle Beiträge (Hilfe, Angebote, Tiere, etc.) |
| `interactions` | Helfer-Reaktionen auf Beiträge |
| `conversations` | Chat-Gespräche (direkt, Gruppe, System) |
| `conversation_members` | Mitglieder in Gesprächen |
| `messages` | Nachrichten mit Realtime-Support |
| `saved_posts` | Gemerkte Beiträge |
| `notifications` | Systembenachrichtigungen |
| `trust_ratings` | Bewertungen zwischen Nutzern |
| `regions` | Lokale Gebiets-Definitionen |

---

## Setup-Anleitung

### 1. Repository klonen und Dependencies installieren
```bash
git clone <repo-url>
cd webapp
npm install
```

### 2. Supabase Projekt einrichten
1. Erstelle ein neues Projekt auf [supabase.com](https://supabase.com)
2. Gehe zu **SQL Editor** und führe die Migrations-Dateien aus:
   - `supabase/migrations/001_schema.sql`
   - `supabase/migrations/002_seed.sql`
   - `supabase/migrations/003_realtime.sql`
3. Unter **Settings > API** findest du URL und Anon Key

### 3. Umgebungsvariablen
```bash
cp .env.example .env.local
# Trage deine Supabase-Werte ein:
# NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
# NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
```

### 4. Entwicklungsserver starten
```bash
npm run dev
# → http://localhost:3000
```

### 5. Produktions-Build
```bash
npm run build
npm start
# Oder mit PM2:
pm2 start ecosystem.config.cjs
```

---

## Deployment

### Vercel (Empfohlen)
```bash
# Via Vercel CLI
npx vercel

# Environment Variables in Vercel Dashboard setzen:
# NEXT_PUBLIC_SUPABASE_URL
# NEXT_PUBLIC_SUPABASE_ANON_KEY
```

### Cloudflare Pages (Alternative)
```bash
# Konfiguration in wrangler.jsonc anpassen
# Build-Befehl: npm run build
# Output-Verzeichnis: .next
```

---

## Cloudflare-Integration

Nach dem Deployment empfehlen wir folgende Cloudflare-Konfiguration:

1. **DNS** – Domain auf Vercel/Server zeigen lassen
2. **SSL/TLS** – Full (strict) Modus aktivieren
3. **WAF** – Managed Rules aktivieren
4. **Caching** – Static Assets (JS/CSS/Images) cachen
5. **Rate Limiting** – `/login` und `/register` auf max. 10 Req/Min begrenzen
6. **Bot-Schutz** – Turnstile auf Auth-Formulare (optionaler Schritt)
7. **Page Rules** – `/dashboard/*` nicht cachen (dynamisch)

---

## Design System

| Farbe | Hex | Verwendung |
|---|---|---|
| Primär Grün | `#66BB6A` | Buttons, Links, Akzente |
| Helles Grün | `#A5D6A7` | Badges, Backgrounds |
| Vertrauens-Blau | `#4F6D8A` | Sekundäre Elemente |
| Warm Beige | `#F5F0E6` | Hintergründe, Karten |
| Notfall Rot | `#C62828` | Kritische Meldungen |
| Background | `#F6FBF6` | Seiten-Hintergrund |

---

## Status

- **Version**: 1.0.0
- **Phase**: Basis-Implementation vollständig
- **Platform**: Vercel + Supabase + Cloudflare
- **Zuletzt aktualisiert**: März 2026

### Nächste Schritte
- [ ] Supabase Storage für Profilbilder integrieren
- [ ] Push-Benachrichtigungen (Web Push API)
- [ ] Erweiterte Kartenfilter mit PostGIS-Abfragen
- [ ] Cloudflare Turnstile in Auth-Formulare integrieren
- [ ] Admin-Dashboard für Moderatoren
- [ ] Mobile PWA-Manifest optimieren
- [ ] E-Mail-Templates in Supabase konfigurieren
