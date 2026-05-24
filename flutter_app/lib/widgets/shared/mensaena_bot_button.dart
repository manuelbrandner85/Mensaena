import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/bot_service.dart';
import '../../services/haptics.dart';
import '../effects/bloom.dart';
import '../effects/glass_card.dart';

/// SKILL: mensaena-design
/// 1:1-Pendant zu `src/components/bot/MensaenaBot.tsx` —
/// Floating-Bronze-Bot-Button mit New-Indicator. Tap oeffnet Chat-Sheet.
class MensaenaBotButton extends StatefulWidget {
  const MensaenaBotButton({super.key});

  @override
  State<MensaenaBotButton> createState() => _MensaenaBotButtonState();
}

class _MensaenaBotButtonState extends State<MensaenaBotButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _openChat(BuildContext context) {
    Haptics.tap();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BotChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse rings
            for (var i = 0; i < 2; i++)
              Opacity(
                opacity:
                    (1 - ((_pulseCtrl.value + i * 0.5) % 1.0)) * 0.4,
                child: Container(
                  width: 56 +
                      ((_pulseCtrl.value + i * 0.5) % 1.0) * 28,
                  height: 56 +
                      ((_pulseCtrl.value + i * 0.5) % 1.0) * 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          AppColors.bronze.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openChat(context),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.bronze,
                        AppColors.bronzeSoft,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bronze
                            .withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    color: AppColors.voidColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bot-Chat-Sheet (Modal Bottom-Sheet)
// ─────────────────────────────────────────────────────────────
class _BotChatSheet extends ConsumerStatefulWidget {
  const _BotChatSheet();

  @override
  ConsumerState<_BotChatSheet> createState() => _BotChatSheetState();
}

class _BotChatSheetState extends ConsumerState<_BotChatSheet> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final List<BotMessage> _messages;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages = [
      BotMessage(
        role: 'assistant',
        content: 'bot.welcomeMessage'.tr(),
      ),
    ];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    Haptics.tap();
    setState(() {
      _messages.add(BotMessage(role: 'user', content: text));
      _messages.add(const BotMessage(role: 'assistant', content: ''));
      _sending = true;
    });
    _ctrl.clear();
    _scrollToBottom();
    final route = GoRouterState.of(context).uri.path;
    await BotService.chatStream(
      messages: _messages.where((m) => m.content.isNotEmpty).toList(),
      route: route,
      onToken: (tok) {
        if (!mounted) return;
        setState(() {
          final last = _messages.last;
          _messages[_messages.length - 1] = BotMessage(
            role: 'assistant',
            content: last.content + tok,
          );
        });
        _scrollToBottom();
      },
    );
    if (!mounted) return;
    final last = _messages.last;
    if (last.content.isEmpty) {
      setState(() {
        _messages[_messages.length - 1] = BotMessage(
          role: 'assistant',
          content: _mockReply(text),
        );
      });
    }
    setState(() => _sending = false);
  }

  /// Lokales Mock-Fallback, falls Backend nicht antwortet — Keyword-basiert.
  String _mockReply(String userText) {
    final t = userText.toLowerCase();
    if (t.contains('karte') || t.contains('map')) {
      return 'Tipp: Über die Karte siehst du Hilfe-Angebote und -Gesuche '
          'in deiner Nachbarschaft. Tipp auf einen Marker für Details.';
    }
    if (t.contains('hilfe')) {
      return 'Du kannst Hilfe anbieten oder eine Bitte erstellen — '
          'einfach unten Mitte auf „Erstellen" tippen.';
    }
    if (t.contains('profil')) {
      return 'Dein Profil findest du im Menü unter „Profil". Dort kannst '
          'du Avatar, Bio und Skills bearbeiten.';
    }
    if (t.contains('krise') || t.contains('notfall')) {
      return 'Für Krisen / Notfälle gibt es das Crisis-Modul — schnell '
          'erreichbar über die Notruf-Schaltfläche.';
    }
    return 'Hm, das hat nicht geklappt. Versuch es bitte später noch '
        'einmal — oder schau in den Einstellungen nach.';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigate(String path) {
    Haptics.tap();
    Navigator.of(context).pop();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.80,
        minChildSize: 0.5,
        maxChildSize: 0.80,
        expand: false,
        builder: (_, scrollCtrl) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Bot-Avatar mit Bloom
                      Bloom(
                        color: AppColors.bronze,
                        radius: 14,
                        intensity: 0.4,
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.bronze,
                                AppColors.bronzeSoft,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.bot,
                            size: 20,
                            color: AppColors.voidColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'bot.title'.tr(),
                              style: AppTypography.display(
                                  size: 18, color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                // Online-Dot mit subtle Bloom
                                Bloom(
                                  color: AppColors.leben,
                                  radius: 6,
                                  intensity: 0.6,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.leben,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _sending
                                      ? 'bot.typing'.tr()
                                      : 'common.online'.tr(),
                                  style: AppTypography.label(
                                      size: 10,
                                      color: AppColors.lebenSoft),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x,
                            size: 18, color: AppColors.mute),
                        onPressed: () {
                          Haptics.tap();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05)),
                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _MessageBubble(message: _messages[i]),
                  ),
                ),
                // Quick Suggestions — horizontal scrollable Chips
                if (_messages.length <= 1) ...[
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _SuggestionChip(
                          icon: LucideIcons.map,
                          label: 'bot.suggestionMap'.tr(),
                          onTap: () => _navigate('/dashboard/map'),
                        ),
                        _SuggestionChip(
                          icon: LucideIcons.heartHandshake,
                          label: 'bot.suggestionHelp'.tr(),
                          onTap: () => _navigate(
                              '/dashboard/create?type=help_offered'),
                        ),
                        _SuggestionChip(
                          icon: LucideIcons.user,
                          label: 'bot.suggestionProfile'.tr(),
                          onTap: () => _navigate('/dashboard/profile/edit'),
                        ),
                        _SuggestionChip(
                          icon: LucideIcons.alertTriangle,
                          label: 'bot.suggestionCrisis'.tr(),
                          onTap: () => _navigate('/dashboard/crisis/create'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                // Input
                Container(
                  padding: EdgeInsets.fromLTRB(
                    12, 8, 12, 8 +
                        MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Colors.white
                              .withValues(alpha: 0.05)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          enabled: !_sending,
                          style: AppTypography.body(
                              size: 14, color: AppColors.ink),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.elevated,
                            hintText: 'bot.hint'.tr(),
                            hintStyle: AppTypography.body(
                                size: 13,
                                color: AppColors.mute),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.bronze,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _sending ? null : () => _send(),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: _sending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.voidColor,
                                    ),
                                  )
                                : const Icon(LucideIcons.send,
                                    size: 16,
                                    color: AppColors.voidColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Suggestion-Chip — horizontal scrollende Quick-Prompts
// ─────────────────────────────────────────────────────────────
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bronze.withValues(alpha: 0.10),
              border: Border.all(
                  color: AppColors.bronze.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: AppColors.bronze),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.label(
                      size: 11, color: AppColors.bronze),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bot-Typing-Dots — 3 sequenziell pulsierende Bronze-Dots (1200ms)
// ─────────────────────────────────────────────────────────────
class _BotTypingDots extends StatefulWidget {
  const _BotTypingDots();

  @override
  State<_BotTypingDots> createState() => _BotTypingDotsState();
}

class _BotTypingDotsState extends State<_BotTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Phase je Dot um 0.33 versetzt
              final phase = (_ctrl.value + i * 0.33) % 1.0;
              // Pulse-Kurve: 0 → 1 → 0 über die Phase
              final t = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
              final scale = 0.6 + t * 0.6;
              final alpha = 0.35 + t * 0.55;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.bronze.withValues(alpha: alpha),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final BotMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == 'user';
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    // Bot-Bubble = GlassCard.subtle für cinematic Feel
    if (!mine) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: GlassCard.subtle(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            borderRadius: 14,
            phaseTinted: false,
            child: message.content.isEmpty
                ? const _BotTypingDots()
                : Text(
                    message.content,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      height: 1.45,
                    ),
                  ),
          ),
        ),
      );
    }

    // User-Bubble = Bronze-Tinted (passt zum Mensaena-Bronze-Theme)
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: AppColors.bronze.withValues(alpha: 0.20),
          border: Border.all(
            color: AppColors.bronze.withValues(alpha: 0.45),
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          message.content,
          style: AppTypography.body(
            size: 14,
            color: AppColors.ink,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
