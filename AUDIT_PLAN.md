# Mensaena Module Audit — Error & Logic Review

**Vorgehen**: In Phasen, nach jeder Phase Push & Deploy. Vor jeder Phase Freigabe durch User.

**Pro Modul prüfen**:
- Laufzeitfehler (null/undefined access, async race conditions, stale closures)
- Falsche Logik (off-by-one, Bedingungen, Filter, Grouping)
- RLS / Supabase Fehlerbehandlung (error ignoriert, falsches `.single()`)
- Zustandsmanagement (stale state, Memory Leaks, fehlende Cleanup)
- Validierung (leere Eingaben, max/min Werte, Regex)
- Effekte (fehlende/fehlerhafte Dependencies, doppelte Subscriptions)
- TypeScript-Gefahren (`any`, falsches Casting)
- Nicht-erreichbarer Code / Dead branches
- Accessibility Offenes (aria, keyboard nav, tab order)
- Mobile vs Desktop Edge Cases

---

## Phase 1: Core Posting Flow
- [ ] `dashboard/create` — Beitrag erstellen Wizard
- [ ] `dashboard/posts` + `[id]` — Post Listing & Detail
- [ ] `dashboard/board` — Schwarzes Brett
- [ ] `dashboard/marketplace` — Marketplace
- [ ] `components/shared/PostCard.tsx` — Shared Post Card

## Phase 2: Social & Community
- [ ] `components/chat/ChatView.tsx` — Chat (Community + DM)
- [ ] `dashboard/groups` — Gruppen
- [ ] `dashboard/community` — Community
- [ ] `dashboard/notifications` — Notifications

## Phase 3: Matching & User-zu-User
- [ ] `dashboard/matching` — Match-Vorschläge & Antworten
- [ ] `dashboard/interactions` — Interaktionen (Helfer ↔ Hilfe)
- [ ] `dashboard/profile` + `[userId]` — Profil & Fremd-Profil
- [ ] `dashboard/badges` — Badges

## Phase 4: Geo & Zeit
- [ ] `dashboard/map` — Interaktive Karte
- [ ] `dashboard/mobility` — Fahrten
- [ ] `dashboard/events` — Events
- [ ] `dashboard/calendar` — Kalender

## Phase 5: Hilfe & Notfall
- [ ] `dashboard/rescuer` — Retter-Modus
- [ ] `dashboard/crisis` — Krisen-Hilfe
- [ ] `dashboard/mental-support` — Mentale Unterstützung
- [ ] `dashboard/housing` — Wohnen
- [ ] `dashboard/animals` — Tierhilfe

## Phase 6: Supply Chain
- [ ] `dashboard/supply` — Versorgung
- [ ] `dashboard/harvest` — Ernte
- [ ] `dashboard/sharing` — Teilen/Tauschen

## Phase 7: Wissen & Wachstum
- [ ] `dashboard/wiki` — Wiki
- [ ] `dashboard/knowledge` — Wissen
- [ ] `dashboard/skills` — Fähigkeiten
- [ ] `dashboard/challenges` — Challenges
- [ ] `dashboard/timebank` — Zeitbank

## Phase 8: Organisation & Verwaltung
- [ ] `dashboard/organizations` + `[orgId]` — Hilfsorganisationen
- [ ] `dashboard/admin` — Admin-Dashboard
- [ ] `dashboard/settings` — Einstellungen
- [ ] `dashboard/DashboardShell.tsx` + `layout.tsx` + Navigation

---

## Fortschritt

| Phase | Status | Commit | Notizen |
|-------|--------|--------|---------|
| 1 | ⏳ pending | — | — |
| 2 | ⏳ pending | — | — |
| 3 | ⏳ pending | — | — |
| 4 | ⏳ pending | — | — |
| 5 | ⏳ pending | — | — |
| 6 | ⏳ pending | — | — |
| 7 | ⏳ pending | — | — |
| 8 | ⏳ pending | — | — |

## Findings Log

_Pro Phase wird hier angehängt: gefundene Fehler + ob sie gefixt oder als Folge-Issue dokumentiert wurden._
