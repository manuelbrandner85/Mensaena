# Migrations-Runbook: Mensaena-DB huaqld -> gyquj

**Ziel:** Komplette Live-DB `huaqldjkgyosefzfhjnf` (eu-central-1) physisch nach
`gyqujitkvymlmgroovch` (eu-west-1) verschieben. 49 echte Nutzer, 161 Tabellen,
206 Funktionen, 116 Trigger, 20 Cron-Jobs, 15 Storage-Buckets, ~7.163 Zeilen.

> **WICHTIG:** Muss von einer Maschine mit Netzzugang zu beiden Supabase-DBs
> (Port 5432) laufen. Aus der Claude-Sandbox sind die DB-Ports gesperrt -- nur
> HTTPS geht. Also auf DEINEM Rechner oder einem CI-Runner ausfuehren.
>
> **Sicherheitsnetz:** `huaqld` wird waehrend der Migration NUR GELESEN und
> bleibt unveraendert -> jederzeit Rollback moeglich, bis du final umstellst.

---

## Voraussetzungen
- `pg_dump` / `psql` >= 15 (getestet: PG16) + `supabase` CLI.
- DB-Passwoerter beider Projekte:
  Dashboard -> Project Settings -> Database -> **Reset database password**
  (App nutzt sie NICHT -> Reset bricht die Live-App nicht).
- Ein Wartungsfenster fuer den Cutover (Phase 6).

## Verbindungs-Strings (Passwoerter [PW] einsetzen)
```bash
# Session-Pooler Port 5432 (NICHT 6543 = Transaction-Mode, taugt nicht fuer pg_dump)
export SRC="postgresql://postgres.huaqldjkgyosefzfhjnf:[SRC_PW]@aws-1-eu-central-1.pooler.supabase.com:5432/postgres"
export DST="postgresql://postgres.gyqujitkvymlmgroovch:[DST_PW]@aws-0-eu-west-1.pooler.supabase.com:5432/postgres"
```

---

