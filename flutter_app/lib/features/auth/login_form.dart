import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_sheet.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/cinema_toggle.dart';
import '../../core/widgets/glow_button.dart';
import '../../services/supabase/auth_service.dart';
import 'reset_sheet.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _stayLoggedIn = true;
  bool _busy = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _emailError = _email.text.contains('@') ? null : 'Ungueltige E-Mail';
      _passwordError = _password.text.length >= 6 ? null : 'Mindestens 6 Zeichen';
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _busy = true);
    try {
      await authService.signInWithPassword(email: _email.text, password: _password.text);
      if (!mounted) return;
      GoRouter.of(context).go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(context,
          variant: ToastVariant.error,
          message: 'Anmeldung fehlgeschlagen. ${_friendly(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _magicLink() async {
    if (!_email.text.contains('@')) {
      setState(() => _emailError = 'E-Mail-Adresse fuer Magic Link eintragen');
      return;
    }
    setState(() => _busy = true);
    try {
      await authService.signInWithMagicLink(_email.text);
      if (!mounted) return;
      CinemaToast.show(context,
          variant: ToastVariant.success,
          message: 'Magic Link an ${_email.text} gesendet.');
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(context, variant: ToastVariant.error, message: _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openReset() {
    CinemaSheet.show(context, child: const ResetSheet(), initialSize: 0.45);
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('Invalid login credentials')) return 'E-Mail oder Passwort falsch.';
    if (s.contains('rate limit')) return 'Zu viele Versuche. Bitte gleich erneut probieren.';
    return 'Bitte versuche es erneut.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CinemaInput(
          controller: _email,
          label: 'E-MAIL',
          placeholder: 'du@nachbar.de',
          variant: CinemaInputVariant.email,
          errorText: _emailError,
        ),
        const SizedBox(height: 16),
        CinemaInput(
          controller: _password,
          label: 'PASSWORT',
          placeholder: 'Mindestens 6 Zeichen',
          variant: CinemaInputVariant.password,
          errorText: _passwordError,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CinemaToggle(value: _stayLoggedIn, onChanged: (v) => setState(() => _stayLoggedIn = v)),
            const SizedBox(width: 10),
            Text('Angemeldet bleiben',
                style: MnTypography.body(color: MnColors.inkSoft, size: 13)),
          ],
        ),
        const SizedBox(height: 20),
        GlowButton(
          label: _busy ? 'Anmelden...' : 'Anmelden',
          variant: GlowVariant.primary,
          fullWidth: true,
          onPressed: _busy ? null : _signIn,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider(color: MnColors.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('oder',
                  style: MnTypography.body(color: MnColors.ghost, size: 12)),
            ),
            const Expanded(child: Divider(color: MnColors.line)),
          ],
        ),
        const SizedBox(height: 16),
        GlowButton(
          label: 'Magic Link senden',
          variant: GlowVariant.ghost,
          fullWidth: true,
          onPressed: _busy ? null : _magicLink,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _openReset,
            child: Text('Passwort vergessen?',
                style: MnTypography.body(color: MnColors.teal, size: 13)),
          ),
        ),
      ],
    );
  }
}
