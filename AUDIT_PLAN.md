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

## Phase 2: Social & Community ✅
- [x] `components/chat/ChatView.tsx` — Chat (Community + DM)
- [x] `dashboard/groups` — Gruppen
- [x] `dashboard/community` — Community
- [x] `dashboard/notifications` — Notifications

## Phase 3: Matching & User-zu-User ✅
- [x] `dashboard/matching` — Match-Vorschläge & Antworten
- [x] `dashboard/interactions` — Interaktionen (Helfer ↔ Hilfe)
- [x] `dashboard/profile` + `[userId]` — Profil & Fremd-Profil
- [x] `dashboard/badges` — Badges

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
| 2 | ✅ done | — | 7 fixes: chat search injection, send/delete/pin error handling, prefs maybeSingle, groups error checks, community widget |
| 3 | ✅ done | — | 8 fixes: interactions silent RLS failures, conv create error, profile maybeSingle + fallback, badges state mutation |
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

### Phase 2 — Social & Community

**Fixed:**
1. `ChatView.tsx:2127-2143` — User-Suche nach DM-Partnern hatte ilike/or() Injection (User-Input ungeprüft in PostgREST-Filter). `sanitizeForOrFilter` + `escapeIlike` Helfer eingefügt + Error-Check.
2. `ChatView.tsx sendMessage` — Bei Insert-Fehler nur console.error, keine User-Feedback. Toast eingefügt.
3. `ChatView.tsx handleDeleteMessage` — Kein Error-Check, keine Rollback. Optimistic mit Snapshot + Rollback bei Fehler.
4. `ChatView.tsx handlePinMessage` — Kein Error-Check, keine Rollback. Optimistic mit Rollback.
5. `NotificationPreferences.tsx` — `.single()` ohne Error-Catch (Promise-Rejection bei 0 rows). Auf `.maybeSingle()` umgestellt + Error-Log + Default-Fallback wenn Profile keine Notify-Spalten hat.
6. `groups/page.tsx loadData` — Errors auf `groups`/`group_members` ignoriert. Error-Toast + console.error eingefügt.
7. `groups/[groupId]/page.tsx:104` — `.single()` auf group ohne Error-Check. Auf `.maybeSingle()` umgestellt.
8. `community/page.tsx CommunityPulseWidget` — Errors ignoriert, `(p: any)`-Cast. Errors loggen, korrekter Type, Cleanup-Flag gegen stale-state nach unmount.

**Verifizierte False Positives:**
- `ChatView.tsx:202` — `isAdminUser(null)` ist sicher (Function checks `if (!profile) return false`). Kein Crash.
- `ChatView.tsx:236` — `or('title.eq.Community Chat,...')` ist hardcoded, kein User-Input.
- `ChatView.tsx:264, 388, 407, 620` — `.single()` jeweils mit `if (data)` / `if (conv)` Guards bzw. innerhalb try/catch geschützt.
- `useNotifications` Hook — Subscription wird korrekt im cleanup unsubscribed, Date-Grouping Calendar-aligned korrekt.

### Phase 3 — Matching & User-zu-User

**Fixed:**
1. `interactions/stores/useInteractionStore.ts respondToInteraction` — Conversation-Insert für Hilfe-Chat ohne Error-Check; bei RLS-Block blieb `convId` still null und Toast meldete trotzdem Erfolg. Error-Check + Early-Return + Toast.
2. `interactions/stores/useInteractionStore.ts respondToInteraction` — Accept- und Decline-Pfade riefen `update()` ohne Error-Check und zeigten Erfolgs-Toast unabhängig vom RLS-Ergebnis. Beide Pfade mit Error-Destrukturierung + Early-Return + Toast.
3. `interactions/stores/useInteractionStore.ts startProgress` — Same silent-RLS-failure-Pattern. Fixed.
4. `interactions/stores/useInteractionStore.ts completeInteraction` — Same. Fixed.
5. `interactions/stores/useInteractionStore.ts cancelInteraction` — Same. Fixed.
6. `interactions/stores/useInteractionStore.ts disputeInteraction` — Same. Fixed.
7. `interactions/stores/useInteractionStore.ts loadInteractionById` / `createInteraction` — Partner-/Post-/Match-Lookups mit `.single()` (PGRST116 bei legitim fehlenden Rows). Auf `.maybeSingle()` umgestellt.
8. `profile/page.tsx` — `.single()` auf eigenes Profil; bei fehlender Row blieb `!profile`-Skeleton ewig. Auf `.maybeSingle()` + Error-Log + Fallback-Profil-Objekt umgestellt.
9. `badges/page.tsx` — State-Mutation: bei `filterCat === 'all'` war `filtered === badges` (gleiche Referenz), `filtered.sort()` mutierte den Badges-State. `[...filtered].sort(...)` Fix. Außerdem: Cancelled-Flag, Error-Checks auf `badges`/`user_badges`, `(b: any)`-Cast entfernt.

**Verifizierte False Positives:**
- `matching/stores/useMatchingStore.ts` — Error-Handling delegiert an API-Helfer in `@/lib/matching/match-algorithm`. Realtime-Channel subscribe/unsubscribe korrekt, `subscribeToRealtime` guarded.
- `profile/[userId]/ProfilePage.tsx` — `.single()` auf Profile-Lookup ist mit `if (profileErr || !profileData)` Guard korrekt geschützt.
