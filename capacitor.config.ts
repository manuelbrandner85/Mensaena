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
  android: {
    allowMixedContent: false,
    captureInput: true,
    webContentsDebuggingEnabled: false,
    backgroundColor: '#EEF9F9',
  },
}

export default config
