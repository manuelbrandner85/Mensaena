import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

/// SKILL: supabase
/// Auth-Screen — Login + Register + Magic-Link. Voll funktional gegen
/// dieselbe Supabase-Instanz wie die Webseite.
class AuthScreen extends StatefulWidget {
  const AuthScreen({this.mode = 'login', super.key});

  final String mode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late String _mode;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode == 'register' ? 'register' : 'login';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'E-Mail fehlt.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
      return 'Ungültige E-Mail.';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'Mindestens 8 Zeichen.';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_mode == 'register') {
        await sb.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        setState(() {
          _info = 'Konto erstellt. Pruefe deine E-Mails zur Bestaetigung.';
        });
      } else {
        await sb.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        if (!mounted) return;
        context.go('/dashboard');
        return;
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('AuthApiException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == 'register';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          isRegister ? 'Registrieren' : 'Anmelden',
          style: AppTypography.appBarTitle(),
        ),
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
                    Text(
                      isRegister
                          ? 'Willkommen in der Nachbarschaft.'
                          : 'Willkommen zurueck.',
                      style: AppTypography.display(
                        size: 28,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      style: AppTypography.body(color: AppColors.ink),
                      decoration: const InputDecoration(labelText: 'E-Mail'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      validator: _validatePassword,
                      style: AppTypography.body(color: AppColors.ink),
                      decoration: const InputDecoration(labelText: 'Passwort'),
                    ),
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
                      child: Text(
                        _busy
                            ? '...'
                            : (isRegister
                                ? 'Konto erstellen'
                                : 'Anmelden'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() {
                        _mode = isRegister ? 'login' : 'register';
                        _error = null;
                        _info = null;
                      }),
                      child: Text(
                        isRegister
                            ? 'Bereits dabei? Anmelden'
                            : 'Noch kein Konto? Registrieren',
                      ),
                    ),
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
      child: Text(
        text,
        style: AppTypography.body(
          size: 13,
          color: isError ? AppColors.herzrotWarm : AppColors.lebenSoft,
          height: 1.5,
        ),
      ),
    );
  }
}
