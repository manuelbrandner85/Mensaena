import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'de.mensaena.app',
  appName: 'Mensaena',
  // public/ always exists; at runtime the server.url below takes precedence
  webDir: 'public',
  server: {
    // The WebView loads the live website — no static export needed.
    // All SSR, API routes and Supabase calls work identically to web.
    url: 'https://www.mensaena.de',
    cleartext: false,
  },
  // User-Agent-Suffix, damit Server/Client "native" erkennen können
  // (z.B. "Mozilla/5.0 … MensaenaApp/1.0").
  appendUserAgent: 'MensaenaApp/1.0',
  android: {
    allowMixedContent: false,
    captureInput: true,
    webContentsDebuggingEnabled: false,
    backgroundColor: '#EEF9F9',
  },
  plugins: {
    StatusBar: {
      // Overlays WebView: Inhalt kann hinter die Statusbar laufen
      // (safe-area-inset-top im CSS kompensiert das)
      overlaysWebView: true,
      style: 'LIGHT',
      backgroundColor: '#EEF9F9',
    },
    Keyboard: {
      // Kein Resize der WebView -> Eingabefelder scrollen selbst in den sichtbaren Bereich
      resize: 'body',
      resizeOnFullScreen: true,
    },
  },
}

export default config
