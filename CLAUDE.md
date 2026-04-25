# CLAUDE.md – Mensaena Projektkontext

## Projekt
Mensaena – Nachbarschaftshilfe-Plattform, live unter www.mensaena.de
Version 1.0.0-beta | Sprache: Deutsch

## Tech-Stack
- Next.js 15.3.0 (App Router, SSR), React 19, TypeScript (strict, kein `any`)
- Tailwind CSS 3.4 (`clsx` + `tailwind-merge`), Zustand 4.5
- Supabase (PostgreSQL, Auth, Realtime, Storage, RLS)
- Leaflet 1.9.4 + MarkerCluster, Lucide React, react-hot-toast
- Cloudflare Pages + Workers (via @opennextjs/cloudflare)

## Pfade
- `@/*` → `./src/*`
- Seiten: `src/app/`, UI: `src/components/ui/`, Navigation: `src/components/navigation/`
- Styles: `src/styles/globals.css`, Landing: `src/app/landing/components/`
- Dashboard-Module: `src/app/dashboard/[modul]/`, Utilities: `src/lib/`, Stores: `src/stores/`
- Dashboard-Komponenten: `src/components/dashboard/`
- Shared-Komponenten: `src/components/shared/`

## Design-System
- Primary: #1EAAA6 (primary-500), Dark: #147170, Light: #d0f5f3
- Background: #EEF9F9, Trust: #4F6D8A, Emergency: #C62828
- Text: gray-900 (Titel), gray-700 (Body), gray-400 (Muted)
- CSS-Klassen: btn-primary, btn-secondary, btn-outline, btn-ghost, btn-danger, card, card-hover, input, form-error
- Schatten: shadow-soft, shadow-card, shadow-glow, shadow-glow-teal
- KEINE emerald-Farben verwenden → stattdessen primary-* (teal)

## Design-Prinzip
Elegant, professionell, subtil. NICHT erdrückend, NICHT zu verspielt.
Dezente Animationen, klare Hierarchie, viel Weißraum.

## Build & Deploy
1. `npm run build` – Fehler? Sofort beheben
2. `git add -A && git commit -m "..."`
3. `git push origin main`
→ GitHub Actions deployed automatisch auf www.mensaena.de via Cloudflare Workers

### Bestätigter Status (2026-04-25, Run #83)
Beide Workflows laufen grün auf jedem Push zu `main`:
- **deploy.yml** → www.mensaena.de + mensaena.de (Cloudflare Workers) ✅
- **android.yml** → Signierte APK + GitHub Release + F-Droid Index ✅

Bekannte Abhängigkeit: `@anthropic-ai/sdk` muss in `package.json` stehen
(für `/api/emails/optimize-subject`). Fehlt es → Build-Fehler "Module not found".

### Deploy-Workflow (.github/workflows/deploy.yml)
Der Workflow macht genau diese 4 Schritte – **nichts weiter, nichts anderes**:
1. `npm ci` – Dependencies installieren
2. `npx opennextjs-cloudflare build` – Next.js für Cloudflare Workers bauen
3. Token-Validierung (CLOUDFLARE_API_TOKEN Secret)
4. `mv open-next.config.ts _open-next.config.ts.ci-skip && npx wrangler deploy`

**Wichtig:** Das `mv open-next.config.ts` ist zwingend nötig! Wrangler 4.x erkennt
`open-next.config.ts` und ruft automatisch `opennextjs-cloudflare deploy` auf → das
schlägt mit Error 10000 (edge-preview API) fehl. Umbenennen vor `wrangler deploy` verhindert das.

**NIEMALS** in den Deploy-Workflow einfügen:
- Supabase CLI / `supabase db push` → bricht den Build (CLI nicht als npm-Paket verfügbar)
- Weitere Build-Schritte → erhöhen Timeout-Risiko

### Supabase Migrationen
Neue Migrations-Dateien liegen in `supabase/migrations/`.

**Option A – Manuell über Supabase Dashboard:**
SQL Editor → Migration-SQL einfügen → Run

**Option B – Claude Code (empfohlen) via Supabase Management API:**
Kein Shadow-DB-Problem, funktioniert direkt. Claude braucht nur den **Supabase Access Token**:
- supabase.com/dashboard/account/tokens → "Generate new token"

Claude führt dann aus:
```bash
curl -X POST "https://api.supabase.com/v1/projects/huaqldjkgyosefzfhjnf/database/query" \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"<SQL-Inhalt>\"}"
```
Leeres Array `[]` als Antwort = Erfolg. Token wird nur für die Dauer der Sitzung verwendet.

**NIEMALS** `supabase db push` in den GitHub Actions Deploy-Workflow einfügen
→ CLI ist dort nicht verfügbar und bricht den Build.

### Benötigte GitHub Secrets
| Secret | Woher |
|--------|-------|
| `CLOUDFLARE_API_TOKEN` | Cloudflare Dashboard → My Profile → API Tokens |
| `GOOGLE_SERVICES_JSON` | Firebase Console → Android App → google-services.json |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 mensaena.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore-Passwort |
| `ANDROID_KEY_ALIAS` | Key-Alias (Standard: `mensaena`) |
| `ANDROID_KEY_PASSWORD` | Key-Passwort |

## Git Push (bei lokalem Proxy-Problem)
```bash
git push "https://x-access-token:<PAT>@github.com/manuelbrandner85/Mensaena.git" main:main
```
Token: In den GitHub Repository Secrets hinterlegt (nicht im Code speichern!)

## Wichtige Hinweise
- Supabase anon key ist absichtlich öffentlich (wie Firebase API key) – durch RLS gesichert
- `typescript.ignoreBuildErrors: true` ist nötig für Cloudflare/OpenNext-Kompatibilität
- Leaflet nur dynamisch laden (`dynamic(() => import(...), { ssr: false })`)
- `'use client'` für interaktive Komponenten, Server Components für statische Inhalte
