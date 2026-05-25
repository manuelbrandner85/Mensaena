import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/conversations_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/supabase_service.dart';
import '../../../services/voice_recorder_service.dart';
import '../../../widgets/shared/image_lightbox.dart';
import '../../../widgets/shared/voice_message_bubble.dart';
import 'chat_action_sheet.dart';

/// SKILL: mensaena-features
/// Chat-Message-Bubble — Text/Image/Voice + Reactions + Reply-Quote
/// + Long-Press-Actions (Reply, Edit, Delete, Pin, React).
class ChatMessageBubble extends ConsumerWidget {
  const ChatMessageBubble({
    required this.json,
    required this.mine,
    required this.conversationId,
    this.showReadReceipt = false,
    this.readByPeer = false,
    this.clustered = false,
    this.onReact,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onPin,
    super.key,
  });
  final Map<String, dynamic> json;
  final bool mine;
  final String conversationId;
  final bool showReadReceipt;
  final bool readByPeer;
  /// True wenn die vorherige Message vom selben Sender innerhalb 60s
  /// kam — Bubble wird enger gestaped (#2 Message-Clustering).
  final bool clustered;
  final Future<bool> Function(String emoji)? onReact;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;

  static final _imgRegex =
      RegExp(r'!\[[^\]]*\]\((https?://[^\s\)]+)\)');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = json['content'] as String? ?? '';
    final at = DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now();
    final editedAt = json['edited_at'] as String?;
    final replyToId = json['reply_to_id'] as String?;
    final deleted = json['deleted_at'] != null;

    // Voice-Message-Detection (Phase 5.2): [VOICE:url:seconds]
    final voiceMsg = VoiceRecorderService.decodeMessage(content);

    // Inline-Image-Match: ![](url) → URL extrahieren, rest = Text
    final imageMatches = _imgRegex.allMatches(content).toList();
    final hasImages = imageMatches.isNotEmpty;
    final textWithoutImages = hasImages
        ? content.replaceAll(_imgRegex, '').trim()
        : content;

