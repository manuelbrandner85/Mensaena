import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';

/// 1:1-Port von /auth (src/app/auth/page.tsx).
///
/// Modes: login | register | forgot | reset.
/// Logik wie Web: signInWithPassword (lowercased email), signUp mit
/// full_name in user_metadata, resetPasswordForEmail, updateUser für Reset.
/// Welcome-Email + Referral-Accept genauso wie im Web.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, this.mode = 'login', this.referralCode});
  final String mode;
  final String? referralCode;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  late String _mode = widget.mode;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _showPassword = false;
  bool _agreed = false;
  bool _loading = false;
  bool _resetSent = false;
  String? _error;
  String? _info;

  // Rate limit (5 fails → 30s lock, identisch zum Web)
  int _failCount = 0;
  DateTime? _lockUntil;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  bool get _isLogin => _mode == 'login';
  bool get _isRegister => _mode == 'register';
  bool get _isForgot => _mode == 'forgot';
  bool get _isReset => _mode == 'reset';

  // Password-Strength wie im Web (3 Checks)
  bool get _pwLen => _password.text.length >= 8;
  bool get _pwCase => RegExp(r'[a-z]').hasMatch(_password.text) &&
      RegExp(r'[A-Z]').hasMatch(_password.text);
  bool get _pwDigit => RegExp(r'\d').hasMatch(_password.text);
  bool get _pwOk => _pwLen && _pwCase && _pwDigit;
  int get _pwScore =>
      (_pwLen ? 1 : 0) +
      (RegExp(r'[A-Z]').hasMatch(_password.text) ? 1 : 0) +
      (RegExp(r'[a-z]').hasMatch(_password.text) ? 1 : 0) +
      (_pwDigit ? 1 : 0);

  String _normalizedEmail() => _email.text.toLowerCase().trim();

  void _switchMode(String next) {
    setState(() {
      _mode = next;
      _error = null;
      _info = null;
      _password.clear();
      _passwordConfirm.clear();
      _resetSent = false;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_isLogin) return _handleLogin();
    if (_isRegister) return _handleRegister();
    if (_isForgot) return _handleForgot();
    if (_isReset) return _handleReset();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lockUntil != null && DateTime.now().isBefore(_lockUntil!)) {
      final s = _lockUntil!.difference(DateTime.now()).inSeconds;
      setState(() => _error = 'Zu viele Versuche. Bitte $s Sekunden warten.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await sb.auth.signInWithPassword(
        email: _normalizedEmail(),
        password: _password.text,
      );
      if (!mounted) return;
      if (res.session != null) {
        HapticFeedback.lightImpact();
        context.go(Routes.dashboard);
      } else {
        setState(() => _error = 'Anmeldung fehlgeschlagen.');
      }
    } on AuthException catch (e) {
      _failCount += 1;
      if (_failCount >= 5) {
        _lockUntil = DateTime.now().add(const Duration(seconds: 30));
        setState(() => _error =
            'Zu viele Versuche. Bitte 30 Sekunden warten und erneut versuchen.');
      } else {
        setState(() => _error = _germanErrorFor(e));
      }
    } catch (e) {
      setState(() => _error = 'Unerwarteter Fehler: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _error =
          'Bitte AGB und Datenschutzerklärung akzeptieren, um fortzufahren.');
      return;
    }
    if (!_pwOk) {
      setState(() => _error =
          'Passwort muss min. 8 Zeichen, Groß-/Kleinbuchstaben und eine Ziffer enthalten.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await sb.auth.signUp(
        email: _normalizedEmail(),
        password: _password.text,
        // emailRedirectTo: HTTPS-URL der Web-App (genau wie Web).
        // Mobile öffnet den Link im Browser – nach Bestätigung kann der
        // User in der Flutter-App per Email/Passwort einloggen.
        emailRedirectTo: 'https://www.mensaena.de/auth?mode=login',
        data: <String, dynamic>{'full_name': _name.text.trim()},
      );
      if (!mounted) return;
      final newUser = res.user;
      // Welcome-Email triggern (best-effort, identisch zum Web)
      if (newUser != null) {
        unawaited(_triggerWelcomeEmail(
          userId: newUser.id,
          email: _normalizedEmail(),
          name: _name.text.trim(),
        ));
      }
      // Referral-Code akzeptieren (per ?ref=… in der URL, wie Web)
      if (widget.referralCode != null && newUser != null) {
        try {
          await sb.rpc<dynamic>(
            'accept_referral',
            params: <String, dynamic>{
              'p_invite_code': widget.referralCode,
              'p_invitee_id': newUser.id,
            },
          );
        } catch (_) {
          // Best-effort: ignore
        }
      }
      if (res.session != null) {
        HapticFeedback.lightImpact();
        context.go(Routes.dashboard);
        return;
      }
      // Kein Session zurück → E-Mail-Confirm aktiv
      setState(() {
        _info = 'Bitte prüfe deine E-Mails und bestätige dein Konto.';
        _password.clear();
      });
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        setState(() => _error =
            'Diese E-Mail-Adresse ist bereits registriert. Bitte einloggen.');
      } else {
        setState(() => _error = _germanErrorFor(e));
      }
    } catch (e) {
      setState(() => _error = 'Unerwarteter Fehler: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForgot() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await sb.auth.resetPasswordForEmail(
        _normalizedEmail(),
        redirectTo: 'https://www.mensaena.de/auth?mode=reset',
      );
      if (!mounted) return;
      setState(() {
        _resetSent = true;
        _info = 'Falls die E-Mail registriert ist, wurde ein Link verschickt.';
      });
    } on AuthException catch (e) {
      setState(() => _error = _germanErrorFor(e));
    } catch (e) {
      setState(() => _error = 'Unerwarteter Fehler: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_pwOk) {
      setState(() => _error =
          'Passwort muss min. 8 Zeichen, Groß-/Kleinbuchstaben und eine Ziffer enthalten.');
      return;
    }
    if (_password.text != _passwordConfirm.text) {
      setState(() => _error = 'Passwörter stimmen nicht überein.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await sb.auth.updateUser(UserAttributes(password: _password.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort aktualisiert. Bitte anmelden.')),
      );
      await sb.auth.signOut();
      _switchMode('login');
    } on AuthException catch (e) {
      setState(() => _error = _germanErrorFor(e));
    } catch (e) {
      setState(() => _error = 'Unerwarteter Fehler: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _triggerWelcomeEmail({
    required String userId,
    required String email,
    required String name,
  }) async {
    try {
      await ref.read(apiClientProvider).post<void>(
            '/api/emails/welcome',
            body: <String, dynamic>{
              'userId': userId,
              'email': email,
              'name': name,
            },
          );
    } catch (_) {
      // best-effort, identisch zum Web
    }
  }

  String _germanErrorFor(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials') ||
        m.contains('invalid email or password')) {
      return 'Falsche E-Mail oder falsches Passwort.';
    }
    if (m.contains('email not confirmed')) {
      return 'Bitte bestätige zuerst deine E-Mail-Adresse (Postfach prüfen).';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Zu viele Anfragen – bitte kurz warten.';
    }
    return e.message;
  }

  // ─── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AppCard(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(mode: _mode),
                      const SizedBox(height: 24),
                      if (!_isReset && !_isForgot) _modeSwitcher(),
                      if (!_isReset && !_isForgot) const SizedBox(height: 20),
                      if (_isRegister) ...[
                        _label('Name'),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Wie heißt du?',
                            prefixIcon: Icon(Icons.person_outline, size: 18),
                          ),
                          validator: (v) =>
                              (v ?? '').trim().length < 2 ? 'Bitte Name angeben' : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (!_isReset) ...[
                        _label('E-Mail'),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            hintText: 'du@example.de',
                            prefixIcon: Icon(Icons.mail_outline, size: 18),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'E-Mail erforderlich';
                            if (!v.contains('@') || !v.contains('.')) return 'Ungültige E-Mail';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (!_isForgot) ...[
                        _label(_isReset ? 'Neues Passwort' : 'Passwort'),
                        TextFormField(
                          controller: _password,
                          obscureText: !_showPassword,
                          textInputAction: _isRegister || _isReset
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: _isLogin
                                ? 'Dein Passwort'
                                : 'Mind. 8 Zeichen, Groß/Klein, Ziffer',
                            prefixIcon: const Icon(Icons.lock_outline, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Passwort erforderlich';
                            if (_isLogin && v.length < 6) return 'Mindestens 6 Zeichen';
                            return null;
                          },
                        ),
                        if ((_isRegister || _isReset) && _password.text.isNotEmpty)
                          _PasswordStrength(
                            score: _pwScore,
                            checks: [
                              ('Min. 8 Zeichen', _pwLen),
                              ('Groß- & Kleinbuchstaben', _pwCase),
                              ('Mind. eine Ziffer', _pwDigit),
                            ],
                          ),
                        const SizedBox(height: 14),
                      ],
                      if (_isReset) ...[
                        _label('Passwort wiederholen'),
                        TextFormField(
                          controller: _passwordConfirm,
                          obscureText: !_showPassword,
                          decoration: const InputDecoration(
                            hintText: 'Bitte erneut eingeben',
                            prefixIcon: Icon(Icons.lock_outline, size: 18),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : () => _switchMode('forgot'),
                            child: const Text('Passwort vergessen?'),
                          ),
                        ),
                      if (_isRegister)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _agreed,
                                onChanged: (v) => setState(() => _agreed = v ?? false),
                              ),
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Ich akzeptiere die AGB und Datenschutzerklärung.',
                                    style: TextStyle(fontSize: 12, height: 1.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        _Banner(text: _error!, isError: true),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 8),
                        _Banner(text: _info!, isError: false),
                      ],
                      const SizedBox(height: 16),
                      BtnPrimary(
                        onPressed: _loading || (_isForgot && _resetSent) ? null : _submit,
                        label: _loading
                            ? 'Wird bearbeitet…'
                            : (_isLogin
                                ? 'Anmelden'
                                : _isRegister
                                    ? 'Registrieren'
                                    : _isForgot
                                        ? (_resetSent ? 'Link gesendet' : 'Link senden')
                                        : 'Passwort speichern'),
                        fullWidth: true,
                        size: BtnSize.large,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _loading
                              ? null
                              : () => _switchMode(_isLogin || _isForgot ? 'register' : 'login'),
                          child: Text(
                            _isLogin
                                ? 'Noch kein Konto? Jetzt registrieren'
                                : _isForgot
                                    ? 'Zurück zur Anmeldung'
                                    : 'Schon ein Konto? Anmelden',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.ink400,
          ),
        ),
      );

  Widget _modeSwitcher() {
    Widget tab(String value, String label) {
      final selected = _mode == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => _switchMode(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.paper : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: selected ? AppColors.primary700 : AppColors.ink500,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.stone100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          tab('login', 'Anmelden'),
          tab('register', 'Registrieren'),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      'register' => 'Konto erstellen',
      'forgot' => 'Passwort vergessen',
      'reset' => 'Neues Passwort setzen',
      _ => 'Willkommen zurück',
    };
    final subtitle = switch (mode) {
      'register' =>
        'Werde Teil der Mensaena-Community – Hilfe in deiner Nachbarschaft.',
      'forgot' =>
        'Trage deine E-Mail ein. Wir senden dir einen Link zum Zurücksetzen.',
      'reset' => 'Wähle ein neues, sicheres Passwort.',
      _ => 'Schön, dass du wieder da bist.',
    };

    return Column(
      children: [
        Text(
          'Mensaena',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.ink400),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: isError ? const Color(0xFFB91C1C) : const Color(0xFF065F46),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isError ? const Color(0xFFB91C1C) : const Color(0xFF065F46),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.score, required this.checks});
  final int score;
  final List<(String, bool)> checks;

  Color get _scoreColor {
    if (score <= 1) return const Color(0xFFC62828);
    if (score <= 2) return const Color(0xFFF59E0B);
    if (score <= 3) return AppColors.primary500;
    return const Color(0xFF059669);
  }

  String get _scoreLabel {
    if (score <= 1) return 'Schwach';
    if (score <= 2) return 'OK';
    if (score <= 3) return 'Gut';
    return 'Stark';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: score / 4,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: _scoreColor,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _scoreLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _scoreColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...checks.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 12,
                    color: c.$2 ? AppColors.primary500 : const Color(0xFFD1D5DB),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.$1,
                    style: TextStyle(
                      fontSize: 11,
                      color: c.$2 ? AppColors.primary700 : AppColors.ink400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

