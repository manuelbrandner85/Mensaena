import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Auth-Methoden gekapselt, identisch zu den Web-Flows.
/// Wirft StringFehler nach oben — UI faengt sie und zeigt CinemaToast error.
class AuthService {
  const AuthService();

  GoTrueClient get _auth => supabase.auth;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _auth.signUp(
      email: email.trim(),
      password: password,
      data: fullName != null && fullName.isNotEmpty ? {'full_name': fullName} : null,
    );
  }

  /// Magic-Link / Passwordless Login. Supabase verschickt E-Mail mit Token.
  Future<void> signInWithMagicLink(String email) {
    return _auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: 'https://www.mensaena.de/auth/callback',
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'https://www.mensaena.de/auth/reset',
    );
  }

  Future<UserResponse> updatePassword(String newPassword) {
    return _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() => _auth.signOut();

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
}

const authService = AuthService();
