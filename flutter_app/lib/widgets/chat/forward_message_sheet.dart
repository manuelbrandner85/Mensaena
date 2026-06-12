/// SKILL: mensaena-features (Phase 2 F7)
/// Forward-Message-Picker: wählt eine Ziel-Konversation aus den eigenen
/// DMs/Channels und sendet eine Kopie der Original-Message mit
/// [FORWARDED]-Prefix.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/conversations_repository.dart';
import '../../services/haptics.dart';
import '../../services/supabase_service.dart';
import '../shared/sized_avatar_image.dart';

class ForwardMessageSheet extends ConsumerStatefulWidget {
  const ForwardMessageSheet({
    required this.originalContent,
    required this.fromConversationId,
    super.key,
  });

  final String originalContent;
  final String fromConversationId;

  static Future<void> show(
    BuildContext context, {
    required String originalContent,
    required String fromConversationId,
  }) async {
    Haptics.tap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => ForwardMessageSheet(
          originalContent: originalContent,
          fromConversationId: fromConversationId,
        ),
      ),
    );
  }

  @override
  ConsumerState<ForwardMessageSheet> createState() =>
      _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends ConsumerState<ForwardMessageSheet> {
  final _search = TextEditingController();
  String _q = '';
  Future<List<Map<String, dynamic>>>? _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = ConversationsRepository.listMine();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _forwardTo(String convId, String title) async {
    if (_sending) return;
    setState(() => _sending = true);
    Haptics.confirm();
    try {
      final me = SupabaseService.currentUser?.id;
      if (me == null) return;
      await MessagesRepository.forward(
        conversationId: convId,
        content: '[FORWARDED]\n${widget.originalContent}',
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'chat.forwardedTo'.tr(namedArgs: {'name': title}),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'chat.forwardFailed'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.herzrotWarm),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(LucideIcons.share2, color: AppColors.bronze),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'chat.forwardTitle'.tr(),
                    style: AppTypography.body(
                      size: 16,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'chat.forwardSearchHint'.tr(),
                hintStyle: AppTypography.caption(),
                prefixIcon: const Icon(LucideIcons.search,
                    size: 16, color: AppColors.mute),
                filled: true,
                fillColor: AppColors.elevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.amber),
                  );
                }
                final all = snap.data ?? const <Map<String, dynamic>>[];
                final list = all.where((c) {
                  if (c['id'] == widget.fromConversationId) return false;
                  if (_q.isEmpty) return true;
                  final t =
                      (c['display_title'] as String? ?? '').toLowerCase();
                  return t.contains(_q);
                }).toList();
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'chat.forwardNoTargets'.tr(),
                        style: AppTypography.body(
                            size: 13, color: AppColors.mute),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final id = c['id'] as String;
                    final title = (c['display_title'] as String?) ??
                        'common.unknown'.tr();
                    final avatar = c['peer_avatar_url'] as String?;
                    final emoji = c['emoji'] as String?;
                    return ListTile(
                      leading: emoji != null
                          ? Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.elevated,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 22)),
                            )
                          : SizedAvatarImage(
                              url: avatar,
                              size: 40,
                              fallbackInitial: title,
                            ),
                      title: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                              size: 14, color: AppColors.ink)),
                      trailing: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.bronze))
                          : const Icon(LucideIcons.send,
                              size: 16, color: AppColors.bronze),
                      onTap: _sending ? null : () => _forwardTo(id, title),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
