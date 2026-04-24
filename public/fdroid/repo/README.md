# F-Droid Repository Index

**Diese Dateien werden von der CI (`.github/workflows/android.yml`) generiert.
Nicht von Hand bearbeiten!**

- Der Index (`index-v1.jar`, `entry.json`, etc.) wird von der F-Droid-App
  gelesen, wenn das Repo `https://www.mensaena.de/fdroid/repo` hinzugefügt wird.
- APK-Downloads (`de.mensaena.app_*.apk`) werden per Next.js-Redirect
  auf die entsprechende GitHub-Release-URL umgeleitet
  (`releases/latest/download/mensaena-release.apk`).

Der Fingerprint des Signing-Keys muss in `src/lib/app-download.ts`
(Konstante `FDROID_FINGERPRINT`) übereinstimmen.
