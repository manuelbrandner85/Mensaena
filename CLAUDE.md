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
