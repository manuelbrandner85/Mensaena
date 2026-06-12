/// SKILL: mensaena-design
/// "Mensa" — warmherziger KI-Assistent als schwebende FAB (unten rechts,
/// über der BottomNav). Tippen öffnet ein wegwischbares DraggableScrollableSheet.
/// Spricht mit der Edge Function `chat-ai` über chatAiProvider.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/chat_ai_provider.dart';
import '../../providers/effects_gate_provider.dart';
import '../../repositories/chat_ai_repository.dart';
import '../../services/haptics.dart';
import '../effects/bloom.dart';

class MensaenaAssistantFab extends ConsumerStatefulWidget {
  const MensaenaAssistantFab({required this.screenLabel, super.key});

  /// Lesbares Label des aktuellen Screens (Kontext für Mensa).
  final String screenLabel;

  @override
  ConsumerState<MensaenaAssistantFab> createState() =>
      _MensaenaAssistantFabState();
}

class _MensaenaAssistantFabState extends ConsumerState<MensaenaAssistantFab>
    with SingleTickerProviderStateMixin {
  static const _pulseKey = 'mensaena_assistant_pulse_v1';

  /// E1 Mensa-Pulse: einmaliger Doppel-Puls beim allerersten Erscheinen
  /// des FABs — lenkt EINMAL den Blick auf Mensa, danach nie wieder
  /// (Guard via SecureStorage). Läuft nur auf EffectsProfile.full.
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _pulseScale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 16),
    TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 16),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 18),
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 16),
    TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 16),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 18),
  ]).animate(_pulseCtrl);

  @override
  void initState() {
    super.initState();
    _maybePulse();
  }

  Future<void> _maybePulse() async {
    const storage = FlutterSecureStorage();
    try {
      if (await storage.read(key: _pulseKey) != null) return;
      await storage.write(key: _pulseKey, value: '1');
    } catch (_) {
      return;
    }
    if (!mounted) return;
    // Nur auf `full` — der Hinweis ist Schmuck, keine Funktion.
    if (!ref.read(effectsProfileProvider).isFull) return;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) _pulseCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _open(BuildContext context) {
    Haptics.tap();
    ref.read(chatAiProvider.notifier).setContext(
          screen: widget.screenLabel,
          language: context.locale.languageCode,
        );
    // Begrüßung sicherstellen (lädt Vorname + Tageszeit, einmalig).
    ref.read(chatAiProvider.notifier).ensureGreeting();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const _AssistantSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseScale,
      child: Bloom(
        color: AppColors.bronze,
        radius: 18,
        intensity: 0.5,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _open(context),
            child: Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Halbtransparent (überlagert nichts dauerhaft).
                gradient: LinearGradient(
                  colors: [
                    AppColors.bronze.withValues(alpha: 0.92),
                    AppColors.bronzeSoft.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.bronze.withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bronze.withValues(alpha: 0.40),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppColors.voidColor, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
class _AssistantSheet extends ConsumerStatefulWidget {
  const _AssistantSheet();

  @override
  ConsumerState<_AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<_AssistantSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    Haptics.tap();
    _ctrl.clear();
    await ref.read(chatAiProvider.notifier).send(text);
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatAiProvider);
    ref.listen(chatAiProvider, (_, __) => _scrollDown());
    final showChips = state.messages.length <= 1 && !state.isTyping;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.66,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, sheetScroll) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(
                top: BorderSide(color: AppColors.bronze, width: 0.6),
              ),
            ),
            child: Column(
              children: [
                _handle(),
                _header(context),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (state.isTyping && i == state.messages.length) {
                        return const _TypingBubble();
                      }
                      return _Bubble(
                        message: state.messages[i],
                        onNavigate: (route) {
                          Haptics.tap();
                          Navigator.of(context).pop();
                          context.go(route);
                        },
                        onRate: (rating, q, a) {
                          Haptics.tap();
                          ref.read(chatAiProvider.notifier).rate(rating, q, a);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('assistant.feedback_thanks'.tr()),
                            duration: const Duration(seconds: 2),
                          ));
                        },
                      );
                    },
                  ),
                ),
                if (showChips) _chips(),
                _input(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _handle() => Container(
        margin: const EdgeInsets.only(top: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Bloom(
              color: AppColors.bronze,
              radius: 12,
              intensity: 0.4,
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.bronze, AppColors.bronzeSoft],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 18, color: AppColors.voidColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('assistant.title'.tr(),
                  style: AppTypography.display(size: 17, color: AppColors.ink)),
            ),
            IconButton(
              tooltip: 'common.close'.tr(),
              icon: const Icon(Icons.close, size: 20, color: AppColors.mute),
              onPressed: () {
                Haptics.tap();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );

  Widget _chips() {
    final chips = <String>[
      'assistant.chip_post'.tr(),
      'assistant.chip_karma'.tr(),
      'assistant.chip_help_nearby'.tr(),
      'assistant.chip_crisis'.tr(),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _send(chips[i]),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bronze.withValues(alpha: 0.10),
                border:
                    Border.all(color: AppColors.bronze.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(chips[i],
                  style:
                      AppTypography.label(size: 11, color: AppColors.bronze)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
            12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.elevated,
                  hintText: 'assistant.hint'.tr(),
                  hintStyle: AppTypography.body(size: 13, color: AppColors.mute),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.bronze,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _send(),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.send,
                      size: 16, color: AppColors.voidColor),
                ),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.onNavigate,
    required this.onRate,
  });

  final ChatAiMessage message;
  final void Function(String route) onNavigate;
  final void Function(int rating, String question, String answer) onRate;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromUser;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    if (mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: AppColors.bronze.withValues(alpha: 0.20),
            border: Border.all(color: AppColors.bronze.withValues(alpha: 0.45)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(message.text,
              style: AppTypography.body(
                  size: 14, color: AppColors.ink, height: 1.45)),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Text(message.text,
                  style: AppTypography.body(
                      size: 14, color: AppColors.ink, height: 1.45)),
            ),
            // Navigations-Button nur wenn navRoute gesetzt.
            if (message.navRoute != null && message.navRoute!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OutlinedButton.icon(
                  onPressed: () => onNavigate(message.navRoute!),
                  icon: const Icon(Icons.arrow_forward, size: 15),
                  label: Text(message.navLabel ?? 'assistant.open'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bronze,
                    side: BorderSide(
                        color: AppColors.bronze.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
              ),
            // Feedback-Daumen unter Bot-Antworten (nur wenn es eine Frage gab).
            if (message.question != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    _ThumbButton(
                      icon: Icons.thumb_up_alt_outlined,
                      onTap: () => onRate(
                          1, message.question!, message.text),
                    ),
                    _ThumbButton(
                      icon: Icons.thumb_down_alt_outlined,
                      onTap: () => onRate(
                          -1, message.question!, message.text),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThumbButton extends StatelessWidget {
  const _ThumbButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 15,
      color: AppColors.mute,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}

// "schreibt…"-Animation (3 pulsierende Bronze-Punkte).
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (_c.value + i * 0.33) % 1.0;
              final t = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.scale(
                  scale: 0.6 + t * 0.6,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.bronze.withValues(alpha: 0.35 + t * 0.55),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
