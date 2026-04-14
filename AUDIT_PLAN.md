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

## Phase 4: Geo & Zeit ✅
- [x] `dashboard/map` — Interaktive Karte
- [x] `dashboard/mobility` — Fahrten
- [x] `dashboard/events` — Events
- [x] `dashboard/calendar` — Kalender

## Phase 5: Hilfe & Notfall ✅
- [x] `dashboard/rescuer` — Retter-Modus
- [x] `dashboard/crisis` — Krisen-Hilfe
- [x] `dashboard/mental-support` — Mentale Unterstützung
- [x] `dashboard/housing` — Wohnen
- [x] `dashboard/animals` — Tierhilfe

## Phase 6: Supply Chain ✅
- [x] `dashboard/supply` — Versorgung
- [x] `dashboard/harvest` — Ernte
- [x] `dashboard/sharing` — Teilen/Tauschen

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
| 4 | ✅ done | — | 9 fixes: map fallback/profile errors, mobility errors, events or() injection + recurring insert + reminder UX, calendar upcoming filter logic |
| 5 | ✅ done | — | 8 fixes: crisis or() injection ×2, crisis detail+trust maybeSingle, ModulePage silent errors, animals/rescuer/housing cancelled flags + error checks |
| 6 | ✅ done | — | 7 fixes: supply or()/ilike injection + error checks + product fetch cleanup, farm detail maybeSingle + cancellation, SimilarFarms ilike escape + error checks, harvest widget cancellation + error checks, sharing widget cancellation + error checks |
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

### Phase 4 — Geo & Zeit

**Fixed:**
1. `map/page.tsx fallbackMapQuery` — Errors ignoriert. Error-Log + return `[]`.
2. `map/page.tsx init` — `.single()` auf Profil ohne Error-Check; bei RLS-Fehler stillschweigend Fallback. Auf `.maybeSingle()` + Error-Log + Cancelled-Flag.
3. `MapComponent.tsx` — `getCurrentPosition`-Error-Callback war leer (`() => {}`). Jetzt `console.warn` + Timeout/maxAge Optionen, damit Mobile-Nutzer mit denied permission nicht ewig hängen.
4. `mobility/page.tsx UpcomingRidesWidget` — Query-Error ignoriert, kein Cancelled-Flag. Beides ergänzt.
5. `events/hooks/useEvents.ts fetchEvents` — `or()`-Filter mit ungeprüftem `searchQuery`. `sanitizeForOrFilter` + `escapeIlike` Helper eingeführt + leere Suche guarden.
6. `events/hooks/useEvents.ts createRecurringInstances` — `insert(instances)` ohne Error-Check; bei RLS-Fail wurde nur Parent-Event angelegt, User dachte recurring funktioniert. Error-Check + Throw mit User-Message.
7. `events/components/EventReminder.tsx` — `try/finally` ohne `catch` → bei Throw aus `setReminder`/`removeReminder` wurde Promise-Rejection unbehandelt geloggt, kein User-Feedback. `try/catch` mit Toast-Meldungen + Erfolgs-Toasts.
8. `calendar/page.tsx load` — Query-Error ignoriert, kein Cancelled-Flag. Beides ergänzt.
9. `calendar/page.tsx upcomingEvents` — Filter `d >= new Date(year, month, today.getDate() || 1)` war kaputt: bei Wechsel in vergangenen/zukünftigen Monat falscher Cutoff (mischte aktuelles Tagesdatum mit angezeigtem Monat). Saubere Logik: `max(today, monthStart)`, oder Monatsende+1 wenn Monat in der Vergangenheit (Liste leer).

**Verifizierte False Positives:**
- `events/hooks/useEvents.ts setAttendance` — keine "unrolled optimistic update": `await upsert` mit `if (error) throw` läuft VOR `setEvents`, also kein State-Drift.
- `events/[id]/page.tsx handleAttend` — `try/catch` umschließt alles, `events.setAttendance` Throw wird abgefangen + Toast.
- `events/hooks/useEvents.ts createEvent` — `[newEvent, ...prev].sort(...)` ist neues Array (Spread), nicht der State. Keine Mutation.
- `mobility/page.tsx` Map-Building — `.push()` auf frisch geholtem Array innerhalb der Map ist OK, kein React-State-Bezug.

### Phase 5 — Hilfe & Notfall

