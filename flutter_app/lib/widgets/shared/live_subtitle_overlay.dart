/// SKILL: mensaena-features + mensaena-design
/// Live-Untertitel — Host tippt in Eingabefeld, alle anderen sehen
/// den Text am unteren Bildrand. Optional auto-uebersetzt in die
/// UI-Sprache des Zuschauers via MyMemory/Lingva.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/libre_translate_service.dart';

class SubtitleData {
  const SubtitleData({
    required this.text,
    required this.sourceLang,
    required this.timestamp,
  });
  final String text;
  final String sourceLang;
  final DateTime timestamp;
}

/// Anzeige-Widget (alle Zuschauer + Host). Auto-translate wenn
/// sourceLang != targetLang.
class SubtitleDisplay extends StatefulWidget {
  const SubtitleDisplay({
    required this.subtitle,
    required this.targetLang,
    super.key,
  });
  final SubtitleData? subtitle;
  final String targetLang;
  @override
  State<SubtitleDisplay> createState() => _SubtitleDisplayState();
}

class _SubtitleDisplayState extends State<SubtitleDisplay> {
  String? _translated;
  String? _lastKey;

  @override
  void didUpdateWidget(covariant SubtitleDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final s = widget.subtitle;
    if (s == null) {
      _translated = null;
      _lastKey = null;
      return;
    }
    final key = '${s.text}|${s.sourceLang}|${widget.targetLang}';
    if (key == _lastKey) return;
    _lastKey = key;
    _translated = null;
    if (s.sourceLang != widget.targetLang) {
      _translate(s);
    }
  }

  Future<void> _translate(SubtitleData s) async {
    final r = await LibreTranslateService.translate(
      text: s.text,
      target: widget.targetLang,
      source: s.sourceLang,
    );
    if (!mounted) return;
    setState(() => _translated = r?.text);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subtitle;
    if (s == null || s.text.isEmpty) return const SizedBox.shrink();
    // Auto-fade nach 8s
    final age = DateTime.now().difference(s.timestamp);
    if (age > const Duration(seconds: 8)) return const SizedBox.shrink();
    final showText = (s.sourceLang == widget.targetLang)
        ? s.text
        : (_translated ?? s.text);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        showText,
        textAlign: TextAlign.center,
        style: AppTypography.body(
          size: 14,
          color: Colors.white,
          height: 1.3,
        ),
      ),
    );
  }
}

/// Host-Input — kleines TextField das den Untertitel-Send triggert.
class SubtitleComposer extends StatefulWidget {
  const SubtitleComposer({required this.onSend, super.key});
  final void Function(String text) onSend;
  @override
  State<SubtitleComposer> createState() => _SubtitleComposerState();
}

class _SubtitleComposerState extends State<SubtitleComposer> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    widget.onSend(t);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.languages,
              size: 14, color: AppColors.bronze),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLength: 120,
              decoration: InputDecoration(
                hintText: 'liveSubtitle.hint'.tr(),
                counterText: '',
                border: InputBorder.none,
                isDense: true,
              ),
              style:
                  AppTypography.body(size: 13, color: Colors.white),
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(
            onPressed: _send,
            icon: const Icon(LucideIcons.send,
                size: 14, color: AppColors.bronze),
            splashRadius: 14,
          ),
        ],
      ),
    );
  }
}
