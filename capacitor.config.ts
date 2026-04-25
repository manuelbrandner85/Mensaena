import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'de.mensaena.app',
  appName: 'Mensaena',
  webDir: 'public',
  server: {
    // WebView lädt die Live-Website – kein Static-Export nötig
    url: 'https://www.mensaena.de',
    cleartext: false,
  },
  appendUserAgent: 'MensaenaApp/1.0',
  android: {
    allowMixedContent: false,
    captureInput: true,
    webContentsDebuggingEnabled: false,
    backgroundColor: '#EEF9F9',
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 4500,
      launchAutoHide: false,       // wir blenden manuell aus (nach Seitenload)
      backgroundColor: '#0a1420',  // dunkler Hintergrund wie das Logo
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
      resizeOnFullScreen: true,
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
