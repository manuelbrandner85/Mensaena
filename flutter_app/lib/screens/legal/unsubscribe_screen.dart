/// SKILL: mensaena-features
/// Unsubscribe-Screen — vollständig in-app.
/// Liest 'token' aus Query-Params, ruft https://mensaena.de/api/emails/unsubscribe
/// auf und zeigt Loading/Success/Error-State. KEIN Browser-Redirect.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../widgets/navigation/language_picker.dart';

class UnsubscribeScreen extends StatefulWidget {
  const UnsubscribeScreen({super.key, this.token});

  final String? token;

  @override
  State<UnsubscribeScreen> createState() => _UnsubscribeScreenState();
}

class _UnsubscribeScreenState extends State<UnsubscribeScreen> {
  _Status _status = _Status.loading;
  String? _email;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final token = widget.token?.trim();
    if (token == null || token.isEmpty) {
      setState(() {
        _status = _Status.error;
        _error =
            'Kein Token in der URL gefunden. Bitte verwende den Abmelde-Link aus deiner E-Mail.';
      });
      return;
    }
    try {
      final uri = Uri.parse(
          'https://mensaena.de/api/emails/unsubscribe?token=$token');
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Body may be JSON {"email":"..."} or HTML; try JSON parse.
        String? email;
        final body = res.body.trim();
        final emailMatch = RegExp(
                r'"email"\s*:\s*"([^"]+)"',
                caseSensitive: false)
            .firstMatch(body);
        if (emailMatch != null) {
          email = emailMatch.group(1);
        }
        setState(() {
          _status = _Status.success;
          _email = email;
        });
      } else {
        setState(() {
          _status = _Status.error;
          _error =
              'Server-Fehler ${res.statusCode}. Bitte versuche es später erneut.';
        });
      }
    } catch (e) {
      setState(() {
        _status = _Status.error;
        _error = 'Verbindung fehlgeschlagen. Bist du online?';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      appBar: AppBar(
        backgroundColor: AppColors.deep,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.ink),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text('legal.unsubscribeTitle'.tr(),
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        actions: const [LanguagePicker(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_status) {
              _Status.loading => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.amber),
                    const SizedBox(height: 20),
                    Text('legal.unsubscribeProcessing'.tr(),
                        style: AppTypography.body(
                            size: 14, color: AppColors.inkSoft)),
                  ],
                ),
              _Status.success => _resultCard(
                  icon: LucideIcons.checkCircle2,
                  iconColor: AppColors.leben,
                  title: 'misc.unsubscribeSuccess'.tr(),
                  message: _email == null
                      ? 'Dein E-Mail-Konto erhält keine weiteren Marketing-E-Mails von Mensaena mehr.'
                      : 'Die Adresse $_email erhält keine weiteren Marketing-E-Mails von Mensaena mehr.',
                  hint:
                      'Wichtige System-Benachrichtigungen (z. B. Passwort-Reset) werden weiterhin zugestellt.',
                ),
              _Status.error => _resultCard(
                  icon: LucideIcons.alertCircle,
                  iconColor: AppColors.herzrot,
                  title: 'misc.unsubscribeFailed'.tr(),
                  message: _error ?? 'Unbekannter Fehler.',
                  hint:
                      'Bitte kontaktiere uns unter info@mensaena.de, wenn das Problem weiter besteht.',
                ),
            },
          ),
        ),
      ),
    );
  }

  Widget _resultCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: iconColor),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: AppTypography.display(size: 20, color: AppColors.ink)),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                  size: 14, color: AppColors.inkSoft, height: 1.5)),
          if (hint != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 12, color: AppColors.mute),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Status { loading, success, error }
