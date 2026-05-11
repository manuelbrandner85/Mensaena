import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_progress.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/cinema_toggle.dart';
import '../../core/widgets/glow_button.dart';
import '../../services/supabase/auth_service.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  String? _err;
  double _strength = 0;

  @override
  void initState() {
    super.initState();
    _password.addListener(_updateStrength);
  }

  void _updateStrength() {
    final pw = _password.text;
    var s = 0.0;
    if (pw.length >= 6) s += 0.25;
    if (pw.length >= 10) s += 0.25;
    if (pw.contains(RegExp(r'[A-Z]')) && pw.contains(RegExp(r'[a-z]'))) s += 0.25;
    if (pw.contains(RegExp(r'[0-9!@#\$%^&*]'))) s += 0.25;
    setState(() => _strength = s);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _err = null);

    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'Name fehlt.');
      return;
    }
    if (!_email.text.contains('@')) {
      setState(() => _err = 'Ungueltige E-Mail.');
      return;
    }
    if (_strength < 0.5) {
      setState(() => _err = 'Passwort zu schwach (mindestens 8 Zeichen mit Zahl).');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _err = 'Passwoerter stimmen nicht ueberein.');
      return;
    }
    if (!_consent) {
      setState(() => _err = 'Bitte Datenschutzerklaerung bestaetigen.');
      return;
    }

    setState(() => _busy = true);
    try {
      await authService.signUp(
        email: _email.text,
        password: _password.text,
        fullName: _name.text.trim(),
      );
      if (!mounted) return;
      CinemaToast.show(context,
          variant: ToastVariant.success,
          message: 'Willkommen! Bitte bestaetige deine E-Mail.');
      GoRouter.of(context).go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Registrierung fehlgeschlagen.');
      CinemaToast.show(context, variant: ToastVariant.error, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color get _strengthColor {
    if (_strength < 0.4) return MnColors.herzrot;
    if (_strength < 0.75) return MnColors.amber;
    return MnColors.leben;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CinemaInput(
            controller: _name,
            label: 'NAME',
            placeholder: 'Vor- und Nachname',
          ),
          const SizedBox(height: 16),
          CinemaInput(
            controller: _email,
            label: 'E-MAIL',
            placeholder: 'du@nachbar.de',
            variant: CinemaInputVariant.email,
          ),
          const SizedBox(height: 16),
          CinemaInput(
            controller: _password,
            label: 'PASSWORT',
            placeholder: 'Mindestens 8 Zeichen',
            variant: CinemaInputVariant.password,
          ),
          const SizedBox(height: 8),
          CinemaProgress(value: _strength, color: _strengthColor),
          const SizedBox(height: 16),
          CinemaInput(
            controller: _confirm,
            label: 'PASSWORT WIEDERHOLEN',
            placeholder: 'Nochmal eingeben',
            variant: CinemaInputVariant.password,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CinemaToggle(value: _consent, onChanged: (v) => setState(() => _consent = v)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ich habe die Datenschutzerklaerung gelesen und stimme zu.',
                  style: MnTypography.body(color: MnColors.inkSoft, size: 12),
                ),
              ),
            ],
          ),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!, style: MnTypography.body(color: MnColors.herzrot, size: 13)),
          ],
          const SizedBox(height: 20),
          GlowButton(
            label: _busy ? 'Registrieren...' : 'Registrieren',
            variant: GlowVariant.primary,
            fullWidth: true,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
