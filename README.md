# Mensaena 🌿
**Die Gemeinwohl-Plattform** – Gemeinsam stärker, lokal vernetzt.

---

## 🌐 URLs
| Umgebung | URL |
|----------|-----|
| **Production (Cloudflare Pages)** | https://mensaena.pages.dev |
| **Custom Domain (DNS ausstehend)** | https://mensaena.de |
| **Supabase Dashboard** | https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf |
| **Cloudflare Dashboard** | https://dash.cloudflare.com |

---

## ✅ Abgeschlossene Features

### Infrastruktur
- [x] Next.js 14.2.5 + TypeScript + Tailwind CSS
- [x] Supabase Auth (E-Mail/Passwort), Auto-Profil-Trigger
- [x] 10 Datenbank-Tabellen mit vollständigen RLS-Policies
- [x] Realtime für Messages, Notifications, Posts
- [x] Cloudflare Pages Deployment (automatisch via Wrangler)
- [x] Custom Domain mensaena.de konfiguriert (DNS-Propagation läuft)
- [x] Supabase Storage: Buckets `avatars` + `post-images`

### Frontend
- [x] Landing Page mit Hero, Features, CTA
- [x] Login + Register (mit Passwort-Validierung)
- [x] Dashboard-Layout (Sidebar + Topbar, Client-Side Auth-Guard)
- [x] Dashboard-Übersicht (Begrüßung, Schnellzugriffe, Feed, Statistiken)
- [x] Interaktive Karte (Leaflet, Standort-Filter, Post-Marker, Detail-Panel)
- [x] Beitrag erstellen (10 Typen, Bilder-Upload bis 4 Fotos, Standort, Kontakt)
- [x] Beitrags-Feed mit Filter, Urgency-Badge, Kontakt-Buttons
- [x] Profil (Bearbeitung, Avatar-Upload via Camera-Button)
- [x] Chat (Echtzeit-Nachrichten, Nutzerprofil-Suche, neue Direktchats)
- [x] 13+ Modul-Seiten (Tiere, Community, Krise, Wohnen, Wissen, etc.)
- [x] Einstellungen, Datenschutz, Impressum

---

## 🗄️ Datenarchitektur

### Supabase-Tabellen
| Tabelle | Beschreibung |
|---------|--------------|
| `profiles` | Nutzerprofile (Name, Bio, Skills, Trust-Score) |
| `posts` | Beiträge (10 Typen: help_needed, rescue, animal, ...) |
| `interactions` | Hilfsangebote zu Beiträgen |
| `conversations` | Chat-Konversationen (direct/group) |
| `conversation_members` | Mitglieder der Konversationen |
| `messages` | Chat-Nachrichten (Realtime) |
| `saved_posts` | Gespeicherte Beiträge |
| `notifications` | Benachrichtigungen (Realtime) |
| `trust_ratings` | Vertrauensbewertungen (1–5 Sterne) |
| `regions` | Verfügbare Regionen (6 Seed-Regionen) |

### Supabase Storage
| Bucket | Typ | Max. Größe | Zweck |
|--------|-----|-----------|-------|
| `avatars` | Public | 5 MB | Profilbilder |
| `post-images` | Public | 10 MB | Beitragsbilder (bis 4) |

---

## 📧 E-Mail-Templates
Templates in `supabase/email-templates/`:
- `confirm-signup.html` – Willkommens-E-Mail mit Bestätigungslink
- `reset-password.html` – Passwort-Reset-E-Mail
- `magic-link.html` – Magic-Link-Login

**Einrichten:** Supabase Dashboard → Authentication → Email Templates → HTML einfügen

---

## 🔧 Ausstehende Setup-Schritte

### 1. Storage RLS Policies (2 Min.)
```sql
-- Ausführen in: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
-- Datei: supabase/004_storage_policies.sql
```

### 2. E-Mail-Templates setzen
→ [Supabase Auth → Email Templates](https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/auth/templates)

### 3. DNS für mensaena.de
Beim Domain-Registrar folgende DNS-Einträge setzen:
```
CNAME  mensaena.de     mensaena.pages.dev
CNAME  www.mensaena.de mensaena.pages.dev
```

### 4. Supabase Auth URL aktualisieren
→ [Auth → URL Configuration](https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/auth/url-configuration)
```
Site URL: https://mensaena.de
Redirect URLs: https://mensaena.de/**, https://mensaena.pages.dev/**
```

---

## 🚀 Deployment

### Lokal entwickeln
```bash
npm run dev          # Next.js Dev-Server (Port 3000)
pm2 start ecosystem.config.cjs  # PM2 Daemon
```

### Auf Cloudflare Pages deployen
```bash
npm run build
npx @cloudflare/next-on-pages --skip-build
npx wrangler pages deploy .vercel/output/static --project-name mensaena --branch main
```

---

## 🛠️ Tech-Stack
- **Frontend:** Next.js 14.2.5, React 18, TypeScript, Tailwind CSS
- **Backend/DB:** Supabase (PostgreSQL, Auth, Realtime, Storage)
- **Hosting:** Cloudflare Pages + Workers
- **Karten:** Leaflet + OpenStreetMap
- **Icons:** Lucide React
- **State:** React Hooks + Zustand

---

## 📊 Projekt-Status
**Version:** 1.0.0-beta  
**Deployment:** ✅ Aktiv (https://mensaena.pages.dev)  
**Supabase:** ✅ Verbunden (10 Tabellen, Auth, Realtime, Storage)  
**Letzte Aktualisierung:** 31. März 2026
