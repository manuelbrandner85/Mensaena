import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../services/supabase/auth_service.dart';

class ResetSheet extends StatefulWidget {
  const ResetSheet({super.key});

  @override
  State<ResetSheet> createState() => _ResetSheetState();
}

class _ResetSheetState extends State<ResetSheet> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_email.text.contains('@')) return;
    setState(() => _busy = true);
    try {
      await authService.sendPasswordReset(_email.text);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      CinemaToast.show(
        context,
        variant: ToastVariant.success,
        message: 'Reset-Link an ${_email.text} gesendet.',
      );
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(context, variant: ToastVariant.error, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Passwort zuruecksetzen', style: MnTypography.display(size: 22)),
        const SizedBox(height: 8),
        Text(
          'Wir senden dir einen Link, mit dem du ein neues Passwort setzen kannst.',
          style: MnTypography.body(color: MnColors.inkSoft, size: 13),
        ),
        const SizedBox(height: 20),
        CinemaInput(
          controller: _email,
          label: 'E-MAIL',
          placeholder: 'du@nachbar.de',
          variant: CinemaInputVariant.email,
          autofocus: true,
        ),
        const SizedBox(height: 20),
        GlowButton(
          label: _busy ? 'Sende...' : 'Link senden',
          variant: GlowVariant.primary,
          fullWidth: true,
          onPressed: _busy ? null : _send,
        ),
      ],
    );
  }
}
