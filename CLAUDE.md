# CLAUDE.md – Mensaena Projektkontext

## Projekt
Mensaena – Nachbarschaftshilfe-Plattform, live unter www.mensaena.de
Version 1.0.0-beta | Sprache: Deutsch (Standard) + EN/IT/ES/FR/TR/RU

## Design- & Motion-Skills (global installiert, Pflicht-Nutzung)
13 Design-Skills liegen versioniert in `.agents/skills/` (SessionStart-Hook
symlinkt sie nach `.claude/skills/` → in jeder Session via Skill-Tool aufrufbar).
Quellen in `skills-lock.json`: `leonxlnx/taste-skill`, `emilkowalski/skill`,
`pbakaus/impeccable` (impeccable.style).

**Wann welcher Skill (VOR der Arbeit aufrufen, nicht danach):**
- **`emil-design-eng`** — IMMER bei Animationen/Micro-Interactions/Transitions
  (Flutter wie Web). Emil Kowalskis Prinzipien: Easing/Dauer-Entscheidungen,
  wann NICHT animiert wird, unsichtbare Details. Leitlinie für AppMotion-Springs.
- **`impeccable`** — Default für jede UI-Arbeit (Design, Redesign, Polish,
  Critique, A11y, Spacing, Typo, Farbe, Motion). Modi als Argument:
  `audit`, `polish`, `animate`, `typeset`, `colorize`, `quieter`, `bolder`.
  Respektiert vorhandene Tokens (AppColors/AppSpacing/AppMotion) — nie überschreiben.
- **`taste-skill`** — Landing pages, Portfolio-/Marketing-Seiten (Next.js-Web,
  Landing `src/app/landing/`): Anti-Slop-Richtung, keine Template-Optik.
- **`redesign-skill`** — bestehende Screens/Seiten hochwertiger machen ohne
  Funktionalität zu brechen (Audit-first).
- **`soft-skill`** — High-End-Agentur-Detailgrad (Schatten, Karten, Motion-
  Choreografie) für Premium-Flächen (Onboarding, Profil, Detail-Screens).
- **`minimalist-skill` / `brutalist-skill`** — alternative Stilrichtungen;
  bei Mensaena nur nach explizitem Auftrag (Design-Prinzip: elegant, subtil).
- **`imagegen-frontend-mobile` / `imagegen-frontend-web` / `brandkit`** —
  Bild-Generierungs-Briefings (z. B. via Higgsfield) für Screen-Konzepte,
  Referenz-Boards, Brand-Assets. Generieren NUR Bilder, keinen Code.
- **`image-to-code-skill`** — Referenzbild → Implementierung (Web).
- **`stitch-skill`** — DESIGN.md-Generierung im Stitch-Format.
- **`output-skill`** — bei großen Generierungsaufgaben gegen Truncation/Platzhalter.

**Regeln:** (1) Flutter-Motion-Arbeit = `emil-design-eng` + `impeccable animate`
zuerst lesen, dann mit AppMotion/EffectsGate umsetzen (Stream-/Perf-Regeln unten
gelten weiter). (2) Web-UI-Arbeit = `impeccable` (+ `taste-skill` für Landing).
(3) Skills liefern Geschmack/Prinzipien — Mensaena-Design-System (Farben,
Spacing, "elegant, professionell, subtil") hat immer Vorrang bei Konflikten.

## i18n-Pflicht (Flutter-App)
**JEDER neue user-facing String MUSS via `easy_localization` übersetzt werden.**

1. Schreibe NIEMALS hardcodierte UI-Strings wie `Text('Speichern')`.
   Stattdessen `Text('common.save'.tr())` mit Key aus den 7 JSON-Files.
2. Bei neuen Keys: füge die Übersetzung in ALLE 7 Files ein
   (`flutter_app/assets/translations/{de,en,it,es,fr,tr,ru}.json`).
   Quelle ist `de.json`. Übersetzungen müssen präzise sein — keine
   wörtlichen Maschinenübersetzungen, sondern natürliche Sprache pro Land.
3. Akzeptable Ausnahmen ohne `.tr()`:
   - Eigennamen ("Mensaena", "WhatsApp", "Supabase")
   - Zahlen, Datumsformate (mit `intl` formatieren)
   - SQL/API-Strings, Log-Messages, Debug-Output
   - Storage-Keys, Routen-Pfade, Asset-Pfade
