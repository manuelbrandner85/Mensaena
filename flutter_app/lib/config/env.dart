/// SKILL: mensaena-architektur
/// Verbindungsdaten via --dart-define oder Default (Live-Werte).
/// SUPABASE_ANON_KEY ist absichtlich öffentlich (durch RLS gesichert).
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gyqujitkvymlmgroovch.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5cXVqaXRrdnltbG1ncm9vdmNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NzgwNzMsImV4cCI6MjA5NjI1NDA3M30.hz7uZJJPffFb5DEXKHVtmVaW5d4YzXFE2WtSROwjFxg',
  );

  static const String supabaseProjectId = 'gyqujitkvymlmgroovch';

  static const String appUrl = String.fromEnvironment(
    'APP_URL',
    defaultValue: 'https://www.mensaena.de',
  );

  static const String livekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://livekit.mensaena.de',
  );

  /// LiveKit API-Key wird im Client zum JWT-Signing benutzt (Anon-Variante:
  /// nur fuer Dev-Builds; in Prod sollte Token vom Server kommen).
  static const String livekitApiKey = String.fromEnvironment(
    'LIVEKIT_API_KEY',
    defaultValue: '',
  );

  static const String livekitApiSecret = String.fromEnvironment(
    'LIVEKIT_API_SECRET',
    defaultValue: '',
  );

  static const String orsApiKey = String.fromEnvironment(
    'ORS_API_KEY',
    defaultValue: '',
  );

  static const String ninaPrimary = String.fromEnvironment(
    'NINA_API_PRIMARY',
    defaultValue: 'https://nina.api.proxy.bund.dev/api31',
  );

  static const String ninaFallback = String.fromEnvironment(
    'NINA_API_FALLBACK',
    defaultValue: 'https://warnung.bund.de/api31',
  );

  static const String appIdAndroid = 'de.mensaena.app';
}
