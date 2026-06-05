---
name: mensaena-architektur
description: Architektur und Design-System der Mensaena Plattform
globs: ["src/**", "package.json", "tailwind.config.*"]
---

# Mensaena Architektur

## Tech-Stack
- Next.js 15.3 (App Router, SSR) + React 19 + TypeScript (strict)
- Tailwind CSS 3.4 (clsx + tailwind-merge) + Zustand 4.5
- Supabase (PostgreSQL, Auth, Realtime, Storage, RLS)
- Cloudflare Pages + Workers (@opennextjs/cloudflare)
- Leaflet 1.9.4 + MarkerCluster, Lucide React
- Capacitor für Android-App (APK via GitHub Actions)
- LiveKit für Video/Voice Calls

## Design-System (PFLICHT)
- Primary: #1EAAA6 (teal), Dark: #147170, Light: #d0f5f3
- Background: #EEF9F9, Trust: #4F6D8A, Emergency: #C62828
- KEINE emerald-Farben → stattdessen primary-*
- CSS-Klassen: btn-primary, btn-secondary, card, card-hover, input
- Schatten: shadow-soft, shadow-card, shadow-glow-teal
- Prinzip: Elegant, professionell, subtil, viel Weißraum

## Pfade
- Seiten: src/app/, UI: src/components/ui/
- Dashboard: src/app/dashboard/[modul]/
- Stores: src/stores/, Utilities: src/lib/
- Shared: src/components/shared/

## URLs
- Production: https://www.mensaena.de
- Supabase: https://gyqujitkvymlmgroovch.supabase.co
- Cloudflare Pages: https://mensaena.pages.dev

## Wichtige Regeln
- Leaflet NUR dynamisch laden: dynamic(() => import(...), { ssr: false })
- 'use client' für interaktive Komponenten
- Server Components für statische Inhalte
- typescript.ignoreBuildErrors: true (nötig für OpenNext)