4. Schlüssel-Konventionen:
   - Kategorie-Namespaces: `common`, `nav`, `navGroups`, `auth`, `profile`,
     `settings`, `chat`, `errors`, `onboarding`, `languages`.
   - Neuer Screen → eigener Top-Level-Key (z. B. `marketplace.*`,
     `events.*`, `crisis.*`).
   - Parameter-Substitution mit `{var}` und `.tr(namedArgs: {'var': value})`.
5. Pull-Request-Check (mental): Falls du irgendwo `Text(` mit deutschem
   Stringliteral siehst, ist das ein Bug — sofort beheben.

Imports: `import 'package:easy_localization/easy_localization.dart';`
Provider/Settings: `lib/providers/locale_provider.dart`
Translation-Files: `flutter_app/assets/translations/`

## Supabase-Streams: Pflicht-Regeln (gegen OOM-Crash)

**Root-Cause des 4.1.x-Crashs (2026-06-06):** App wurde über Stunden langsamer
und crashte. Ursache: Supabase `.stream()` ohne `.limit()` lädt ALLE Rows einer
Tabelle in den RAM und re-emittiert sie bei jedem Event. Nach Monaten Nutzung
= OOM-Kill durch Android.

**Regeln (vom CI erzwungen via `scripts/check_stream_limits.py`):**

1. **JEDER** `sb.from(...).stream(primaryKey: [...])` MUSS ein `.limit(N)` haben.
   Richtwerte: Notifications 150, Messages 200, Reactions 500, Calls 20, Pins 50.
   Ohne Limit = Build scheitert.
2. **JEDER** `StreamProvider.family<...>` MUSS `.autoDispose` sein. Ohne autoDispose
   bleibt der Realtime-Channel offen sobald ein Widget den Provider einmal gelesen
   hat — auch nach Verlassen des Screens.
3. **Server-Filter vor Client-Filter:** `.eq(...)` IMMER vor dem `.map()`-Block.
   Niemals "alle Rows laden + client-seitig filtern".
4. **MemoryWatchdogService läuft global** (`lib/services/memory_watchdog_service.dart`):
   Soft-Evict bei 80% Cache, Full-Clear bei OS-MemoryPressure, Pause-Cleanup.
   Nicht deaktivieren ohne Ersatz.

Ausnahmen (sehr selten): Tabellen mit garantiert <10 Rows pro User (z.B.
Singleton-Settings) — trotzdem `.limit(10)` setzen, kostet nichts.

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

### Bestätigter Status (2026-06-06) — Update-Pipeline repariert
- **Shorebird-Fix:** `shorebird.yaml` ist jetzt als Flutter-Asset in
  `flutter_app/pubspec.yaml` gebündelt. Vorher fehlte das → `shorebird release`
  fiel auf plain `flutter build apk` zurück (kein OTA-Updater, kein Release
  registriert) und `shorebird_patch.yml` übersprang JEDEN Patch. Änderungen
  erreichten nie die App.
- **flutter.yml (Run #985)** baut `4.1.5+40105` jetzt **via Shorebird** (kein
  Fallback), publiziert das GitHub-Release `v4.1.5-40105` und schreibt die
  `app_releases`-Pflichtzeile (`mandatory=true`). Ab dieser Basis greifen OTA-
  Patches für künftige Dart-only-Commits. ✅
