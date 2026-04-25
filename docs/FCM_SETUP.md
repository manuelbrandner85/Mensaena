# Firebase Cloud Messaging — Komplettsetup

Schritt-für-Schritt-Anleitung um FCM-Push für die Capacitor-APK von Null
einzurichten. Nach diesem Guide funktionieren Push-Benachrichtigungen
auch wenn die App komplett geschlossen ist.

**Voraussetzung**: Du hast einen Google-Account, GitHub-Repo-Zugriff und
Supabase-Dashboard-Zugriff für das Mensaena-Projekt.

---

## Übersicht

| Komponente | Wofür | Liegt | Wer setzt's |
|---|---|---|---|
| `google-services.json` | Client-Config in der APK | Firebase Console + GitHub Secret + android/app/ | Du |
| `serviceAccount.json` | Server-Auth für FCM HTTP v1 API | Firebase Console + Supabase `private.push_config` | Du |
| `fcm_project_id` | Match-Check Server↔Client | Supabase `private.push_config` | Du |
| `send-push` Edge Function | Sendet via FCM HTTP v1 | Supabase Edge Functions | CI / CLI |
| `useCapacitorPush` Hook | Registriert Token nach Login | APK | Auto |
| `notify_push_on_new_notification` Trigger | DB → Edge Function | Supabase Postgres | Migration |

---

## Schritt 1 — Firebase-Projekt anlegen (3 Min)

1. https://console.firebase.google.com öffnen
2. **„Projekt erstellen"**
3. Projektname: `Mensaena` (frei wählbar)
4. Google Analytics: **deaktivieren** (Privacy)
5. Warten bis Projekt erstellt → **„Weiter"**

## Schritt 2 — Android-App hinzufügen

1. Im Projekt-Dashboard das **Android-Roboter-Icon** klicken
2. **Android-Paketname**: `de.mensaena.app` ⚠️ MUSS exakt stimmen
3. App-Alias: beliebig (z.B. „Mensaena")
4. SHA-1: leer lassen
5. **„App registrieren"**
6. **„`google-services.json` herunterladen"** → speichern, du brauchst sie gleich
7. Restliche Schritte überspringen → **„Zur Konsole"**

## Schritt 3 — `google-services.json` als GitHub-Secret

1. https://github.com/manuelbrandner85/Mensaena/settings/secrets/actions
2. Falls vorher schon `GOOGLE_SERVICES_JSON` existiert → **klicken → „Update"** (sonst „New repository secret")
3. **Name**: `GOOGLE_SERVICES_JSON`
4. **Value**: kompletten Inhalt der `google-services.json` reinpasten (mit Editor öffnen, Ctrl+A, Ctrl+C)
5. **„Add/Update secret"**

## Schritt 4 — Service-Account-Schlüssel generieren

1. In Firebase: **⚙️** (Zahnrad) → **„Projekteinstellungen"**
2. Tab **„Dienstkonten"**
3. Sektion „Firebase Admin SDK" → **„Neuen privaten Schlüssel generieren"**
4. Bestätigen → JSON wird heruntergeladen (z.B. `mensaena-edd7b-firebase-adminsdk-xxxxx-abc123.json`)

⚠️ **Diese Datei NICHT** ins Git committen, **NICHT** in Chats posten,
**NICHT** als GitHub-Secret hinterlegen — sie gehört nur in Supabase.

## Schritt 5 — Supabase `push_config` befüllen

1. Service-Account-JSON mit Editor öffnen
2. Den Wert von `"project_id"` (oben in der Datei, z.B. `mensaena-edd7b`) merken
3. https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new
4. Diese SQL einfügen:

```sql
-- Project ID setzen (aus dem JSON kopiert)
INSERT INTO private.push_config (key, value)
  VALUES ('fcm_project_id', 'DEINE_PROJECT_ID_HIER')
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Service Account JSON (kompletten Inhalt zwischen $SA$ und $SA$ pasten)
INSERT INTO private.push_config (key, value)
  VALUES ('fcm_service_account_json', $SA$

PASTE-HIER-DEN-KOMPLETTEN-JSON-INHALT

$SA$)
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Verify
SELECT
  (SELECT value FROM private.push_config WHERE key = 'fcm_project_id') AS pid,
  (SELECT (value::jsonb)->>'type' FROM private.push_config WHERE key = 'fcm_service_account_json') AS sa_type,
  (SELECT (value::jsonb)->>'client_email' FROM private.push_config WHERE key = 'fcm_service_account_json') AS sa_email;
```

5. **„Run"** klicken

Erwartete Ausgabe (eine Zeile):

| pid | sa_type | sa_email |
|---|---|---|
| mensaena-edd7b | service_account | firebase-adminsdk-…@mensaena-edd7b.iam.gserviceaccount.com |

`sa_type` MUSS `service_account` sein. Wenn da `null` oder etwas
anderes steht → falsche JSON gepastet (vermutlich google-services.json
statt service-account JSON).

## Schritt 6 — Edge Function deployen

