import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState, OtpType, UserAttributes;

import '../../config/theme/app_colors.dart';
import '../../widgets/navigation/language_picker.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

/// Auth-Modi 1:1 zu Web src/app/auth/page.tsx:
/// - login: E-Mail+Passwort
/// - register: zusätzlich Nickname + AGB-Checkbox
/// - forgot: nur E-Mail, sendet resetPasswordForEmail
/// - reset: neues Passwort + Bestätigung (nach PASSWORD_RECOVERY-Event)
enum _AuthMode { login, register, forgot, reset }

/// SKILL: mensaena-design + mensaena-features
/// 1:1-Spiegel von `src/app/auth/page.tsx` (Cinema-Dark + Bronze-Akzent).
/// Elemente: Hero-Orbs, Firefly-Partikel, Logo + Wortmarke, Meta-Label
/// "01 / Anmelden", Cinema-Serif-Heading mit Akzent-Wort, Inline-Forgot-Link,
/// Passwort-Strength-Bar mit 4-stufiger Farbkurve, Agreement-Checkbox,
/// Bronze-Gradient-CTA mit Pfeil, Mode-Toggle im Footer, Back-to-Home-Link.
class AuthScreen extends StatefulWidget {
  const AuthScreen({this.mode = 'login', super.key});

  final String mode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  late _AuthMode _mode;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  // For reset-mode: confirm new password
  final _passwordConfirmCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _agreed = false;
  String? _error;
  String? _info;
  // B6: true → "Bestätigungs-E-Mail erneut senden"-Button anzeigen
  // (nach Registrierung ODER bei 'email not confirmed'-Login-Fehler).
  bool _showResendConfirm = false;
  bool _resending = false;
  int _failCount = 0;
  DateTime? _lockUntil;

  /// Subscription for Supabase auth state — listens for PASSWORD_RECOVERY
  /// events from magic-link deep-links and switches UI to reset mode.
  StreamSubscription<AuthState>? _authSub;

  // Animation for fireflies
  late final AnimationController _fireflyCtrl;