- **supabase.yml (Run #125)** deployt Migrationen + Edge Functions grün; die
  Phase-4 **pg_cron-Jobs** sind via Migration `20260606200000` automatisch auf
  gyquj eingerichtet (Helper `private.invoke_edge_function`). ✅
- **Regel:** Reine Dart-Änderungen → OTA-Patch (kein Version-Bump). Dependencies/
  native Änderungen oder eine Pflicht-Auslieferung → Version bumpen (`flutter.yml`
  registriert dann ein neues Shorebird-Release).

Bekannte Abhängigkeit: `@anthropic-ai/sdk` muss in `package.json` stehen
(für `/api/emails/optimize-subject`). Fehlt es → Build-Fehler "Module not found".

### ⚠️ Shorebird MUSS Flutter 3.27.4 pinnen (sonst Crash auf allen Geräten)
`shorebird release/patch` nutzt ohne Pin Shorebirds gebundeltes Flutter (z. B.
3.44.x). Der App-Code ist aber auf **Flutter 3.27.4** ausgelegt (flutter.yml
`subosito 3.27.x`, plus 3.27-spezifische Plugin-Patches wie
`scripts/patch_flutter_webrtc.sh`). Ein Engine-Sprung 3.27→3.44 ließ die 4.1.5-
APK auf JEDE Interaktion nativ abstürzen. Deshalb in `flutter.yml` UND
`shorebird_patch.yml` immer `--flutter-version=3.27.4` setzen. Release- und
Patch-Engine MÜSSEN identisch sein, sonst verwirft der Client den Patch.
**ABER:** `--flutter-version` NUR bei `shorebird release` setzen — `shorebird patch`
kennt das Flag NICHT (→ Exit 64) und übernimmt die Flutter-Version automatisch
vom Ziel-Release. Im Patch-Command also KEIN `--flutter-version`.

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
curl -X POST "https://api.supabase.com/v1/projects/gyqujitkvymlmgroovch/database/query" \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"<SQL-Inhalt>\"}"
```
Leeres Array `[]` als Antwort = Erfolg. Token wird nur für die Dauer der Sitzung verwendet.

**NIEMALS** `supabase db push` in den GitHub Actions Deploy-Workflow einfügen
→ CLI ist dort nicht verfügbar und bricht den Build.

### Benötigte GitHub Secrets
| Secret | Woher | Wofür |
|--------|-------|-------|
| `CLOUDFLARE_API_TOKEN` | Cloudflare Dashboard → My Profile → API Tokens | deploy.yml (Web) |
| `GOOGLE_SERVICES_JSON` | Firebase Console → Android App → google-services.json | flutter.yml + shorebird_*.yml |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 mensaena.jks` | flutter.yml + shorebird_*.yml |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore-Passwort | flutter.yml + shorebird_*.yml |
| `ANDROID_KEY_ALIAS` | Key-Alias (Standard: `mensaena`) | flutter.yml + shorebird_*.yml |
| `ANDROID_KEY_PASSWORD` | Key-Passwort | flutter.yml + shorebird_*.yml |
| `SHOREBIRD_TOKEN` | `shorebird login:ci` → Token kopieren | shorebird_patch.yml + shorebird_release.yml |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Dashboard → Project Settings → API → service_role | flutter.yml (app_releases-Insert) + admin_agent.yml |
| `CLAUDE_CODE_OAUTH_TOKEN` | `claude setup-token` (nutzt Claude Pro/Max-Abo, **empfohlen** — kein API-Key/keine Pay-per-use) | admin_agent.yml (Code-Agent) |
| `ANTHROPIC_API_KEY` | console.anthropic.com → API Keys (Alternative zum Abo-Token) | admin_agent.yml (Code-Agent) |
| `AGENT_PAT` | GitHub → Settings → Developer settings → Fine-grained PAT (contents:write, pull-requests:write) auf `manuelbrandner85/Mensaena` | admin_agent.yml + agent_automerge.yml (Push/PR/Merge MÜSSEN über PAT laufen, sonst triggert das PR-CI nicht) |

### Admin-Entwicklungs-Agent „Godmode" (Code aus dem Dashboard)
Admins (NUR `role='admin'`) können im Dashboard unter „KI-Entwicklungs-Agent"
(`/dashboard/admin/dev-agent`) die gesamte App weiterentwickeln: Features,
Bugfixes, UI/UX, Performance, i18n, Datenbank, Sicherheit, Konfiguration —
kategorisiert über eine Chip-Leiste. Zwei Modi:

**A) Freie Aufträge (natürliche Sprache):**
1. Edge Function `admin-dev-agent` verifiziert Admin, legt `admin_dev_tasks`-Zeile
   an und triggert `admin_agent.yml` via `workflow_dispatch`.
2. `admin_agent.yml` lässt die Claude Code CLI den Code ändern (liest CLAUDE.md
   automatisch → i18n/Stream-Regeln/Design gelten), erstellt einen PR (`agent/*`).
3. Das echte Flutter-CI (`flutter.yml` Job `build`) ist das Sicherheits-Tor.
4. `agent_automerge.yml` merged **NUR bei grünem CI**; sonst bleibt der PR offen.
   - **Lückenschluss:** `flutter.yml` läuft nur bei `flutter_app/**`-Änderungen.
     Aufträge OHNE Flutter-Code (nur Migrationen/Edge/Workflows/Docs) lösen den
     Build nicht aus → `agent_automerge.yml` feuert nie. Dafür mergt
     `agent_automerge_direct.yml` diese Nicht-Flutter-Agent-PRs automatisch
     (triggert auf `pull_request`, wartet alle übrigen Checks ab, respektiert
     `await_review`). So mergt JEDER grüne Agent-Auftrag automatisch.
