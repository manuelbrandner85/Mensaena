import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

enum _AuthMode { login, register, forgot, magic }

/// SKILL: supabase
/// 1:1 zu `src/app/auth/page.tsx`. Modi: login / register / forgot / magic.
/// Features: Passwort-Anforderungen-Check (≥8 Zeichen, Klein+Gross, Zahl),
/// Stärke-Indikator (0-4), Name-Feld bei Registrierung, Referral-Code
/// aus Query-Param, Forgot-Password-Reset, Magic-Link (passwortlos).
class AuthScreen extends StatefulWidget {
  const AuthScreen({this.mode = 'login', super.key});

  final String mode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late _AuthMode _mode;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _mode = switch (widget.mode) {
      'register' => _AuthMode.register,
      'forgot' => _AuthMode.forgot,
      'magic' => _AuthMode.magic,
      _ => _AuthMode.login,
    };
    _passwordCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────────────────
  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'E-Mail fehlt.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
      return 'Ungültige E-Mail.';
    }
    return null;
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.length < 2) return 'Mindestens 2 Zeichen.';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'Mindestens 8 Zeichen.';
    return null;
  }

  // ── Password strength ──────────────────────────────────────────────
  List<({String label, bool ok})> get _checks {
    final p = _passwordCtrl.text;
    return [
      (label: 'Mindestens 8 Zeichen', ok: p.length >= 8),
      (
        label: 'Großbuchstabe + Kleinbuchstabe',
        ok: RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p),
      ),
      (label: 'Mindestens eine Zahl', ok: RegExp(r'\d').hasMatch(p)),
    ];
  }

  int get _pwScore {
    final p = _passwordCtrl.text;
    if (p.isEmpty) return 0;
    var s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    return s;
  }

  // ── Actions ─────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mode == _AuthMode.register && !_checks.every((c) => c.ok)) {
      setState(() => _error =
          'Passwort erfüllt nicht alle Anforderungen.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      switch (_mode) {
        case _AuthMode.login:
          await sb.auth.signInWithPassword(
            email: _emailCtrl.text.trim().toLowerCase(),
            password: _passwordCtrl.text,
          );
          if (!mounted) return;
          context.go('/dashboard');
          return;
        case _AuthMode.register:
          // Referral-Code BEVOR async aus Query-Param holen.
          final refCode = mounted
              ? GoRouterState.of(context).uri.queryParameters['ref']
              : null;
          final res = await sb.auth.signUp(
            email: _emailCtrl.text.trim().toLowerCase(),
            password: _passwordCtrl.text,
            data: {'full_name': _nameCtrl.text.trim()},
            emailRedirectTo: 'https://www.mensaena.de/auth?mode=login',
          );
          if (refCode != null && res.user?.id != null) {
            try {
              await sb.rpc<dynamic>('accept_referral', params: {
                'p_invite_code': refCode,
                'p_invitee_id': res.user!.id,
              });
            } catch (_) {}
          }
          if (res.session != null) {
            if (!mounted) return;
            context.go('/dashboard');
            return;
          }
          setState(() => _info =
              'Konto erstellt. Prüfe deine E-Mails zur Bestätigung.');
          break;
        case _AuthMode.forgot:
          await sb.auth.resetPasswordForEmail(
            _emailCtrl.text.trim().toLowerCase(),
            redirectTo: 'https://www.mensaena.de/auth?mode=reset',
          );
          setState(() => _info =
              'Wir haben dir einen Reset-Link geschickt. Prüfe dein Postfach.');
          break;
        case _AuthMode.magic:
          await sb.auth.signInWithOtp(
            email: _emailCtrl.text.trim().toLowerCase(),
            emailRedirectTo: 'https://www.mensaena.de/dashboard',
          );
          setState(() => _info =
              'Magic-Link gesendet. Öffne deine E-Mail.');
          break;
      }
    } catch (e) {
      setState(() {
        var msg = e.toString().replaceFirst('AuthApiException: ', '');
        if (msg.contains('already registered') ||
            msg.contains('User already')) {
          msg = 'Diese E-Mail ist bereits registriert.';
        } else if (msg.contains('Invalid login')) {
          msg = 'Falsche E-Mail oder Passwort.';
        }
        _error = msg;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == _AuthMode.register;
    final isForgot = _mode == _AuthMode.forgot;
    final isMagic = _mode == _AuthMode.magic;

    String title;
    String submitLabel;
    switch (_mode) {
      case _AuthMode.login:
        title = 'Anmelden';
        submitLabel = 'Anmelden';
        break;
      case _AuthMode.register:
        title = 'Registrieren';
        submitLabel = 'Konto erstellen';
        break;
      case _AuthMode.forgot:
        title = 'Passwort zurücksetzen';
        submitLabel = 'Reset-Link senden';
        break;
      case _AuthMode.magic:
        title = 'Magic-Link';
        submitLabel = 'Link senden';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(title, style: AppTypography.appBarTitle()),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroLogo(),
                    const SizedBox(height: 18),
                    Text(
                      isRegister
                          ? 'Willkommen in der Nachbarschaft.'
                          : isForgot
                              ? 'Passwort vergessen?'
                              : isMagic
                                  ? 'Login ohne Passwort.'
                                  : 'Willkommen zurück.',
                      style: AppTypography.display(size: 28, height: 1.15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRegister
                          ? 'Trag dich ein — wir helfen dir nicht mit Werbung, sondern mit echten Nachbarn.'
                          : isForgot
                              ? 'Wir senden dir einen Reset-Link per E-Mail.'
                              : isMagic
                                  ? 'Nur deine E-Mail — keine Passwörter.'
                                  : 'Schön, dass du wieder da bist.',
                      style: AppTypography.body(
                          size: 13, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 28),

                    // Name nur bei Registrierung
                    if (isRegister) ...[
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        validator: _validateName,
                        style: AppTypography.body(color: AppColors.ink),
                        decoration: const InputDecoration(
                          labelText: 'Name (sichtbar für Nachbarn)',
                          prefixIcon: Icon(LucideIcons.user, size: 16),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _validateEmail,
                      style: AppTypography.body(color: AppColors.ink),
                      decoration: const InputDecoration(
                        labelText: 'E-Mail',
                        prefixIcon: Icon(LucideIcons.mail, size: 16),
                      ),
                    ),

                    if (!isForgot && !isMagic) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        validator: _validatePassword,
                        style: AppTypography.body(color: AppColors.ink),
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          prefixIcon:
                              const Icon(LucideIcons.lock, size: 16),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              size: 16,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      if (isRegister && _passwordCtrl.text.isNotEmpty)
                        _PasswordStrength(
                          score: _pwScore,
                          checks: _checks,
                        ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _Banner(text: _error!, isError: true),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 14),
                      _Banner(text: _info!),
                    ],

                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.voidColor,
                              ),
                            )
                          : Text(submitLabel),
                    ),

                    const SizedBox(height: 16),

                    // ── Mode-Switch-Buttons ────────────────────
                    if (_mode == _AuthMode.login) ...[
                      TextButton(
                        onPressed: () => setState(() {
                          _mode = _AuthMode.forgot;
                          _error = null;
                          _info = null;
                        }),
                        child: const Text('Passwort vergessen?'),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _mode = _AuthMode.magic;
                          _error = null;
                          _info = null;
                        }),
                        icon: const Icon(LucideIcons.wand, size: 14),
                        label: const Text('Login per Magic-Link'),
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppColors.line, height: 1),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _mode = _AuthMode.register;
                          _error = null;
                          _info = null;
                        }),
                        icon: const Icon(LucideIcons.userPlus, size: 16),
                        label: const Text('Noch kein Konto? Registrieren'),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: () => setState(() {
                          _mode = _AuthMode.login;
                          _error = null;
                          _info = null;
                        }),
                        child: const Text('Zurück zum Login'),
                      ),
                    ],

                    if (isRegister) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Mit der Registrierung akzeptierst du die '
                        'Nutzungsbedingungen und Datenschutzerklärung.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.amber, AppColors.amberWarm],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber.withValues(alpha: 0.4),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(LucideIcons.heart,
            size: 30, color: AppColors.voidColor),
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.score, required this.checks});
  final int score;
  final List<({String label, bool ok})> checks;

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    String scoreLabel;
    if (score <= 1) {
      scoreColor = AppColors.herzrot;
      scoreLabel = 'schwach';
    } else if (score == 2) {
      scoreColor = AppColors.amber;
      scoreLabel = 'mittel';
    } else if (score == 3) {
      scoreColor = AppColors.tealSoft;
      scoreLabel = 'gut';
    } else {
      scoreColor = AppColors.leben;
      scoreLabel = 'stark';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: score / 4,
                    minHeight: 4,
                    backgroundColor: AppColors.elevated,
                    valueColor: AlwaysStoppedAnimation(scoreColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(scoreLabel,
                  style: AppTypography.label(
                      size: 9, color: scoreColor)),
            ],
          ),
          const SizedBox(height: 8),
          for (final c in checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    c.ok ? LucideIcons.checkCircle2 : LucideIcons.circle,
                    size: 12,
                    color: c.ok ? AppColors.lebenSoft : AppColors.mute,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: AppTypography.caption(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.isError = false});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.herzrot : AppColors.leben;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isError ? LucideIcons.alertTriangle : LucideIcons.checkCircle,
            size: 14,
            color: isError ? AppColors.herzrotWarm : AppColors.lebenSoft,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body(
                size: 13,
                color: isError ? AppColors.herzrotWarm : AppColors.lebenSoft,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
