import 'package:supabase_flutter/supabase_flutter.dart';

/// Schmaler Wrapper um den bereits initialisierten Supabase-Client.
/// Die eigentliche `Supabase.initialize()` passiert in main.dart via
/// `lib/core/supabase.dart` — diese Klasse bietet nur typisierte Accessors.
class SupabaseService {
  const SupabaseService();

  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;
  User? get currentUser => client.auth.currentUser;
  String? get userId => currentUser?.id;
  bool get isAuthenticated => currentUser != null;
}

const supabase = SupabaseService();
