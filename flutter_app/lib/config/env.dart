/// Environment-Konfiguration.
/// Werte werden zur Build-Zeit per `--dart-define` injiziert (analog zu
/// NEXT_PUBLIC_* in der Web-App). Fallbacks decken Production-URLs ab,
/// damit Dev-Builds direkt laufen.
class Env {
  Env._();

  // ── Supabase (identisch zur Web-App) ─────────────────────────────
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://huaqldjkgyosefzfhjnf.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODcxMTgsImV4cCI6MjA5MDU2MzExOH0.Q5ciM8f--f1xAsKyr9-hv1mz7GGbJ6vbxPe4Cj5mgYE',
  );

  // ── Cloudflare Workers (Next.js API-Routes Proxy) ───────────────
  /// Basis-URL der Live-Site auf Cloudflare Workers. Alle /api/*-Endpoints
  /// laufen weiterhin dort und werden vom Flutter-Client per HTTPS gerufen.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.mensaena.de',
  );

  // ── LiveKit (Voice/Video Calls) ─────────────────────────────────
  /// Token + Room werden per /api/live-room/token vom Backend geholt
  /// (genau wie in der Web-App), kein API-Secret im Client.
  static const livekitWsUrl = String.fromEnvironment(
    'LIVEKIT_WS_URL',
    defaultValue: 'wss://mensaena-livekit.livekit.cloud',
  );

  // ── Drittanbieter-APIs (öffentliche Keys) ───────────────────────
  static const orsApiKey = String.fromEnvironment('ORS_API_KEY', defaultValue: '');
  static const ddbApiKey = String.fromEnvironment('DDB_API_KEY', defaultValue: '');

  // ── App-Metadaten ───────────────────────────────────────────────
  static const appName = 'Mensaena';
  static const appUrl = 'https://www.mensaena.de';
  static const appVersion = '1.0.0-beta';
}