5. Merge auf `main` → `shorebird_patch.yml` liefert den Dart-Patch als OTA aus.

**B) KI-Tiefenanalyse (Vorschläge zum Annehmen/Ablehnen):**
1. „Scan starten" → Edge Function `admin-dev-suggestions` (action='scan')
   verifiziert Admin, legt `admin_scan_runs`-Zeile an und triggert `admin_scan.yml`.
2. `admin_scan.yml` lässt die Claude Code CLI die **gesamte** App lesen (jeden
   Screen, jedes Detail) und schreibt konkrete Vorschläge (logische Fehler, Bugs,
   UI/UX, Performance, i18n, DB, Security) als JSON nach `admin_dev_suggestions`.
   Dieser Workflow ändert KEINEN Code und erstellt KEINEN PR — er analysiert nur.
3. Der Admin sieht die Vorschläge (mit Kategorie + Severity) im Dashboard und
   nimmt sie an (→ `admin-dev-suggestions` action='accept' → erzeugt einen
   `admin_dev_tasks`-Auftrag → Pfad A ab Schritt 2) oder lehnt sie ab.

Tabellen: `admin_dev_tasks`, `admin_dev_suggestions`, `admin_scan_runs`
(alle RLS: nur `role='admin'` liest, Schreiben nur via service_role).
Beide Scan-/Agent-Workflows brauchen dieselben Secrets (kein neues nötig):
`CLAUDE_CODE_OAUTH_TOKEN` ODER `ANTHROPIC_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
(GitHub) sowie `GH_AGENT_TOKEN` (Supabase).

**Supabase Project Secret (NICHT in GitHub):**
- `GH_AGENT_TOKEN` — fine-grained PAT (contents:write, pull-requests:write,
  **actions:write**) auf `manuelbrandner85/Mensaena`. Nutzt die Edge Function,
  um den Workflow zu dispatchen. Setzen via Supabase Dashboard → Edge Functions
  → Secrets (oder kann denselben Wert wie `AGENT_PAT` haben, sofern `actions:write`
  ebenfalls aktiviert ist).

### Update-Flow (Flutter 4.0+)

**1) Shorebird OTA-Patches (lautlos, automatisch):**
- `shorebird_patch.yml` triggert auf jedem `push` zu `main` mit `flutter_app/**`-Pfaden.
- Pusht einen Dart-only Patch ans aktuelle Shorebird-Release (`pubspec.yaml.version`).
- Client mit `shorebird_code_push` SDK installiert den Patch beim nächsten App-Launch lautlos — keine UI.
- **Wichtig:** Nur Dart-Änderungen. Dependencies/native Plugins ändern → neues Release.

**2) Initial Shorebird-Release (manuell, pro Major.Minor):**
- `shorebird_release.yml` läuft NUR auf `workflow_dispatch` (Actions-Tab → manuell auslösen).
- Trigger wenn `pubspec.yaml.version` major/minor bumpt (z.B. 4.0.0+40000 → 4.1.0+41000).
- Sonst schlägt `shorebird_patch.yml` mit "no release for version X" fehl.

**3) Mandatory APK-Update (UpdateGate blockiert App, In-App-Download):**
- `flutter.yml` baut auf jedem main-Push die signierte APK + erstellt GitHub Release.
- Schreibt `app_releases`-Row mit `apk_url` und `mandatory`-Flag.
- **Auto-mandatory** wenn Commit-Message enthält: `[mandatory]`, `[force-update]`, `BREAKING:`, `BREAKING CHANGE:`
- Client `UpdateGate` (in `lib/widgets/shared/update_gate.dart`):
  - Watcht `app_releases` beim Launch
  - Wenn `latest.build_number > currentBuild` && `latest.mandatory == true` → Vollbild-Block-Screen
  - **In-App-Download** via `http`-Stream mit Progress, Speicherort `getTemporaryDirectory()`
  - **In-App-Install** via `open_filex` → triggert Android PackageInstaller-Intent
  - `AndroidManifest` hat `REQUEST_INSTALL_PACKAGES` + FileProvider schon konfiguriert

**`changelog`-JSON-Format** (von `flutter.yml` geschrieben, von Client gelesen):
```json
{ "entries": [{ "type": "feature", "title": "...", "description": "..." }] }
```

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
