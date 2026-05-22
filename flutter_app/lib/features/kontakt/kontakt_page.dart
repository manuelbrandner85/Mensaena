import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/supabase.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/glow_button.dart';
import '../../routing/routes.dart';

/// Kontakt-Page – Cinema-Variant der Web /kontakt.
/// Direct-Contact-Block (Email + Adresse), Social-Media-Links und
/// vollwertiges Formular mit Supabase-Insert in contact_messages.
class KontaktPage extends StatefulWidget {
  const KontaktPage({super.key});

  @override
  State<KontaktPage> createState() => _KontaktPageState();
}

class _KontaktPageState extends State<KontaktPage> {
  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      level: AtmosphereLevel.app,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: MnColors.ink),
          onPressed: () => Navigator.of(context).maybePop().then((popped) {
            if (!popped && context.mounted) context.go(Routes.landing);
          }),
        ),
        title: Text('Kontakt', style: MnTypography.appBarTitle()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _HeroSection(),
                  SizedBox(height: 32),
                  _DirectContactCard(),
                  SizedBox(height: 28),
                  _SocialButtons(),
                  SizedBox(height: 36),
                  _ContactForm(),
                  SizedBox(height: 36),
                  _FaqSection(),
                  SizedBox(height: 64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternal(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ── Hero ─────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '— Kontakt',
          style: MnTypography.label(
            size: 11,
            color: MnColors.amber,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Schreib uns.',
          style: MnTypography.display(
            size: 34,
            height: 1.1,
            color: MnColors.ink,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Wir antworten in der Regel innerhalb von 1–2 Werktagen. '
          'Per Mail, Social oder direkt über das Formular.',
          style: MnTypography.body(
            size: 15,
            color: MnColors.inkSoft,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ── Direct Contact ───────────────────────────────────────────────────────
class _DirectContactCard extends StatelessWidget {
  const _DirectContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MnColors.deep.withValues(alpha: 0.7),
        border: Border.all(color: MnColors.lineActive),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconRow(
            icon: LucideIcons.mail,
            label: 'E-Mail',
            value: 'info@mensaena.de',
            onTap: () => _openExternal('mailto:info@mensaena.de'),
          ),
          const SizedBox(height: 14),
          const Divider(color: MnColors.line, height: 1),
          const SizedBox(height: 14),
          const _IconRow(
            icon: LucideIcons.mapPin,
            label: 'Adresse',
            value: 'Manuel Brandner\nIm Wahlsberg 10\n55545 Bad Kreuznach',
          ),
        ],
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: MnColors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: MnColors.amber),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: MnTypography.label(size: 10)),
              const SizedBox(height: 4),
              Text(
                value,
                style: MnTypography.body(
                  size: 14,
                  color: onTap != null ? MnColors.amber : MnColors.ink,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: content,
    );
  }
}

// ── Social ───────────────────────────────────────────────────────────────
class _SocialButtons extends StatelessWidget {
  const _SocialButtons();

  static const List<({String label, String url})> _links = [
    (label: 'Facebook', url: 'https://www.facebook.com/share/g/1BF2NKqGTF/'),
    (label: 'X', url: 'https://x.com/mensaena'),
    (
      label: 'TikTok',
      url: 'https://www.tiktok.com/@mensaena.de?_r=1&_t=ZN-95Qvcabfheo',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Folge uns', style: MnTypography.label(size: 10)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _links
              .map(
                (l) => GlowButton(
                  label: l.label,
                  icon: LucideIcons.externalLink,
                  variant: GlowVariant.ghost,
                  onPressed: () => _openExternal(l.url),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ── Form ─────────────────────────────────────────────────────────────────
class _ContactForm extends StatefulWidget {
  const _ContactForm();

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool _submitting = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Bitte gib deinen Namen an.';
    if (s.length > 100) return 'Name zu lang (max. 100 Zeichen).';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Bitte gib deine E-Mail an.';
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(s)) return 'Ungültige E-Mail-Adresse.';
    return null;
  }

  String? _validateSubject(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Bitte gib einen Betreff an.';
    if (s.length > 200) return 'Betreff zu lang (max. 200 Zeichen).';
    return null;
  }

  String? _validateMessage(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Bitte schreib uns eine Nachricht.';
    if (s.length < 10) return 'Nachricht zu kurz (min. 10 Zeichen).';
    if (s.length > 5000) return 'Nachricht zu lang (max. 5000 Zeichen).';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final emailLower = _emailCtrl.text.trim().toLowerCase();

    try {
      // Rate-Limit: max. 3 Nachrichten pro E-Mail / 24h
      final since = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      final List<dynamic> recent = await sb
          .from('contact_messages')
          .select('id')
          .eq('email', emailLower)
          .gte('created_at', since);
      if (recent.length >= 3) {
        setState(() {
          _submitting = false;
          _error =
              'Zu viele Nachrichten von dieser E-Mail in den letzten 24h. '
              'Bitte versuche es morgen erneut.';
        });
        return;
      }

      await sb.from('contact_messages').insert({
        'name': _nameCtrl.text.trim(),
        'email': emailLower,
        'subject': _subjectCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
      });

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = true;
      });
      _formKey.currentState?.reset();
      _nameCtrl.clear();
      _emailCtrl.clear();
      _subjectCtrl.clear();
      _messageCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Nachricht konnte nicht gesendet werden. Bitte versuche es '
            'gleich noch einmal oder schreib direkt an info@mensaena.de.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MnColors.leben.withValues(alpha: 0.12),
          border: Border.all(color: MnColors.leben),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.check, color: MnColors.leben),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Danke! Deine Nachricht ist bei uns angekommen. '
                'Wir antworten in 1–2 Werktagen.',
                style: MnTypography.body(
                  size: 14,
                  color: MnColors.ink,
                  height: 1.5,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _success = false),
              child: Text(
                'Weitere senden',
                style: MnTypography.body(
                  size: 13,
                  color: MnColors.amber,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MnColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: MnColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Direkt schreiben',
              style: MnTypography.display(
                size: 20,
                height: 1.2,
                color: MnColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            _FormField(
              controller: _nameCtrl,
              label: 'Name',
              validator: _validateName,
              maxLength: 100,
            ),
            const SizedBox(height: 12),
            _FormField(
              controller: _emailCtrl,
              label: 'E-Mail',
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),
            _FormField(
              controller: _subjectCtrl,
              label: 'Betreff',
              validator: _validateSubject,
              maxLength: 200,
            ),
            const SizedBox(height: 12),
            _FormField(
              controller: _messageCtrl,
              label: 'Nachricht',
              validator: _validateMessage,
              maxLines: 6,
              maxLength: 5000,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MnColors.herzrot.withValues(alpha: 0.12),
                  border: Border.all(color: MnColors.herzrot),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: MnTypography.body(
                    size: 13,
                    color: MnColors.herzrotWarm,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            GlowButton(
              label: _submitting ? 'Wird gesendet…' : 'Nachricht senden',
              icon: LucideIcons.send,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType ??
          (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: maxLength != null
          ? [LengthLimitingTextInputFormatter(maxLength)]
          : null,
      style: MnTypography.body(size: 15, color: MnColors.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: MnTypography.label(size: 11),
        filled: true,
        fillColor: MnColors.deep.withValues(alpha: 0.6),
        counterStyle: MnTypography.caption(),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: MnColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: MnColors.amber, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: MnColors.herzrot),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: MnColors.herzrot, width: 2),
        ),
        errorStyle: MnTypography.body(
          size: 12,
          color: MnColors.herzrotWarm,
        ),
      ),
    );
  }
}

// ── FAQ ──────────────────────────────────────────────────────────────────
class _FaqSection extends StatelessWidget {
  const _FaqSection();

  static const List<({String q, String a})> _items = [
    (
      q: 'Technische Probleme',
      a: 'Beschreibe das Problem und nenn dein Geraet / Browser.',
    ),
    (
      q: 'Feedback & Ideen',
      a: 'Wir freuen uns ueber Verbesserungsvorschlaege!',
    ),
    (
      q: 'Meldungen',
      a: 'Problematische Inhalte bitte mit Link melden.',
    ),
    (
      q: 'Datenschutz',
      a: 'Anfragen gemaess DSGVO bitte per E-Mail an info@mensaena.de.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Häufige Anliegen',
          style: MnTypography.display(
            size: 20,
            height: 1.2,
            color: MnColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        for (final it in _items) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MnColors.surface.withValues(alpha: 0.4),
              border: Border.all(color: MnColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it.q,
                  style: MnTypography.body(
                    size: 14,
                    color: MnColors.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  it.a,
                  style: MnTypography.body(
                    size: 13,
                    color: MnColors.inkSoft,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
