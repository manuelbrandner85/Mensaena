import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'de.mensaena.app',
  appName: 'Mensaena',
  webDir: 'public',
  server: {
    // WebView lädt die Live-Website – kein Static-Export nötig
    url: 'https://www.mensaena.de',
    cleartext: false,
    // KRITISCH: damit der Capacitor-Bridge auch nach internen Redirects/
    // Subdomain-Wechseln (mensaena.de ↔ www.mensaena.de) verfügbar bleibt.
    // Ohne diese Liste verlässt der WebView den vertrauenswürdigen Origin
    // und window.Capacitor wird nicht injiziert → Plugins fallen still
    // auf die Web-Implementation zurück (z.B. Camera.requestPermissions
    // wirft "Not implemented on web." statt den Android-Dialog zu zeigen).
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
    // Temporär aktiviert um den Capacitor-Bridge-Status auf Geräten via
    // chrome://inspect debuggen zu können (Kamera-Permission-Issue).
    webContentsDebuggingEnabled: true,
    backgroundColor: '#EEF9F9',
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 0,
      launchAutoHide: false,
      backgroundColor: '#EEF9F9',  // matches app background — no jarring flash
      androidSplashResourceName: 'splash',
      androidScaleType: 'CENTER_INSIDE',
      showSpinner: false,
      splashFullScreen: true,
      splashImmersive: true,
    },
    StatusBar: {
      overlaysWebView: true,
      style: 'LIGHT',
      backgroundColor: '#EEF9F9',
    },
    Keyboard: {
      resize: 'body',
      resizeOnFullScreen: false,
    },
    PushNotifications: {
      // Android System-Dialog wird beim ersten register() gezeigt.
      // Android 13+ braucht POST_NOTIFICATIONS permission - cap-plugin
      // setzt die automatisch ins Manifest, Plugin fragt zur Laufzeit an.
      presentationOptions: ['badge', 'sound', 'alert'],
    },
  },
}

export default config
