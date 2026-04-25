// Zentrale Konstanten für den App-Download-Flow.
// Wird von AppInstallLink, AppDownloadStatusModal, AppDownloadSection und /app/page.tsx genutzt.

// ── Master-Schalter ──────────────────────────────────────────────────────
// Auf `false` setzen um die komplette APK-Download-UI auf der Website zu
// verstecken (Hero-Button, Navbar-Eintrag, Footer-Link, AppDownloadSection,
// FloatingAppButton, /app-Route → redirected zu /).
// In der Capacitor-APK selbst hat diese Konstante keine Bedeutung – die
// CTAs sind dort sowieso via .cta-app-download CSS-Klasse versteckt.
export const APK_DOWNLOAD_ENABLED = false

export const APK_URL =
  'https://github.com/manuelbrandner85/Mensaena/releases/latest/download/mensaena-release.apk'

export const APK_FILENAME = 'mensaena-release.apk'

// ─── Self-hosted F-Droid Repository ──────────────────────────────────────────
// Das eigene F-Droid-Repo liegt unter https://www.mensaena.de/fdroid/repo
// Fingerprint prüfen mit:
//   keytool -printcert -jarfile <signed.apk> | grep SHA256
// oder via fdroidserver:
//   fdroid -v | grep fingerprint
export const FDROID_REPO_DOMAIN = 'www.mensaena.de'
export const FDROID_REPO_PATH   = '/fdroid/repo'
export const FDROID_FINGERPRINT = 'C68487D0CF0F084959A01484326F04CEC541BB2E1B86D8171AA0F474356389F3'
export const FDROID_APP_ID      = 'de.mensaena.app'

// fdroidrepos://-Deeplink: F-Droid-App öffnet bei Klick automatisch
// den "Repo hinzufügen"-Dialog mit vorausgefüllten Feldern.
export const FDROID_DEEPLINK =
  `fdroidrepos://${FDROID_REPO_DOMAIN}${FDROID_REPO_PATH}` +
  `?fingerprint=${FDROID_FINGERPRINT}`

// HTTPS-Fallback (z.B. für Browser ohne F-Droid-Intent-Handler)
export const FDROID_HTTPS_URL =
  `https://${FDROID_REPO_DOMAIN}${FDROID_REPO_PATH}` +
  `?fingerprint=${FDROID_FINGERPRINT}`

// QR-Code-Inhalt in ALL-CAPS (kompakterer QR, F-Droid unterstützt case-insensitive URLs)
// QR-Code generieren:
//   qrencode -o public/images/mensaena-fdroid-qr.png -s 8 -l H \
//     "FDROIDREPOS://WWW.MENSAENA.DE/FDROID/REPO?FINGERPRINT=DEIN_FINGERPRINT"
export const FDROID_QR_CONTENT =
  `FDROIDREPOS://${FDROID_REPO_DOMAIN.toUpperCase()}${FDROID_REPO_PATH.toUpperCase()}` +
  `?FINGERPRINT=${FDROID_FINGERPRINT}`

// URL zum F-Droid-Client APK (Fallback: User muss F-Droid erst installieren)
export const FDROID_CLIENT_APK_URL = 'https://f-droid.org/F-Droid.apk'

// Rotierende motivierende Sätze im Download-Status-Modal.
// Alle ~3 Sekunden wechselt der angezeigte Satz.
export const MOTIVATIONAL_MESSAGES: readonly string[] = [
  'Du machst jetzt was Gutes für deine Nachbarschaft 💚',
  'Gleich ist es geschafft – danke, dass du mitmachst',
  'Mensaena verbindet Nachbarn, die sich sonst nie kennen würden',
  'Kleine Hilfe, großer Unterschied – bald am Handy',
  'Deine Community wartet schon auf dich',
  'Open Source, keine Tracker – deine Daten bleiben bei dir',
  'Jeder Nachbar zählt. Auch du.',
  'Zusammen sind wir stärker als jede Krise',
  'Ein Tipp weiter – und Hilfe ist da, wenn sie gebraucht wird',
]
