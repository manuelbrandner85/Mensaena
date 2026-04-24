// Zentrale Konstanten für den App-Download-Flow.
// Wird von AppInstallLink, AppDownloadStatusModal und /app/page.tsx genutzt.

export const APK_URL =
  'https://github.com/manuelbrandner85/Mensaena/releases/latest/download/mensaena-release.apk'

export const APK_FILENAME = 'mensaena-release.apk'

export const FDROID_DEEPLINK =
  'fdroidrepos://manuelbrandner85.github.io/Mensaena/repo' +
  '?fingerprint=C68487D0CF0F084959A01484326F04CEC541BB2E1B86D8171AA0F474356389F3'

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
