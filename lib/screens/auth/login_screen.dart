import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  int _secondsLeft = 0;
  Timer? _lockoutTimer;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _secondsLeft = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _lockoutUntil = null;
          _error = null;
        });
      } else {
        setState(() {
          _secondsLeft = remaining;
          _error = 'Zu viele Versuche. Bitte warte noch ${remaining}s.';
        });
      }
    });
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLockedOut) {
      setState(() => _error = 'Zu viele Versuche. Bitte warte noch ${_secondsLeft}s.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref.read(authServiceProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (response.session == null) {
        setState(() => _error = 'Anmeldung fehlgeschlagen. Bitte überprüfe deine Eingaben.');
      }
    } on AuthException {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        _failedAttempts = 0;
        _startLockoutCountdown();
      } else {
        setState(() => _error = 'Anmeldung fehlgeschlagen. Bitte überprüfe deine Eingaben.');
      }
    } catch (_) {
      setState(() => _error = 'Anmeldung fehlgeschlagen. Bitte überprüfe deine Eingaben.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Meta-Label
                const Text(
                  'COMMUNITY PLATTFORM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/mensaena-logo.png',
                    width: 120,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mensaena',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary500,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Willkommen zurück',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Melde dich an, um deiner Nachbarschaft zu helfen',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-Mail',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte E-Mail eingeben';
                          }
                          if (!value.contains('@')) {
                            return 'Ungültige E-Mail-Adresse';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte Passwort eingeben';
                          }
                          return null;
                        },
                      ),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              context.push('/auth/forgot-password'),
                          child: const Text('Passwort vergessen?'),
                        ),
                      ),

                      // Error
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.emergencyLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_loading || _isLockedOut) ? null : _signIn,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Anmelden'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Noch kein Konto? ',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    TextButton(
                      onPressed: () => context.push('/auth/register'),
                      child: const Text('Registrieren'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