  @override
  void initState() {
    super.initState();
    _mode = switch (widget.mode) {
      'register' => _AuthMode.register,
      'forgot' => _AuthMode.forgot,
      'reset' => _AuthMode.reset,
      _ => _AuthMode.login,
    };
    _passwordCtrl.addListener(() => mounted ? setState(() {}) : null);
    _fireflyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Listen for PASSWORD_RECOVERY event (magic-link deep-link).
    // 1:1 zu Web src/app/auth/page.tsx PASSWORD_RECOVERY-Listener.
    _authSub = sb.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() => _mode = _AuthMode.reset);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _fireflyCtrl.dispose();
    super.dispose();
  }

  // ── Validators ─────────────────────────────────────────────
  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'auth.emailRequired'.tr();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
      return 'auth.emailInvalid'.tr();
    }
    return null;
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.length < 2) return 'auth.nameTooShort'.tr();
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'auth.passwordTooShort'.tr();
    return null;
  }

  // ── Password-Strength ──────────────────────────────────────
  List<({String label, bool ok})> get _checks {
    final p = _passwordCtrl.text;
    return [
      (label: 'auth.pwCheckLength'.tr(), ok: p.length >= 8),
      (
        label: 'auth.pwCheckCase'.tr(),
        ok: RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p),
      ),
      (label: 'auth.pwCheckNumber'.tr(), ok: RegExp(r'\d').hasMatch(p)),
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

  Color _pwColor() {
    final s = _pwScore;
    if (s <= 1) return AppColors.herzrotWarm;
    if (s == 2) return AppColors.bronze;
    if (s == 3) return const Color(0xFF60A5FA);
    return const Color(0xFF4ADE80);
  }

  String _pwLabel() {
    final s = _pwScore;
    if (s <= 1) return 'auth.pwStrengthWeak'.tr();
    if (s == 2) return 'auth.pwStrengthMedium'.tr();
    if (s == 3) return 'auth.pwStrengthGood'.tr();
    return 'auth.pwStrengthStrong'.tr();
  }

  String _modeIndex() => switch (_mode) {
        _AuthMode.login => '01',
        _AuthMode.register => '02',
        _AuthMode.forgot => '03',
        _AuthMode.reset => '04',
      };

  String _modeLabel() => switch (_mode) {
        _AuthMode.login => 'auth.signIn'.tr(),
        _AuthMode.register => 'auth.signUp'.tr(),
        _AuthMode.forgot => 'settings.security.forgotPassword'.tr(),
        _AuthMode.reset => 'settings.security.newPassword'.tr(),
      };

  String _heading() => switch (_mode) {
        _AuthMode.login => 'auth.heading.login'.tr(),
        _AuthMode.register => 'auth.heading.register'.tr(),
        _AuthMode.forgot => 'auth.heading.forgot'.tr(),
        _AuthMode.reset => 'auth.heading.reset'.tr(),
      };

  String _headingAccent() => switch (_mode) {
        _AuthMode.login => 'auth.headingAccent.login'.tr(),
        _AuthMode.register => 'auth.headingAccent.register'.tr(),
        _AuthMode.forgot => 'auth.headingAccent.forgot'.tr(),
        _AuthMode.reset => 'auth.headingAccent.reset'.tr(),
      };

  String _subtitle() => switch (_mode) {
        _AuthMode.login => 'auth.subtitle.login'.tr(),
        _AuthMode.register => 'auth.subtitle.register'.tr(),
        _AuthMode.forgot => 'auth.subtitle.forgot'.tr(),
        _AuthMode.reset => 'auth.subtitle.reset'.tr(),
      };

  String _submitLabel() => switch (_mode) {
        _AuthMode.login => 'auth.submit.login'.tr(),
        _AuthMode.register => 'auth.submit.register'.tr(),
        _AuthMode.forgot => 'auth.submit.forgot'.tr(),
        _AuthMode.reset => 'auth.submit.reset'.tr(),
      };

  // ── Actions ────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mode == _AuthMode.register) {
      if (!_checks.every((c) => c.ok)) {
        setState(() => _error = 'auth.pwRequirementsNotMet'.tr());
        return;
      }
      if (!_agreed) {
        setState(() => _error = 'auth.acceptTerms'.tr());
        return;
      }
    }
    if (_lockUntil != null && DateTime.now().isBefore(_lockUntil!)) {
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
          _failCount = 0;
          context.go('/dashboard');
          return;
        case _AuthMode.register:
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
          setState(() {
            _info = 'auth.infoAccountCreated'.tr();
            // Nach Registrierung: Resend-Pfad anbieten, falls die Mail nicht
            // ankommt (Spam, Tippfehler) → kein Sackgassen-Gefühl.
            _showResendConfirm = true;
          });
          break;
        case _AuthMode.forgot:
          // Email-Enumeration-Schutz: gleicher Text egal ob Konto existiert.
          await sb.auth.resetPasswordForEmail(
            _emailCtrl.text.trim().toLowerCase(),
            redirectTo: 'https://www.mensaena.de/auth?mode=reset',
          );
          setState(() => _info =
              'auth.infoResetSent'.tr());
          break;
        case _AuthMode.reset:
          // Passwort-Stärke Pflicht.
          if (_pwScore < 3) {
            setState(() => _error =
                'auth.errResetWeak'.tr());
            return;
          }
          if (_passwordCtrl.text != _passwordConfirmCtrl.text) {
            setState(() => _error = 'auth.errPwMismatch'.tr());
            return;
          }
          await sb.auth.updateUser(
            UserAttributes(password: _passwordCtrl.text),
          );
          await sb.auth.signOut();
          if (!mounted) return;
          setState(() {
            _info = 'auth.infoPwSaved'.tr();
            _mode = _AuthMode.login;
            _passwordCtrl.clear();
            _passwordConfirmCtrl.clear();
          });
          break;
      }
    } catch (e) {
      final raw = e.toString().replaceFirst('AuthApiException: ', '');
      final low = raw.toLowerCase();
      // Lokalisierte, nutzerfreundliche Meldungen statt roher Supabase-Texte
      // (App ist 7-sprachig). Vorher fehlte u.a. der häufige Fall
      // 'Email not confirmed' → Nutzer sah englischen Roh-Text.
      String msg;
      if (low.contains('already registered') ||
          low.contains('user already')) {
        // Email-Enumeration-Schutz: Bei der Registrierung NICHT verraten, dass
        // die Adresse bereits existiert. Stattdessen exakt dieselbe Antwort wie
        // bei einer echten Neu-Registrierung anzeigen — so kann ein Angreifer
        // über das Register-Formular keine bestehenden Konten abklopfen.
        // (Login bleibt unverändert: 'invalid credentials' ist ohnehin identisch
        //  für falsches Passwort und nicht existierende Adresse.)
        if (_mode == _AuthMode.register) {
          setState(() {
            _info = 'auth.infoAccountCreated'.tr();
            _showResendConfirm = true;
          });
          return;
        }
        msg = 'auth.errAlreadyRegistered'.tr();
      } else if (low.contains('email not confirmed') ||
          low.contains('not confirmed')) {
        msg = 'auth.errEmailNotConfirmed'.tr();
        _showResendConfirm = true;
      } else if (low.contains('invalid login') ||
          low.contains('invalid credentials')) {
        msg = 'auth.wrongCredentials'.tr();
        _failCount += 1;
        if (_failCount >= 5) {
          _lockUntil = DateTime.now().add(const Duration(seconds: 60));
        }
      } else if (low.contains('rate limit') ||
          low.contains('too many') ||
          low.contains('429')) {
        msg = 'auth.errRateLimit'.tr();
      } else if (low.contains('password should be') ||
          low.contains('weak password') ||
          low.contains('at least 6')) {
        msg = 'auth.errWeakPassword'.tr();
      } else {
        msg = 'auth.errGeneric'.tr();
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// B6: Bestätigungs-E-Mail erneut senden. Behebt die Sackgasse, wenn die
  /// Mail nach Registrierung nicht ankommt.
  Future<void> _resendConfirmation() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await sb.auth.resend(type: OtpType.signup, email: email);
      if (!mounted) return;
      setState(() => _info = 'auth.resendConfirmSent'.tr());
    } catch (_) {
      if (!mounted) return;
      // Bewusst generische Meldung (kein Email-Enumeration-Leak).
      setState(() => _info = 'auth.resendConfirmSent'.tr());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == _AuthMode.register;
    final isForgot = _mode == _AuthMode.forgot;
    final isReset = _mode == _AuthMode.reset;
    final lockSeconds = _lockUntil == null
        ? 0
        : _lockUntil!.difference(DateTime.now()).inSeconds.clamp(0, 999);

    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: Stack(
        children: [
          // Language-Picker top-right
          const Positioned(
            top: 12,
            right: 12,
            child: SafeArea(child: LanguagePicker()),
          ),
          // Hero-Orb 1 (Bronze, top-left)
          const _HeroOrb(
            color: AppColors.bronze,
            opacity: 0.10,
            top: -0.20,
            left: -0.10,
            sizeRatio: 0.7,
          ),
          // Hero-Orb 2 (Teal, bottom-right)
          const _HeroOrb(
            color: AppColors.teal,
            opacity: 0.05,
            bottom: -0.15,
            right: -0.10,
            sizeRatio: 0.65,
          ),
          // Firefly-Particles
          ..._buildFireflies(MediaQuery.sizeOf(context)),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo + Wortmarke
                      const _LogoLockup(),
                      const SizedBox(height: 32),

                      // Card (bg-mn-raised + shadow-cinema-raised)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.raised,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.45),
                              blurRadius: 38,
                              offset: const Offset(0, 18),
                            ),
                            BoxShadow(
                              color: AppColors.bronze
                                  .withValues(alpha: 0.06),
                              blurRadius: 60,
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MetaLabel(
                                index: _modeIndex(),
                                label: _modeLabel(),
                              ),
                              const SizedBox(height: 14),
                              _CinemaHeading(
                                base: _heading(),
                                accent: _headingAccent(),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _subtitle(),
                                style: AppTypography.body(
                                  size: 13,
                                  color: AppColors.mute,
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (_error != null)
                                _AlertBanner(
                                    text: _error!, isError: true),
                              if (_info != null)
                                _AlertBanner(
                                    text: _info!, isError: false),
                              // B6: Resend-Bestätigung — behebt Email-Sackgasse.
                              if (_showResendConfirm)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed:
                                        _resending ? null : _resendConfirmation,
                                    icon: _resending
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.bronze),
                                          )
                                        : const Icon(LucideIcons.mailCheck,
                                            size: 14),
                                    label: Text('auth.resendConfirm'.tr()),
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppColors.bronze),
                                  ),
                                ),
                              if (_error != null ||
                                  _info != null ||
                                  _showResendConfirm)
                                const SizedBox(height: 16),

                              // Name (register only)
                              if (isRegister) ...[
                                _FieldLabel('auth.fieldName'.tr()),
                                _CinemaTextField(
                                  controller: _nameCtrl,
                                  hint: 'auth.nameHint'.tr(),
                                  icon: LucideIcons.user,
                                  validator: _validateName,
                                ),
                                const SizedBox(height: 16),
                              ],

                              // E-Mail (hidden in reset-mode, session already set)
                              if (!isReset) ...[
                              _FieldLabel('auth.fieldEmail'.tr()),
                              _CinemaTextField(
                                controller: _emailCtrl,
                                hint: 'auth.emailHint'.tr(),
                                icon: LucideIcons.mail,
                                keyboardType:
                                    TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              ],

                              // Passwort + Inline-Forgot-Link
                              if (!isForgot) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _FieldLabel('auth.fieldPassword'.tr()),
                                    if (_mode == _AuthMode.login)
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          _mode = _AuthMode.forgot;
                                          _error = null;
                                          _info = null;
                                        }),
                                        child: Text(
                                          'auth.forgotShort'.tr(),
                                          style: AppTypography.body(
                                            size: 11,
                                            color: AppColors.bronze,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                _CinemaTextField(
                                  controller: _passwordCtrl,
                                  hint: isRegister
                                      ? 'auth.passwordHintRegister'.tr()
                                      : '••••••••',
                                  icon: LucideIcons.lock,
                                  obscure: _obscure,
                                  validator: _validatePassword,
                                  suffixIcon: IconButton(
                                    tooltip: 'common.showPassword'.tr(),
                                    icon: Icon(
                                      _obscure
                                          ? LucideIcons.eyeOff
                                          : LucideIcons.eye,
                                      size: 16,
                                      color: AppColors.ghost,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscure = !_obscure),
                                  ),
                                ),
                                if ((isRegister || isReset) &&
                                    _passwordCtrl.text.isNotEmpty)
                                  _PasswordStrength(
                                    score: _pwScore,
                                    color: _pwColor(),
                                    label: _pwLabel(),
                                    checks: _checks,
                                  ),
                                // Confirm-Field nur fuer Reset-Mode
                                if (isReset) ...[
                                  const SizedBox(height: 16),
                                  _FieldLabel('auth.fieldConfirmPassword'.tr()),
                                  _CinemaTextField(
                                    controller: _passwordConfirmCtrl,
                                    hint: 'auth.confirmPasswordHint'.tr(),
                                    icon: LucideIcons.lock,
                                    obscure: _obscure,
                                    validator: (v) {
                                      if (v != _passwordCtrl.text) {
                                        return 'auth.errPwMismatch'.tr();
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ],

                              // Agreement (register only)
                              if (isRegister) ...[
                                const SizedBox(height: 16),
                                _AgreementCheckbox(
                                  checked: _agreed,
                                  onChanged: (v) =>
                                      setState(() => _agreed = v),
                                ),
                              ],

                              // Rate-limit warning
                              if (lockSeconds > 0) ...[
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    'auth.lockedSeconds'.tr(
                                        namedArgs: {'n': '$lockSeconds'}),
                                    style: AppTypography.mono(
                                      size: 10,
                                      color: AppColors.herzrotWarm,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 22),

                              // Submit Button — Bronze Gradient + Arrow
                              _SubmitButton(
                                label: _submitLabel(),
                                loading: _busy,
                                disabled: lockSeconds > 0,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Mode Toggle (im Card-Footer)
                      const SizedBox(height: 18),
                      Center(child: _ModeToggle(
                        mode: _mode,
                        onChange: (m) => setState(() {
                          _mode = m;
                          _error = null;
                          _info = null;
                        }),
                      )),

                      // Back to home
                      const SizedBox(height: 18),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/'),
                          child: Text(
                            'auth.backToHome'.tr(),
                            style: AppTypography.label(
                              size: 10,
                              color: AppColors.mute,
                              letterSpacing: 0.10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFireflies(Size size) {
    return List<Widget>.generate(6, (i) {
      return AnimatedBuilder(
        animation: _fireflyCtrl,
        builder: (_, __) {
          final t = (_fireflyCtrl.value + i * 0.18) % 1.0;
          final y = (15 + i * 13) / 100 * size.height +
              math.sin(t * 2 * math.pi) * 10;
          final x = (8 + i * 14) / 100 * size.width +
              math.cos(t * 2 * math.pi) * 8;
          final s = 3.0 + (i % 3);
          return Positioned(
            top: y,
            left: x,
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                color: AppColors.bronze.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bronze.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Hero-Orb (Radial-Gradient Hintergrund-Blob)
// ─────────────────────────────────────────────────────────────
class _HeroOrb extends StatelessWidget {
  const _HeroOrb({
    required this.color,
    required this.opacity,
    this.top,
    this.left,
    this.bottom,
    this.right,
    required this.sizeRatio,
  });

  final Color color;
  final double opacity;
  final double? top;
  final double? left;
  final double? bottom;
  final double? right;
  final double sizeRatio;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dim = size.width * sizeRatio;
    return Positioned(
      top: top != null ? size.height * top! : null,
      left: left != null ? size.width * left! : null,
      bottom: bottom != null ? size.height * bottom! : null,
      right: right != null ? size.width * right! : null,
      child: IgnorePointer(
        child: Container(
          width: dim,
          height: dim,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Logo + Wortmarke (Mensaena. mit bronze Punkt)
// ─────────────────────────────────────────────────────────────
class _LogoLockup extends StatelessWidget {
  const _LogoLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.bronze, AppColors.bronzeSoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.bronze.withValues(alpha: 0.35),
                blurRadius: 22,
              ),
            ],
          ),
          child: const Icon(LucideIcons.heart,
              size: 28, color: AppColors.voidColor),
        ),
        const SizedBox(width: 12),
        RichText(
          text: TextSpan(
            style: AppTypography.display(
              size: 28,
              color: AppColors.ink,
            ),
            children: const [
              TextSpan(text: 'Mensaena'),
              TextSpan(
                text: '.',
                style: TextStyle(color: AppColors.bronze),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Meta-Label "01 / Anmelden"
// ─────────────────────────────────────────────────────────────
class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.index, required this.label});
  final String index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 1,
          color: AppColors.bronze.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Text(
          '$index / $label',
          style: AppTypography.label(
            size: 9,
            color: AppColors.bronze.withValues(alpha: 0.85),
            letterSpacing: 0.20,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cinema-Serif Heading mit Akzent-Wort (bronze)
// ─────────────────────────────────────────────────────────────
class _CinemaHeading extends StatelessWidget {
  const _CinemaHeading({required this.base, required this.accent});
  final String base;
  final String accent;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTypography.display(
          size: 30,
          color: AppColors.ink,
          height: 1.10,
        ),
        children: [
          TextSpan(text: base),
          TextSpan(
            text: accent,
            style: const TextStyle(
              color: AppColors.bronze,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Field Label (UPPERCASE, tracking-wide)
// ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.label(
          size: 9,
          color: const Color(0xFFF5F0E8).withValues(alpha: 0.55),
          letterSpacing: 0.20,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cinema-TextField
// ─────────────────────────────────────────────────────────────
class _CinemaTextField extends StatelessWidget {
  const _CinemaTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.validator,
    this.keyboardType,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      style: AppTypography.body(size: 14, color: AppColors.ink),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        hintText: hint,
        hintStyle: AppTypography.body(
          size: 13,
          color: AppColors.ghost,
        ),
        prefixIcon: Icon(icon, size: 16, color: AppColors.ghost),
        suffixIcon: suffixIcon,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.07)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.07)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.bronze.withValues(alpha: 0.45),
              width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.herzrot.withValues(alpha: 0.6)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.herzrot, width: 1.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Password-Strength
// ─────────────────────────────────────────────────────────────
class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({
    required this.score,
    required this.color,
    required this.label,
    required this.checks,
  });

  final int score;
  final Color color;
  final String label;
  final List<({String label, bool ok})> checks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
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
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.right,
                  style: AppTypography.mono(
                    size: 8,
                    color: AppColors.mute,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final c in checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.checkCircle2,
                    size: 12,
                    color: c.ok ? AppColors.leben : AppColors.ghost,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: AppTypography.body(
                      size: 11,
                      color: c.ok ? AppColors.lebenSoft : AppColors.mute,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Agreement-Checkbox mit Inline-Links zu Terms + Privacy
// ─────────────────────────────────────────────────────────────
class _AgreementCheckbox extends StatelessWidget {
  const _AgreementCheckbox({required this.checked, required this.onChanged});
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: checked,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.bronze,
                checkColor: AppColors.voidColor,
                side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2)),
                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTypography.body(
                    size: 11,
                    color: AppColors.mute,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(text: 'auth.terms.prefix'.tr()),
                    TextSpan(
                      text: 'auth.terms.tos'.tr(),
                      style: const TextStyle(
                          color: AppColors.bronze,
                          fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: 'auth.terms.and'.tr()),
                    TextSpan(
                      text: 'auth.terms.privacy'.tr(),
                      style: const TextStyle(
                          color: AppColors.bronze,
                          fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: 'auth.terms.suffix'.tr()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Alert-Banner (Error / Info)
// ─────────────────────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.herzrot : AppColors.leben;
    final fg = isError ? AppColors.herzrotWarm : AppColors.lebenSoft;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body(
                size: 13,
                color: fg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Submit-Button mit Bronze-Gradient + Arrow
// ─────────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: disabled || loading ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.bronze,
                AppColors.bronzeSoft,
                AppColors.bronze,
              ],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.bronze.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.bronze.withValues(alpha: 0.12),
                blurRadius: 40,
              ),
            ],
          ),
          child: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.voidColor),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.voidColor,
                        weight: FontWeight.w600,
                        letterSpacing: 0.05,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowRight,
                        size: 16, color: AppColors.voidColor),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mode-Toggle (Login ↔ Register ↔ Forgot)
// ─────────────────────────────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChange});
  final _AuthMode mode;
  final void Function(_AuthMode) onChange;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTypography.body(
          size: 11,
          color: AppColors.mute,
        ),
        children: [
          if (mode == _AuthMode.login) ...[
            TextSpan(text: 'auth.toggle.noAccountQ'.tr()),
            _link('auth.toggle.registerNow'.tr(),
                () => onChange(_AuthMode.register)),
          ] else if (mode == _AuthMode.register) ...[
            TextSpan(text: 'auth.toggle.alreadyRegisteredQ'.tr()),
            _link(
                'auth.toggle.signIn'.tr(), () => onChange(_AuthMode.login)),
          ] else if (mode == _AuthMode.forgot) ...[
            TextSpan(text: 'auth.toggle.pwRememberedQ'.tr()),
            _link('auth.toggle.backToLogin'.tr(),
                () => onChange(_AuthMode.login)),
          ],
        ],
      ),
    );
  }

  TextSpan _link(String text, VoidCallback onTap) => TextSpan(
        text: text,
        style: TextStyle(
          color: AppColors.bronze,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.bronze.withValues(alpha: 0.5),
        ),
        recognizer: TapGestureRecognizer()..onTap = onTap,
      );
}