    return GestureDetector(
      onLongPress: () {
        Haptics.longPress();
        ChatActionSheet.open(
          context,
          onReact: onReact,
          onReply: onReply,
          onEdit: onEdit,
          onDelete: onDelete,
          onPin: onPin,
          // #5 Copy: nur wenn nicht deleted + textWithoutImages nicht leer.
          onCopy: (!deleted && textWithoutImages.trim().isNotEmpty)
              ? () async {
                  await Clipboard.setData(
                      ClipboardData(text: textWithoutImages.trim()));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: AppColors.surface,
                    duration: const Duration(seconds: 1),
                    content: Text('chat.copied'.tr(),
                        style: AppTypography.body(
                            size: 13, color: AppColors.ink)),
                  ));
                }
              : null,
        );
      },
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          // #2 Clustering: enger Abstand wenn selber Sender < 60s.
          // Plus zusaetzlich top-corner-radius reduzieren bei clustered
          // damit die Bubbles wie eine zusammenhaengende Gruppe wirken.
          margin: EdgeInsets.only(bottom: clustered ? 2 : 6),
          padding: hasImages
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: deleted
                ? AppColors.elevated.withValues(alpha: 0.5)
                : mine
                    ? AppColors.amber.withValues(alpha: 0.2)
                    : AppColors.surface,
            border: Border.all(
              color: deleted
                  ? AppColors.line
                  : mine
                      ? AppColors.amber.withValues(alpha: 0.4)
                      : AppColors.line,
            ),
            borderRadius: BorderRadius.only(
              // Bei clustered: top-corner auf der Side des Senders reduziert
              // damit Bubbles visuell zusammenhaengen.
              topLeft: Radius.circular(clustered && mine ? 14 : (clustered ? 4 : 14)),
              topRight: Radius.circular(clustered && !mine ? 14 : (clustered ? 4 : 14)),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reply-to-Quote
              if (replyToId != null && !deleted) ...[
                _ReplyQuote(messageId: replyToId),
                const SizedBox(height: 6),
              ],
              // Inline-Images (Tap → Lightbox)
              if (hasImages && !deleted)
                for (final m in imageMatches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: GestureDetector(
                      onTap: () => ImageLightbox.open(
                        context,
                        urls: imageMatches
                            .map((m) => m.group(1)!)
                            .toList(),
                        initialIndex:
                            imageMatches.toList().indexOf(m),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: m.group(1)!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 120,
                            color: AppColors.elevated,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.amber),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                              LucideIcons.imageOff,
                              color: AppColors.mute),
                        ),
                      ),
                    ),
                  ),
              // Text
              if (deleted)
                Padding(
                  padding: hasImages
                      ? const EdgeInsets.fromLTRB(8, 4, 8, 4)
                      : EdgeInsets.zero,
                  child: Text(
                    'chat.messageDeleted'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.mute,
                        height: 1.4),
                  ),
                )
              else if (voiceMsg != null)
                // Voice-Message-Bubble statt Text-Render
                VoiceMessageBubble(
                  url: voiceMsg.url,
                  durationSeconds: voiceMsg.durationSeconds,
                  mine: mine,
                )
              else if (textWithoutImages.isNotEmpty)
                Padding(
                  padding: hasImages
                      ? const EdgeInsets.fromLTRB(8, 4, 8, 0)
                      : EdgeInsets.zero,
                  // #6 Emoji-Only Large: wenn die ganze Nachricht nur aus
                  // Emojis besteht (max 3), groesser darstellen ohne
                  // Bubble-Begrenzung. Wirkt wie iMessage/Telegram.
                  child: Text(
                    textWithoutImages,
                    style: _isEmojiOnly(textWithoutImages)
                        ? AppTypography.body(
                            size: 32,
                            color: AppColors.ink,
                            height: 1.2,
                          )
                        : AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            height: 1.4,
                          ),
                  ),
                ),
              const SizedBox(height: 2),
              // Reactions-Pills
              if (!deleted)
                _ReactionsPills(
                  messageId: json['id'] as String,
                  conversationId: conversationId,
                  onTap: onReact,
                  padded: hasImages,
                ),
              // Meta (Zeit, Edited, Read-Receipt)
              Padding(
                padding: hasImages
                    ? const EdgeInsets.fromLTRB(8, 0, 8, 4)
                    : EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(at),
                      style: AppTypography.body(
                          size: 10, color: AppColors.mute),
                    ),
                    if (editedAt != null && !deleted) ...[
                      const SizedBox(width: 4),
                      Text('bearbeitet',
                          style: AppTypography.label(
                              size: 8, color: AppColors.mute)),
                    ],
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        readByPeer
                            ? LucideIcons.checkCheck
                            : LucideIcons.check,
                        size: 11,
                        color: readByPeer
                            ? AppColors.tealSoft
                            : AppColors.mute,
                      ),
                    ],
                  ],
                ),
              ),
              if (showReadReceipt && mine && readByPeer) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: hasImages
                      ? const EdgeInsets.symmetric(horizontal: 8)
                      : EdgeInsets.zero,
                  child: Text('chat.read'.tr(),
                      style: AppTypography.label(
                          size: 8, color: AppColors.tealSoft)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reply-Quote (geladen aus messages-Tabelle) ─────────────────────
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.messageId});
  final String messageId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: MessagesRepository.fetchById(messageId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.elevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('lädt…',
                style: AppTypography.body(
                    size: 11, color: AppColors.mute)),
          );
        }
        final row = snap.data;
        // Wenn die Reply-Quelle null oder soft-deleted ist, zeige
        // expliziten Fallback statt einfach nichts. Sonst wirkt der
        // Reply wie eine zusammenhanglose Nachricht.
        final isDeleted = row == null ||
            row['deleted_at'] != null ||
            ((row['content'] as String?) ?? '').isEmpty;
        final c = isDeleted
            ? 'chat.messageDeleted'.tr()
            : (row['content'] as String? ?? '');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.elevated.withValues(alpha: 0.6),
            border: const Border(
              left: BorderSide(color: AppColors.bronze, width: 2),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('chat.reply'.tr(),
                  style: AppTypography.label(
                      size: 8, color: AppColors.bronzeSoft)),
              Text(
                c.length > 80 ? '${c.substring(0, 80)}…' : c,
                style: AppTypography.body(
                    size: 11,
                    color: isDeleted ? AppColors.mute : AppColors.inkSoft),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Reactions-Pills (gruppiert nach Emoji) ─────────────────────────
class _ReactionsPills extends ConsumerWidget {
  const _ReactionsPills({
    required this.messageId,
    required this.conversationId,
    required this.onTap,
    required this.padded,
  });
  final String messageId;
  final String conversationId;
  final Future<bool> Function(String emoji)? onTap;
  final bool padded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MessagesRepository.watchReactions(conversationId),
      builder: (context, snap) {
        final all = snap.data ?? const <Map<String, dynamic>>[];
        final mine = SupabaseService.currentUser?.id;
        final reactions = all.where((r) => r['message_id'] == messageId);
        if (reactions.isEmpty) return const SizedBox.shrink();
        final counts = <String, int>{};
        final iReacted = <String, bool>{};
        for (final r in reactions) {
          final e = (r['emoji'] as String?) ?? '?';
          counts[e] = (counts[e] ?? 0) + 1;
          if (r['user_id'] == mine) iReacted[e] = true;
        }
        return Padding(
          padding: padded
              ? const EdgeInsets.fromLTRB(8, 4, 8, 0)
              : const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: counts.entries.map((e) {
              final active = iReacted[e.key] == true;
              return InkWell(
                onTap: () => onTap?.call(e.key),
                borderRadius: BorderRadius.circular(999),
                // BUG-FIX #6: 32dp min Touch-Target (mehr Tap-Sicherheit)
                child: Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.bronze.withValues(alpha: 0.22)
                        : AppColors.elevated,
                    border: Border.all(
                      color: active
                          ? AppColors.bronze
                          : AppColors.line,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 3),
                      Text('${e.value}',
                          style: AppTypography.mono(
                              size: 10,
                              color: active
                                  ? AppColors.bronze
                                  : AppColors.inkSoft)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// Heuristik fuer Emoji-Only-Nachrichten (#6): ohne Buchstaben/Zahlen,
/// und max 3 Glyphen Laenge. Variations-Selectors / ZWJ werden ignoriert
/// fuer die Laengen-Pruefung.
bool _isEmojiOnly(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.length > 12) return false; // 3 Emojis × max 4 Codepoints
  // Wenn Buchstaben oder Zahlen drin: kein Pure-Emoji.
  if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(trimmed)) return false;
  // Mind. ein Symbol/Pictographic-Charakter pruefen.
  if (!RegExp(r'\p{Extended_Pictographic}', unicode: true).hasMatch(trimmed)) {
    return false;
  }
  return true;
}
