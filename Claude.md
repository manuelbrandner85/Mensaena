# Mensaena – Gemeinwohl-Plattform

## Projekt-Überblick
Nachbarschaftshilfe-Plattform mit Community-Features, Echtzeit-Chat, interaktive Karte, Marktplatz, Gruppen, Challenges, Wiki, Admin-Dashboard. PWA-fähig. Live unter www.mensaena.de

## Tech-Stack
- Framework: Next.js 15.3.0 (App Router, SSR)
- React: 19, TypeScript (strict)
- Styling: Tailwind CSS 3.4, Font: Inter
- State: Zustand 4.5 + React Hooks
- Backend: Supabase (PostgreSQL, Auth, Realtime, Storage, RLS)
- Karten: Leaflet 1.9.4 + MarkerCluster + react-leaflet
- Icons: Lucide React
- Toasts: react-hot-toast
- Hosting: Cloudflare Pages + Workers (@opennextjs/cloudflare)

## Pfad-Struktur
- @/* → ./src/*
- src/app/ → Seiten (App Router, 50+ Seiten)
- src/components/ui/ → Button, Card, Input, Heading, Text, Textarea, FormField
- src/components/navigation/ → AppShellWrapper, Sidebar, Mobile-Nav
- src/lib/ → Utilities, Supabase-Client, SEO-Konstanten
- src/styles/globals.css → Globale Styles + Tailwind
- src/stores/ → Zustand Stores

## Design-System
- Primary (Teal): #1EAAA6 (primary-500)
- Background: #EEF9F9
- Trust (Blau): trust-50 bis trust-600
- Emergency (Rot): #C62828
- Text: Überschriften gray-900, Fließtext gray-700, Muted gray-400
- Schatten: shadow-soft, shadow-card, shadow-hover, shadow-glow-teal

## UI-Komponenten
- Buttons: src/components/ui/Button.tsx (primary, secondary, danger, ghost)
- Cards: src/components/ui/Card.tsx (hover, glow, padding-Varianten)
- Inputs: src/components/ui/Input.tsx + FormField.tsx
- Headings: src/components/ui/Heading.tsx (h1-h4 + subtitle)
- Text: src/components/ui/Text.tsx (body, small, muted)

## Konventionen
- TypeScript strict, keine any
- Funktionale Komponenten, Arrow Functions
- Tailwind mit clsx + tailwind-merge
- Deutsche UI-Texte
- Lucide React für Icons
- Commit-Messages auf Deutsch

## Build & Deploy
- npm run dev (lokal Port 3000)
- npm run build (Production Build)
- npx opennextjs-cloudflare build + npx wrangler deploy
- Auto-Deploy via GitHub Actions bei Push auf main
- Live: www.mensaena.de + mensaena.de
