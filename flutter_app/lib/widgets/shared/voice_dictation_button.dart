/// SKILL: mensaena-features
/// Voice-Diktat-Button — drücken → hören → Text in den Controller schreiben.
/// Funktioniert offline auf Android (Google Speech-Recognizer).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class VoiceDictationButton extends StatefulWidget {
  const VoiceDictationButton({
    required this.controller,
    this.localeId,
    this.size = 22,
    super.key,
  });

  final TextEditingController controller;
  final String? localeId; // z. B. 'de_DE' — null = System-Default
  final double size;

  @override
  State<VoiceDictationButton> createState() => _VoiceDictationButtonState();
}

class _VoiceDictationButtonState extends State<VoiceDictationButton> {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _listening = false;
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    // Verlässt der User den Screen mitten im Diktat, läuft die native
    // STT-Session sonst weiter und onStatus/onError feuern auf disposed
    // State ("setState after dispose").
    _stt.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final ok = await _stt.initialize(
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() => _listening = false);
        }
      },
    );
    if (mounted) setState(() => _available = ok);
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _stt.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }
    final mic = await Permission.microphone.request();
    if (mic.isDenied || mic.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('voice.micDenied'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
      return;
    }
    if (!_available) {
      await _init();
      if (!_available) return;
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _listening = true);
    final startLen = widget.controller.text.length;
    await _stt.listen(
      onResult: (r) {
        final words = r.recognizedWords;
        if (words.isEmpty) return;
        final before = widget.controller.text.substring(0, startLen);
        final sep = (before.isEmpty || before.endsWith(' ')) ? '' : ' ';
        widget.controller.text = '$before$sep$words';
        widget.controller.selection = TextSelection.collapsed(
            offset: widget.controller.text.length);
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _listening ? 'voice.dictStop'.tr() : 'voice.dictStart'.tr(),
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _listening
                ? AppColors.herzrot.withValues(alpha: 0.22)
                : Colors.transparent,
          ),
          child: Icon(
            _listening ? LucideIcons.micOff : LucideIcons.mic,
            size: widget.size,
            color: _listening ? AppColors.herzrot : AppColors.bronze,
          ),
        ),
      ),
    );
  }
}