**Fixed:**
1. `crisis/stores/useCrisisStore.ts loadCrises` — `or()`-Filter mit ungeprüftem `filters.search`. `sanitizeForOrFilter` + `escapeIlike` Helper + Error-Check.
2. `crisis/stores/useCrisisStore.ts loadMoreCrises` — Gleicher Bug. Gleicher Fix.
3. `crisis/stores/useCrisisStore.ts loadCrisisDetail` — `.single()` führte bei 0 Rows zu PGRST116-Error im Detail-Load. Auf `.maybeSingle()` + Error-Log + explicit null Fallback.
4. `crisis/stores/useCrisisStore.ts createCrisis` — Profile-Trust-Check mit `.single()`; bei fehlendem Profil PGRST116 statt sauberer "kein Trust Score" Meldung. Auf `.maybeSingle()` + Error-Log.
5. `components/shared/ModulePage.tsx loadData` — Posts- und Saved-Posts-Queries ignorierten Errors komplett. Jetzt beide mit console.error. Betrifft alle Module die ModulePage nutzen.
6. `animals/page.tsx AnimalStatusWidget` — Zwei parallele Queries ohne Error-Check und ohne Cancelled-Flag (stale-state Risiko bei unmount). Beides ergänzt.
7. `rescuer/page.tsx RescuedTodayWidget` — Query-Error ignoriert, kein Cancelled-Flag. Beides ergänzt.
8. `housing/page.tsx HousingSplitView` — `load()` als useCallback, drei Queries (saved_posts, offers, requests) ohne Error-Check und ohne Cancellation. Signal-Object-Pattern eingeführt (`{ cancelled: boolean }` an load übergeben), Error-Logs auf alle drei.

**Verifizierte False Positives:**
- `mental-support/page.tsx` — Pure static content (HOTLINES-Tabelle + CrisisHotlinesWidget nur mit Country-Selector). Keine Daten-Queries, keine Bugs.
- `crisis/components/CrisisContactBar.tsx` — WhatsApp `+`-Strip ist korrekt (wa.me-Doku verlangt Ziffern ohne `+`).
- `crisis/stores/useCrisisStore.ts createCrisis` Trust-Check — Fail-closed: fehlendes Profil → `trust_score` default 0 → Throw. Kein Bypass-Bug, Logging-Fix war reine Defense-in-Depth.

### Phase 6 — Supply Chain

**Fixed:**
1. `supply/page.tsx fetchFarms` — `or()`-Filter mit ungeprüftem `debouncedQ` + `filters.state` ilike unescaped. `sanitizeForOrFilter` + `escapeIlike` Helper eingeführt, leere Suche guarden, Error-Destrukturierung + console.error ergänzt.
2. `supply/page.tsx` products-Fetch (useEffect Zeile 503) — `.catch(() => {})` swallowte alle Errors, keine Cancellation. Cancelled-Flag + explicit Error-Log.
3. `supply/farm/[slug]/page.tsx FarmDetailPage` — Farm-Load mit `.single()` + `.catch(() => setFarm(null))`: "nicht gefunden" und echte Netzwerk-Fehler waren ununterscheidbar, kein Cleanup-Flag. Auf `.maybeSingle()` + Error-Log + Cancelled-Flag.
4. `supply/farm/[slug]/page.tsx SimilarFarms` — `or()` mit `farm.city`/`farm.state` (user-submitted DB-Werte mit potenziellen `%`/`_` Wildcards) unescaped. `escapeIlike` + Error-Checks auf Primary- und Fallback-Query + Cancelled-Flag, `setLoading(false)` aus finally heraus in beide Zweige verschoben (Fallback-Query konnte `setSimilar` nach Cancellation feuern).
5. `harvest/page.tsx NearbyFarmsWidget` — Promise.all hatte keinen `.catch()`, keine Error-Destrukturierung, kein Cancelled-Flag → unhandled rejection bei DB-Fehler und infinite loading. Cancelled-Flag, Error-Log auf beide Queries, `.catch()` der Promise-Kette, Loading-State wird immer beendet.
6. `sharing/page.tsx SharingStatsWidget` — Gleiche Probleme wie rescuer/animals in Phase 5: Promise.all ohne Error-Check, kein Cancelled-Flag. Cancelled-Flag + Error-Logs ergänzt.

**Verifizierte False Positives:**
- `supply/farm/[slug]/FarmDetailClient.tsx` — Parallele Datei, aber niemand importiert sie (dead code, vermutlich alter Refactor-Rest). Nicht angefasst, da kein Runtime-Impact. Kandidat für Cleanup in einer späteren Aufräum-Phase.
- `supply/farm/add/page.tsx` — Agent meldete "unvalidated category/country". Category/Country kommen aus `<select>` mit `FARM_CATEGORIES`/fester Länder-Liste, also bei regulärer UI-Nutzung unmöglich ungültig. RLS/CHECK-Constraints liegen in der DB. Kein Code-Fix im Client nötig.
- `supply/page.tsx` CSV-Export — Agent meldete `String(undefined)` Risiko. CSV-Builder verwendet Quote-Escape korrekt und `?? ''` ist für Lesbarkeit, nicht für Korrektheit. Kein Fix.