Wenn du die Supabase-CLI lokal hast:
```bash
npx supabase functions deploy send-push --project-ref huaqldjkgyosefzfhjnf --no-verify-jwt
```

Sonst über das Dashboard:
1. https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/functions/send-push
2. Tab „Code"
3. Inhalt komplett ersetzen mit dem Code aus
   https://raw.githubusercontent.com/manuelbrandner85/Mensaena/main/supabase/functions/send-push/index.ts
4. **„Deploy"**

## Schritt 7 — APK neu bauen

1. https://github.com/manuelbrandner85/Mensaena/actions/workflows/android.yml
2. Rechts oben **„Run workflow"** → **„Run workflow"**
3. ~25 Min warten bis grün

## Schritt 8 — APK auf Handy

1. Alte App **deinstallieren** (Dauerdrücken → Deinstallieren)
2. https://github.com/manuelbrandner85/Mensaena/releases/latest/download/mensaena-release.apk
3. Installieren → öffnen → einloggen
4. Android fragt **„Darf Mensaena Benachrichtigungen senden?"** → **Erlauben**
5. In der App **Einstellungen → Benachrichtigungen** öffnen
6. Oben sollte das **„📱 Push-Status (APK)"** Panel erscheinen mit grünem **✓ Aktiv**

Wenn da `Verweigert` oder `Firebase-Fehler` steht: Fehlerdetails lesen
und entsprechend handeln (Permission im Android aktivieren oder
google-services.json prüfen).

## Schritt 9 — Test-Push

In Supabase SQL Editor:
```sql
INSERT INTO public.notifications (user_id, type, category, title, content, link)
VALUES (
  (SELECT user_id FROM public.fcm_tokens WHERE active ORDER BY last_used DESC LIMIT 1),
  'system', 'system',
  'Test 🎉', 'Push funktioniert!',
  '/dashboard/notifications'
);
```

Vor „Run": **Handy sperren** oder zum Homescreen wischen, sodass die
App nicht im Vordergrund ist.

Nach „Run" sollte das Handy nach 1-3 Sekunden vibrieren und die
Benachrichtigung mit „Test 🎉" + „Push funktioniert!" zeigen — auch
wenn die App geschlossen ist.

---

## Troubleshooting

### Edge Function `fcm_debug`-Output

Bei jedem direkten Aufruf der Edge Function liefert sie ein
`fcm_debug`-Feld im Response, falls FCM nicht geklappt hat:

| Meldung | Ursache |
|---|---|
| `skipped: fcm_project_id empty` | Schritt 5 nicht gemacht oder leer |
| `skipped: fcm_service_account_json empty` | Schritt 5 nicht gemacht oder leer |
| `service-account JSON is not parseable` | JSON kaputt (Anführungszeichen-Mismatch?) |
| `service-account wrong type: "..."` | `google-services.json` statt service-account.json gepastet |
| `service-account missing required fields` | private_key / client_email fehlt |
| `project_id mismatch: ...` | Service-Account ist aus anderem Firebase-Projekt als google-services.json |
| `OAuth2 exchange failed: ...` | Private Key ungültig oder Service-Account widerrufen |
| `HTTP 404: ...UNREGISTERED` | Token gehört zu anderem Firebase-Projekt oder App neu installiert |
| `HTTP 403: ...permission_denied` | Service-Account hat keine FCM-Permission (Firebase-Console-Sache) |

### Token registriert sich nicht (fcm_tokens bleibt leer)

Schau in der App auf **Einstellungen → Benachrichtigungen** ins
Push-Status-Panel. Da steht der genaue Grund (Permission denied,
Firebase-Init-Fehler, DB-RLS-Block, …).

### CI-Build schlägt fehl mit „GOOGLE_SERVICES_JSON missing"

Schritt 3 nochmal prüfen — Secret muss exakt so heißen, kompletter
JSON-Inhalt rein, keine Anführungszeichen drum.

### Pushes kommen aber ohne Body / Titel

Service Worker-Cache. Browser-Tab schließen, zurück zur Site, User
muss kurz warten bis SW aktualisiert ist (oder Hard-Reload).

---

## Sicherheits-Checkliste

- [ ] `service-account.json` wurde nicht in Git committed
- [ ] `service-account.json` wurde nicht in Chat / Slack / Email geteilt
- [ ] Lokale Kopie der Service-Account-JSON kann nach Schritt 5 gelöscht werden
- [ ] Falls Service-Account je geleakt: Firebase Console → ⚙️ → Service accounts → alten Key revoken + neuen generieren + Schritt 5 wiederholen

## Aktuelle Reset-Punkte (Stand wenn du diesen Guide neu durchläufst)

Nach einem `Reset-FCM`-Lauf sind diese Stellen leer und müssen neu befüllt werden:

| Stelle | Wie befüllen |
|---|---|
| `private.push_config.fcm_project_id` | Schritt 5 |
| `private.push_config.fcm_service_account_json` | Schritt 5 |
| GitHub-Secret `GOOGLE_SERVICES_JSON` | Schritt 3 |
| `public.fcm_tokens` (Tabelle) | Wird von der APK automatisch befüllt nach Schritt 8 |
