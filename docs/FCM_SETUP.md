# FCM Push-Notifications Setup – Mensaena

Die Capacitor-APK bekommt Push-Nachrichten auch wenn die App **komplett
geschlossen** ist, via **Firebase Cloud Messaging (FCM)**. Dieser Einrichtungs-
Guide beschreibt die einmaligen Schritte, die manuell gemacht werden müssen –
alles andere im Code läuft automatisch.

---

## Übersicht Architektur

```
┌─────────────┐         ┌─────────────┐         ┌─────────────────┐
│  DB-Trigger │ ──────> │  send-push  │ ──────> │ Web Push / FCM  │
│ notifications│         │ Edge Fn     │         │  → User-Handy   │
└─────────────┘         └─────────────┘         └─────────────────┘
```

* **Web-User** (Browser, PWA): Web Push via VAPID (`push_subscriptions`-Tabelle).
* **APK-User**: FCM via `fcm_tokens`-Tabelle.

Die `send-push` Edge Function sendet an **beide** parallel – ein User auf
Laptop + Handy bekommt die Benachrichtigung an beiden Stellen.

---

## Was du einmalig einrichten musst

### 1. Firebase-Projekt anlegen

1. https://console.firebase.google.com → **„Projekt hinzufügen"**
2. Name: *Mensaena* (beliebig)
3. Google Analytics: **deaktivieren** (privacy-friendly)
4. Projekt erstellen → kurze Wartezeit

### 2. Android-App zum Projekt hinzufügen

1. Im Firebase-Projekt auf **Android-Icon** klicken („App hinzufügen")
2. **Android-Paketname**: `de.mensaena.app` (muss exakt stimmen – steht in
   `capacitor.config.ts` als `appId`)
3. App-Nickname: *Mensaena* (egal)
4. **SHA-1** (optional, brauchst du nicht für reines FCM)
5. **„App registrieren"** → Download **`google-services.json`**

### 3. `google-services.json` als GitHub-Secret hinterlegen

1. GitHub-Repo → **Settings → Secrets and variables → Actions**
2. **New repository secret**:
   * Name: `GOOGLE_SERVICES_JSON`
   * Value: **den kompletten Inhalt** der heruntergeladenen JSON 1:1
     reinkopieren (inklusive geschweifter Klammern)
3. Save

Ohne dieses Secret wird der Android-CI-Build **absichtlich fehlschlagen** mit
einer klaren Fehlermeldung – damit nicht versehentlich eine APK ohne
Push-Support released wird.

### 4. Firebase Service Account für den Server

Der **send-push** Edge Function braucht einen Service Account, um per OAuth2
Zugriffstoken für die FCM HTTP v1 API zu bekommen.

1. Firebase Console → **⚙️ → Project settings → Service accounts**
2. **„Generate new private key"** → `serviceAccount.json` herunterladen
3. **Nicht ins Git committen!** Stattdessen in Supabase eintragen:

   ```sql
   -- In Supabase SQL Editor:
   UPDATE private.push_config
     SET value = '<PROJECT_ID aus dem JSON, z.B. mensaena-12345>'
     WHERE key = 'fcm_project_id';

   UPDATE private.push_config
     SET value = '<KOMPLETTER INHALT der serviceAccount.json als String>'
     WHERE key = 'fcm_service_account_json';
   ```

   Tip: die JSON einmal mit `SELECT convert_from(decode(your_json,'escape'),'UTF8')`
   testweise parsen zum Sanity-Check.

### 5. Deploy

* **Push auf main** → CI baut APK mit FCM-Support.
* **Supabase migrieren**: `supabase db push` (oder SQL-Editor) – applied die
  neue Migration `20260424190000_fcm_tokens.sql`.
* **Edge Function deployen**: `supabase functions deploy send-push`.

### 6. Test

1. Neue APK installieren.
2. Einloggen.
3. Android fragt nach „Darf Mensaena Benachrichtigungen senden?" → **Erlauben**.
4. Test-Insert in Supabase:
   ```sql
   INSERT INTO notifications (user_id, title, body, category)
     VALUES ('<deine user_id>', 'Test', 'Hallo vom Server', 'system');
   ```
5. Handy zeigt Notification im Lockscreen / Benachrichtigungsbereich – auch
   wenn die App geschlossen ist.

---

## Was automatisch passiert (keine Arbeit für dich)

* `@capacitor/push-notifications` Plugin ist in `package.json` installiert.
* `capacitor.config.ts` hat `PushNotifications`-Block konfiguriert.
* `src/hooks/useCapacitorPush.ts` registriert Token nach Login automatisch.
* `src/components/native/CapacitorPushBridge.tsx` mountet den Hook im
  Root-Layout, sodass er überall greift, wo der User eingeloggt ist.
* DB-Migration `20260424190000_fcm_tokens.sql` erzeugt `fcm_tokens`-Tabelle
  und RLS-Policies.
* `supabase/functions/send-push/index.ts` schickt an Web Push UND FCM parallel.
* `.github/workflows/android.yml` injiziert `google-services.json` aus dem
  Secret vor dem Gradle-Build.

---

## Troubleshooting

### CI-Fehler: „GOOGLE_SERVICES_JSON secret fehlt"

Du hast Schritt 3 noch nicht gemacht. Secret setzen, Workflow rerunnen.

### APK installiert, aber keine Permission-Abfrage

* Android 13+ braucht `POST_NOTIFICATIONS` Laufzeit-Permission. Das Capacitor-Plugin fragt automatisch an.
* In den Handy-Einstellungen → App-Info → Benachrichtigungen prüfen.

### Permission erteilt, aber kein Token in `fcm_tokens`

* Im Browser-DevTools-Log (`adb logcat -s Capacitor`) gucken ob `registration`-Event gefeuert hat.
* Oft Problem: `google-services.json` gehört zur **falschen Package-ID**.
  `de.mensaena.app` muss exakt match.

### FCM-Request schlägt mit 401 fehl

* Service Account JSON in `push_config` ist ungültig oder Scope fehlt.
* Private Key muss PEM-Format haben (`-----BEGIN PRIVATE KEY-----` etc.).
* Cache kann stale sein: Edge Function neu deployen erzwingt Cold Start.

### FCM liefert `UNREGISTERED` / 404

* User hat die App deinstalliert oder Benachrichtigungen blockiert.
* Die `send-push` Function markiert das Token automatisch als `active = false`.
