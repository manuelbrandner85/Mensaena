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

## Phase 1: Core Posting Flow ✅
- [x] `dashboard/create` — Beitrag erstellen Wizard
- [x] `dashboard/posts` + `[id]` — Post Listing & Detail
- [x] `dashboard/board` — Schwarzes Brett (audited, no critical issues)
- [x] `dashboard/marketplace` — Marketplace
- [x] `components/shared/PostCard.tsx` — Shared Post Card

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
| 1 | ✅ done | — | 6 fixes: sanitize or-filter, user_id typo, draft validation, optimistic rollback, PostCard status sync |
| 2 | ⏳ pending | — | — |
| 3 | ⏳ pending | — | — |
| 4 | ⏳ pending | — | — |
| 5 | ⏳ pending | — | — |
| 6 | ⏳ pending | — | — |
| 7 | ⏳ pending | — | — |
| 8 | ⏳ pending | — | — |

## Findings Log

_Pro Phase wird hier angehängt: gefundene Fehler + ob sie gefixt oder als Folge-Issue dokumentiert wurden._

### Phase 1 — Core Posting Flow

**Fixed:**
1. `posts/page.tsx`: Realtime "neue Beiträge"-Counter feuerte bei jedem INSERT (auch eigenen), weil `p.author_id` geprüft wurde, das Feld heißt aber `user_id`. → fixed
2. `posts/page.tsx`: Suchfeld konnte PostgREST `or()`-Filter brechen (Zeichen `,()"\\`). Sanitize-Helfer + ilike-Escape eingefügt. → fixed
3. `posts/page.tsx`: Fallback-Query ignorierte Errors. Jetzt mit `if (error) return []` + console.error. → fixed
4. `posts/page.tsx`: Saved-Posts-Query hatte keinen Error-Check + filterte keine null. → fixed
5. `marketplace/page.tsx`: `loadData` ignorierte Fehler. Jetzt Toast bei Fehler. → fixed
6. `marketplace/page.tsx`: `handleMarkClaimed` mit optimistischem Update + Rollback bei Fehler. → fixed
7. `create/page.tsx`: Draft-Restore aus localStorage hatte keine Schema-Validierung — `JSON.parse` konnte alles liefern. `isValidDraft()`-Type-Guard eingefügt. → fixed
8. `PostCard.tsx`: Quick-Status-Aktionen (`activate`/`archive`/`done`) updaten DB, aber Karte zeigte stale Status bis manuellem Refresh. Jetzt `localStatus`-State + `post-status-changed`/`post-deleted` Custom Events. → fixed
9. `posts/page.tsx`: Hört jetzt auf `post-status-changed`/`post-deleted` und syncht lokale Liste. → fixed

**Verifizierte False Positives (kein Fix nötig):**
- `posts/[id]/PostDetailPage.tsx:185` — bereits korrekt mit `if (postErr || !postData)` geschützt
- `posts/[id]/PostDetailPage.tsx:405` Vote-Math — `s - vote` für vote=-1 ergibt s+1, ist korrekt
