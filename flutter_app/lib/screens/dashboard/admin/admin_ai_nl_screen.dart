import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_insights_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// KI-Analytik (Natural Language) — Admin stellt Fragen auf Deutsch und
/// bekommt datenbasierte Antworten ohne SQL zu schreiben.
class AdminAiNlScreen extends ConsumerStatefulWidget {
  const AdminAiNlScreen({super.key});

  @override
  ConsumerState<AdminAiNlScreen> createState() => _AdminAiNlScreenState();
}

class _AdminAiNlScreenState extends ConsumerState<AdminAiNlScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];
  bool _thinking = false;

  static const _suggestions = [
    'adminNl.sug1',
    'adminNl.sug2',
    'adminNl.sug3',
    'adminNl.sug4',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final q = (text ?? _ctrl.text).trim();
    if (q.isEmpty || _thinking) return;
    _ctrl.clear();

    setState(() {
      _messages.add(_Message(text: q, isUser: true));
      _thinking = true;
    });
    _scrollDown();

    try {
      final res = await AiInsightsRepository.nlQuery(q);
      final answer = res['answer'] as String?;
      final error = res['error'] as String?;

      setState(() {
        if (answer != null && answer.isNotEmpty) {
          _messages.add(_Message(text: answer, isUser: false));
        } else {
          _messages.add(_Message(
            text: error != null
                ? 'adminNl.failed'.tr()
                : 'adminNl.failed'.tr(),
            isUser: false,
            isError: true,
          ));
        }
        _thinking = false;
      });
    } catch (_) {
      setState(() {
        _messages.add(_Message(text: 'adminNl.failed'.tr(), isUser: false, isError: true));
        _thinking = false;
      });
    }
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _clear() => setState(() => _messages.clear());

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'adminNl.title'.tr(),
      currentRoute: '/dashboard/admin/nl-analytics',
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.teal.withValues(alpha: 0.06),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Icon(LucideIcons.messageSquare, size: 18, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('adminNl.subtitle'.tr(),
                        style: AppTypography.body(size: 12, color: AppColors.lightMute)),
                  ),
                  if (_messages.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clear,
                      icon: const Icon(LucideIcons.trash2, size: 13),
                      label: Text('adminNl.clear'.tr()),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.lightMute,
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            // Chat
            Expanded(
              child: _messages.isEmpty
                  ? _Suggestions(onTap: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _messages.length + (_thinking ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (_thinking && i == _messages.length) {
                          return _ThinkingBubble();
                        }
                        return _ChatBubble(msg: _messages[i]);
                      },
                    ),
            ),
            // Input
            _InputBar(ctrl: _ctrl, thinking: _thinking, onSend: _send),
          ],
        ),
      ),
    );
  }
}

// ── Suggestions ──────────────────────────────────────────────────────────────

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Icon(LucideIcons.barChart3, size: 40, color: AppColors.teal),
          const SizedBox(height: 12),
          Text('adminNl.placeholder'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 13, color: AppColors.lightMute)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _AdminAiNlScreenState._suggestions.map((key) {
              final label = key.tr();
              return ActionChip(
                label: Text(label, style: AppTypography.body(size: 12)),
                onPressed: () => onTap(label),
                backgroundColor: AppColors.teal.withValues(alpha: 0.08),
                side: BorderSide(color: AppColors.teal.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Chat Bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.msg});
  final _Message msg;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isUser
              ? AppColors.teal
              : msg.isError
                  ? Colors.red.shade50
                  : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Text(
          msg.text,
          style: AppTypography.body(
            size: 13,
            color: msg.isUser
                ? Colors.white
                : msg.isError
                    ? Colors.red.shade700
                    : AppColors.lightInk,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.sparkles, size: 14, color: AppColors.teal),
            const SizedBox(width: 6),
            Text('adminNl.thinking'.tr(),
                style: AppTypography.body(size: 12, color: AppColors.lightMute)),
          ],
        ),
      ),
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({required this.ctrl, required this.thinking, required this.onSend});
  final TextEditingController ctrl;
  final bool thinking;
  final Future<void> Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              enabled: !thinking,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'adminNl.placeholder'.tr(),
                hintStyle: AppTypography.body(size: 13, color: AppColors.lightMute),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: thinking ? null : () => onSend(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: thinking
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.send, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Message {
  const _Message({required this.text, required this.isUser, this.isError = false});
  final String text;
  final bool isUser;
  final bool isError;
}
