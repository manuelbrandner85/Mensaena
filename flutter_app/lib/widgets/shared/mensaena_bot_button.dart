import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/bot_service.dart';

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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
  final List<BotMessage> _messages = [
    const BotMessage(
      role: 'assistant',
      content:
          'Hallo! 👋 Ich bin der Mensaena-Bot. Wie kann ich helfen? Frag mich nach Modulen, Hilfe, Funktionen — oder sag mir, was du suchst.',
    ),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
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
        _messages[_messages.length - 1] = const BotMessage(
          role: 'assistant',
          content:
              'Hm, das hat nicht geklappt. Versuch es bitte später noch einmal — oder schau in den Einstellungen nach.',
        );
      });
    }
    setState(() => _sending = false);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.bronze,
                              AppColors.bronzeSoft,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.sparkles,
                            size: 18,
                            color: AppColors.voidColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('Mensaena-Bot',
                                style: AppTypography.display(
                                    size: 18,
                                    color: AppColors.ink)),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.leben,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text('Online',
                                    style: AppTypography.label(
                                        size: 9,
                                        color:
                                            AppColors.lebenSoft)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x,
                            size: 18, color: AppColors.mute),
                        onPressed: () => Navigator.pop(context),
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
                // Quick Prompts
                if (_messages.length <= 1) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in const [
                          'Was kann ich hier?',
                          'Hilfe melden',
                          'Wie funktioniert Matching?',
                          'Krise melden',
                        ])
                          GestureDetector(
                            onTap: () {
                              _ctrl.text = p;
                              _send();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.bronze
                                    .withValues(alpha: 0.10),
                                border: Border.all(
                                    color: AppColors.bronze
                                        .withValues(alpha: 0.3)),
                                borderRadius:
                                    BorderRadius.circular(999),
                              ),
                              child: Text(p,
                                  style: AppTypography.label(
                                      size: 10,
                                      color: AppColors.bronze)),
                            ),
                          ),
                      ],
                    ),
                  ),
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
                            hintText: 'Frag mich was…',
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
                          onTap: _sending ? null : _send,
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final BotMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine
              ? AppColors.bronze.withValues(alpha: 0.18)
              : AppColors.elevated,
          border: Border.all(
            color: mine
                ? AppColors.bronze.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.05),
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: message.content.isEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => AnimatedContainer(
                    duration: Duration(milliseconds: 400 + i * 100),
                    width: 6,
                    height: 6,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.bronze,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              )
            : Text(
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
