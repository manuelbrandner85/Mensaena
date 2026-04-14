# MENSAENA – Phasen-Plan
> Erstellt: 2026-04-14 | Zeitbank-Rewrite

---

## Phase 1 – Zeitbank: Hilfe eintragen + Bestätigungssystem ✅

### Schritt 1 – Zeitbank-Seite neu (ohne ModulePage) ✅
- [x] ModulePage-Abhängigkeit entfernt
- [x] `HilfeForm`: Inline-Formular mit User-Suche-Dropdown (debounced), Textarea, Stunden+Minuten-Auswahl (0–8h / 0 oder 30 Min), Datepicker (max: heute)
- [x] `HilfeHistorie`: Eintrags-Liste (bis 50) für Helfer UND Empfänger; `StatusBadge`; Bestätigen/Ablehnen-Buttons direkt in der Zeile für empfangene pending-Einträge
- [x] `Zeitkonto`: 5 parallele Supabase-Queries → given / received / balance / pending / community_total
- [x] Layout: `min-h-screen bg-[#EEF9F9]`, `max-w-2xl mx-auto`, mobile-first
- [x] Migration: `help_date DATE` Spalte für `timebank_entries` + Backfill

### Schritt 2 – Datenmodell + API-Routes ✅
- [x] Migration: `updated_at` + Trigger, CHECK constraint (pending/confirmed/cancelled/rejected), neue Tabelle `zeitbank_notifications` (id, user_id, entry_id, type, message, seen, clicked, created_at), Indexes + RLS
- [x] `src/lib/supabase/api-auth.ts`: `getApiClient()` + `err`-Helfer (unauthorized, forbidden, notFound, bad, conflict, internal)
- [x] `GET /api/zeitbank/entries` – eigene Einträge (als Helfer + Empfänger), `normalize()` (giver_id→helper_id, receiver_id→helped_id, cancelled→rejected)
- [x] `POST /api/zeitbank/entries` – Eintrag erstellen (status: pending) + `zeitbank_notifications` INSERT
- [x] `PATCH /api/zeitbank/entries/[id]/confirm` – Empfänger bestätigt; status→confirmed, confirmed_at=now(); Notification für Helfer
- [x] `PATCH /api/zeitbank/entries/[id]/reject` – Empfänger lehnt ab; status→rejected; Notification für Helfer
- [x] `GET /api/zeitbank/balance` – given/received/balance/pending_as_helper/pending_as_helped/community_total
- [x] `GET /api/zeitbank/notifications` – mit `?unseen=true` Filter; nested entry-Join

### Schritt 3 – Bestätigungs-System: Banner + Push ✅
- [x] `ZeitbankConfirmationBanner.tsx`: globale Client-Komponente (ssr: false), lädt unseen confirmation_requests beim Mount, abonniert `zeitbank_notifications` via Supabase Realtime
- [x] Animiertes Slide-in-Banner mit Avatar, Helfer-Name, Stunden, Beschreibung
- [x] Inline Bestätigen / Ablehnen → PATCH API → Banner gleitet raus, Notification als seen+clicked
- [x] X-Button → schließen ohne Aktion, markiert seen
- [x] `DashboardShell.tsx`: Banner als `dynamic(..., { ssr: false })` eingebunden (erscheint auf ALLEN Dashboard-Seiten)
- [x] `POST /api/zeitbank/entries`: Dual-Notification beim Eintragen
  - `zeitbank_notifications` → triggert Banner via Realtime
  - `notifications` (category: interaction) → triggert Toast + Sound + Browser Push über AppShell Realtime

---

## Phase 2 – (Planned)
> Nächste Phase nach Abschluss Phase 1

---