## STATUS (2026-06-05)
- ✅ **Phase 1 (Schema + Daten + Auth)** — `.github/workflows/migrate-db.yml`
  (Run #12 gruen). gyquj verifiziert: **161 Tabellen, 49 auth.users**.
- ✅ **Phase 3 (Cron-Jobs)** — im selben Workflow uebertragen (20 Jobs). Keine
  hardcodierte huaqld-Referenz; `invoke_edge_function` liest URL/anon aus
  `private.push_config` (auf gyquj umgebogen).
- ✅ **Phase 2 (Storage-Dateien)** — direkt via rclone + Session-Token-S3-Auth
  (anon+service_role aus Management-API, keine Dashboard-S3-Keys). Alle 15
  Buckets verifiziert (Objektzahl + Bytes identisch). ~50 MiB.
- ✅ **Phase 4a (Schema `private`)** — email_config (8) + push_config (12) via
  Query-API kopiert. `push_config.supabase_url` + `supabase_anon_key` auf gyquj
  umgestellt. (`enya`-Schema = FREMDES Projekt, bewusst NICHT migriert.)
- ✅ **Phase 4b (Edge Functions)** — 9 Functions nach gyquj deployt (backfill-geo,
  delete-user, fuel-prices, livekit-token, notify-call, send-email, send-push,
  import-farms-overpass, import-nina-warnings). `run-migrations` = obsoletes
  Ops-Tool, weggelassen. Die 2 Import-Funktionen aus huaqld ins Repo geholt.
- ✅ **Phase 4c (URL-Rewrite)** — gespeicherte absolute huaqld-Storage-URLs in
  gyquj auf gyquj umgeschrieben: profiles.avatar_url(4)/cover_url(3),
  notifications.body(10)/content(10). (error_logs.message = nur Diagnose, belassen.)
- ✅ **Projekt-Audit (alle 6 Projekte)** — Mensaena-Inhalte NUR in huaqld:
  - WELTENBIBLIOTHEKAPP (adtvi), Weltenbibliothek (zctuf): reiner Welten-Content.
  - eakdl ("manuelbrandner85's Project"): E-Learning (courses/modules/...), fremd.
  - runpsy (Weltenbibliothekstream): >90 Tage pausiert, nicht restaurierbar (tot).
- ⏳ **Phase 5/6 (App-Cutover)** — OFFEN. env.dart-Branch erst zum Schluss mergen,
  dann APK + Web neu bauen. Danach huaqld als Rollback-Anker behalten.

> Hinweis: huaqld-DB-Passwort wurde im Zuge der Migration neu gesetzt (Workflow,
> Zufallswert). Die Live-App nutzt es nicht. Die genutzten Management-Tokens
> (`sbp_…`) nach Abschluss in Supabase -> Account -> Tokens widerrufen.

---

## Phase 1 -- Schema + Daten + Auth (das Herzstueck)
`pg_dump` der drei relevanten Schemas. **`auth` traegt die Passwort-Hashes**
(auth.users.encrypted_password) -> alle 49 Logins funktionieren danach.
**`storage`** traegt nur die Bucket-/Objekt-METADATEN (Dateien folgen in Phase 2).

```bash
pg_dump "$SRC" \
  --schema=public --schema=auth --schema=storage \
  --no-owner --no-privileges --no-publications --no-subscriptions \
  --quote-all-identifiers \
  -f mensaena_full.sql

# Einspielen. ON_ERROR_STOP=0, weil auth/storage-Schema im Ziel schon existiert
# (einige CREATE kollidieren -> erwartbar; Daten-INSERTs laufen durch).
psql "$DST" -v ON_ERROR_STOP=0 -f mensaena_full.sql 2> restore_errors.log

# restore_errors.log pruefen: "already exists" ist ok, alles andere checken.
```

Danach Sequenzen + RLS sind mit drin (pg_dump erfasst Policies, Defaults,
Trigger, Indizes, Constraints). Verifizieren:
```bash
psql "$DST" -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r';"   # erwartet 161
psql "$DST" -c "SELECT count(*) FROM auth.users;"   # erwartet 49
```

---

## Phase 2 -- Storage-Dateien (S3-Objekte)
`pg_dump` bewegt KEINE Dateien -- nur Metadaten. Die echten Files (Avatare,
Sprachnachrichten, alle Bilder) in 15 Buckets separat kopieren.

Buckets: `avatars board-images chat-images chat-voice-messages covers
crisis-images event-images event-photos group-images knowledge-images
marketplace-images organization-images post-images public voicemails`

Einfachster Weg -- **rclone** ueber die S3-kompatiblen Endpunkte
(Dashboard -> Storage -> **S3 Connection** gibt Endpoint + Access/Secret-Key):
```bash
# rclone remotes 'src' und 'dst' als S3 (provider=Other) konfigurieren,
# endpoint = https://<ref>.storage.supabase.co/storage/v1/s3
for b in avatars board-images chat-images chat-voice-messages covers \
         crisis-images event-images event-photos group-images knowledge-images \
         marketplace-images organization-images post-images public voicemails; do
  rclone copy "src:$b" "dst:$b" --transfers=8 --progress
done
```
(Buckets muessen im Ziel existieren -- Phase 1 hat die storage.buckets-Zeilen
schon eingespielt; sonst per Dashboard/SQL anlegen.)

---

## Phase 3 -- Cron-Jobs (20)
`pg_dump` erfasst die `cron`-Tabelle nicht. Exportieren + neu anlegen:
```bash
# pg_cron im Ziel aktivieren (ggf. Dashboard -> Database -> Extensions)
psql "$DST" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"

psql "$SRC" -At -c \
 "SELECT format('SELECT cron.schedule(%L,%L,%L);', jobname, schedule, command) FROM cron.job;" \
 > cron_jobs.sql
psql "$DST" -f cron_jobs.sql
```

---

## Phase 4 -- Edge Functions (7) + Secrets
```bash
cd /pfad/zu/Mensaena
supabase link --project-ref gyqujitkvymlmgroovch
supabase functions deploy backfill-geo delete-user fuel-prices \
  livekit-token notify-call send-email send-push

# Secrets im NEUEN Projekt setzen (Werte aus dem alten Projekt uebernehmen):
supabase secrets set \
  SUPABASE_SERVICE_ROLE_KEY=... \
  GEMINI_API_KEY=... GROQ_API_KEY=... CEREBRAS_API_KEY=... OPENROUTER_API_KEY=... \
  # + alle weiteren: FCM service account, push_webhook_secret, livekit creds, ...
```
Die push_config (FCM-Service-Account, Webhook-Secret) liegt in der `private`-
Schema-Tabelle -- pg_dump hat sie NICHT mit (nur public/auth/storage). Diese
Werte separat aus dem alten Projekt holen und im neuen setzen.

---

## Phase 5 -- App auf gyquj umstellen (Repo)
Projekt-Ref + Anon-Key + URL ueberall ersetzen:

| Alt | Neu |
|---|---|
| `huaqldjkgyosefzfhjnf` (49x im Repo) | `gyqujitkvymlmgroovch` |
| URL `https://huaqldjkgyosefzfhjnf.supabase.co` | `https://gyqujitkvymlmgroovch.supabase.co` |
| alter anon-Key | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5cXVqaXRrdnltbG1ncm9vdmNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NzgwNzMsImV4cCI6MjA5NjI1NDA3M30.hz7uZJJPffFb5DEXKHVtmVaW5d4YzXFE2WtSROwjFxg` |

Betroffen: `flutter_app/lib/...` (Config/main), Web `src/...`, GitHub Secrets
(`SUPABASE_PROJECT_REF` u.a. fuer supabase.yml / flutter.yml). Danach **APK neu
bauen + Web neu deployen**. (Diesen Repo-Teil kann Claude auf einem Branch
vorbereiten -- NICHT auf main mergen vor dem Cutover, sonst zeigt die Live-App
auf die leere DB.)

---

## Phase 6 -- Cutover + Verifikation
1. **Wartungsmodus** auf huaqld: `UPDATE app_settings SET value='true' WHERE key='maintenance_mode';`
2. **Delta-Sync**: Tabellen, die seit Phase 1 geschrieben wurden, data-only
   nachziehen (`pg_dump --data-only -t <tabelle>` -> psql DST).
3. Re-pointete App deployen (Branch aus Phase 5 mergen + Build).
4. **Verifizieren**: Test-Login (echter Nutzer), Daten da, Avatar laedt, Push kommt an, Chat/Realtime laeuft.
5. huaqld **noch ein paar Tage intakt lassen** (Rollback-Anker), erst dann pausieren/loeschen.

## Rollback
huaqld bleibt bis zur finalen Verifikation unberuehrt. Faellt etwas aus:
App-Ref zurueck auf huaqld, redeploy -> alter Zustand.

## Region / GDPR
Daten wandern **DE (eu-central-1) -> IE (eu-west-1)**. Datenschutzerklaerung
anpassen, falls dort der Serverstandort genannt ist.
