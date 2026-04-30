import type { CapacitorConfig } from '@capacitor/cli'

// UPDATE-SYSTEM: Capacitor-Konfiguration – App lädt Live-Website via server.url.
// webDir 'out' ist für lokale cap:build-Entwicklung (CAPACITOR_BUILD=true).
// CI-Workflow erstellt out/index.html als Platzhalter für cap sync.
const config: CapacitorConfig = {
  appId: 'de.mensaena.app',
  appName: 'Mensaena',
  webDir: 'out',
  server: {
    // Live-Website wird geladen – Capacitor-Bridge via allowNavigation aktiv.
    // Für lokalen APK-Bundle-Build: server.url entfernen + npm run cap:build ausführen.
    url: 'https://www.mensaena.de',
    androidScheme: 'https',
    hostname: 'app.mensaena.de',
    cleartext: false,
    allowNavigation: [
      'www.mensaena.de',
      'mensaena.de',
      '*.mensaena.de',
    ],
  },
  appendUserAgent: 'MensaenaApp/1.0',
  android: {
    allowMixedContent: false,
    captureInput: true,
    webContentsDebuggingEnabled: true,
    backgroundColor: '#EEF9F9',
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 1500,
      launchAutoHide: true,
      backgroundColor: '#EEF9F9',
      androidSplashResourceName: 'splash',
      androidScaleType: 'CENTER_CROP',
      showSpinner: false,
      splashFullScreen: true,
      splashImmersive: true,
    },
    StatusBar: {
      overlaysWebView: true,
      style: 'LIGHT',
      backgroundColor: '#1EAAA6',
    },
    Keyboard: {
      resize: 'body',
      resizeOnFullScreen: true,
    },
    PushNotifications: {
      presentationOptions: ['badge', 'sound', 'alert'],
    },
  },
}

export default config
