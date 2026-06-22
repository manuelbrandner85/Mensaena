import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/conversations_repository.dart';
import '../../../repositories/profiles_repository.dart';
import '../../../services/dm_call_service.dart';
import '../../../services/haptics.dart';
import '../../../services/link_preview_service.dart';
import '../../../services/safe_url.dart';
import '../../../services/supabase_service.dart';
import '../../../services/voice_recorder_service.dart';
import '../../../widgets/chat/chat_link_preview_card.dart';
import '../../../widgets/chat/post_card_chat_bubble.dart';
import '../../../widgets/shared/image_lightbox.dart';
import '../../../widgets/shared/translate_button.dart';
import '../../../widgets/shared/voice_message_bubble.dart';
import 'chat_action_sheet.dart';
import '../../../widgets/shared/app_snackbar.dart';

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
    this.onForward,
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
  final VoidCallback? onForward;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;

  static final _imgRegex =
      RegExp(r'!\[[^\]]*\]\((https?://[^\s\)]+)\)');
  // PERF (Audit): vorher wurden _callRegex/_sysRegex pro build() neu
  // kompiliert. Bei 100 Bubbles auf dem Screen = 200 RegExp-Kompilierungen
  // pro Scroll-Frame → 50–80ms Frame-Spike. Static final = einmal pro
  // Prozess.
  static final _callRegex =
      RegExp(r'^\[SYSTEM_CALL:([a-z]+):([^:]*):([0-9]+):([^\]]*)\]$');
  static final _sysRegex = RegExp(r'^\[SYSTEM(?::([\w_]+))?\]\s*(.*)$');
  static final _forwardedRegex = RegExp(r'^\[FORWARDED\]\n?');
  // Standort-Nachricht: [LOC:lat:lng] → tippbare Karten-Vorschau.
  static final _locRegex =
      RegExp(r'^\[LOC:(-?\d+(?:\.\d+)?):(-?\d+(?:\.\d+)?)\]$');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = json['content'] as String? ?? '';
    final at = DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
        DateTime.now();
    final editedAt = json['edited_at'] as String?;
    final replyToId = json['reply_to_id'] as String?;
    final deleted = json['deleted_at'] != null;

    // System-Call-Cards — Pattern [SYSTEM_CALL:type:callId:durationSec:peerName]
    // wird als zentrierte Karte mit Icon/Label/Dauer/Rueckruf-Button gerendert.
    // MUSS vor der generischen SYSTEM-Detection laufen weil die Regex
    // ansonsten "SYSTEM_CALL" als type interpretieren wuerde.
    final callMatch = _callRegex.firstMatch(content.trim());
    if (callMatch != null && !deleted) {
      return _SystemCallCard(
        type: callMatch.group(1) ?? 'ended',
        callId: callMatch.group(2) ?? '',
        durationSec: int.tryParse(callMatch.group(3) ?? '0') ?? 0,
        peerName: callMatch.group(4) ?? '',
        conversationId: conversationId,
        viewerIsMine: mine,
      );
    }

    // Standort-Karte — Pattern [LOC:lat:lng] → tippbare Vorschau, öffnet
    // die Karte extern. MUSS vor der SYSTEM-Detection laufen.
    final locMatch = _locRegex.firstMatch(content.trim());
    if (locMatch != null && !deleted) {
      final lat = double.tryParse(locMatch.group(1) ?? '');
      final lng = double.tryParse(locMatch.group(2) ?? '');
      if (lat != null && lng != null) {
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: _LocationCard(lat: lat, lng: lng, mine: mine),
        );
      }
    }

    // #15 System-Messages — Pattern [SYSTEM:type] body wird als zentrierte
    // gedimmte Pill gerendert statt normale Bubble.
    final sysMatch = _sysRegex.firstMatch(content);
    if (sysMatch != null && !deleted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.elevated.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.5), width: 0.5),
            ),
            child: Text(
              sysMatch.group(2) ?? '',
              style: AppTypography.label(
                size: 10,
                color: AppColors.mute,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Voice-Message-Detection (Phase 5.2): [VOICE:url:seconds]
    final voiceMsg = VoiceRecorderService.decodeMessage(content);

    // Inline-Image-Match: ![](url) → URL extrahieren, rest = Text
    final imageMatches = _imgRegex.allMatches(content).toList();
    final hasImages = imageMatches.isNotEmpty;
    final textWithoutImages = hasImages
        ? content.replaceAll(_imgRegex, '').trim()
        : content;

    // Erste HTTP/HTTPS-URL für Link-Vorschau extrahieren. Hat ein Treffer
    // existiert, rendern wir unter dem Text eine ChatLinkPreviewCard
    // (Open-Graph/Twitter-Meta — siehe services/link_preview_service.dart).
    final previewUrl = LinkPreviewService.firstUrl(textWithoutImages);

    // #4 Swipe-to-Reply: nach RECHTS wischen → Reply-Modus mit Haptic.
    // Dismissible mit confirmDismiss=false damit Widget nicht entfernt
    // wird, dafuer onUpdate haptisch + onDismissed-like fuer reply.
    return Dismissible(
      key: ValueKey('msg_swipe_${json['id']}'),
      direction: onReply != null
          ? DismissDirection.startToEnd
          : DismissDirection.none,
      dismissThresholds: const {DismissDirection.startToEnd: 0.25},
      confirmDismiss: (_) async {
        Haptics.tap();
        onReply?.call();
        return false; // keep widget
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(LucideIcons.cornerUpLeft,
            size: 18, color: AppColors.bronze.withValues(alpha: 0.7)),
      ),
      child: GestureDetector(
      onLongPress: () {
        Haptics.longPress();
        ChatActionSheet.open(
          context,
          onReact: onReact,
          onReply: onReply,
          onForward: onForward,
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
            // Perf: sizeOf statt of(context) — granulare Subscription auf
            // Size only, kein Rebuild bei Padding/Locale-Changes.
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
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
                          memCacheWidth: 600,
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
              else if (_postCardId(textWithoutImages) != null)
                // F26: Auto-Postcard als erste Nachricht aus Post-Kontakt.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: PostCardChatBubble(
                      postId: _postCardId(textWithoutImages)!),
                )
              else if (_callInviteRoom(textWithoutImages) != null)
                // Gruppen-Anruf wurde entfernt — alte [CALL_INVITE]-Marker
                // werden als inerter Hinweis dargestellt (keine Navigation).
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'group_call.removedNotice'.tr(),
                    style: AppTypography.caption(),
                  ),
                )
              else if (textWithoutImages.startsWith('[FORWARDED]'))
                // F7: Weitergeleitete Nachricht — Header + Original-Text.
                Padding(
                  padding: hasImages
                      ? const EdgeInsets.fromLTRB(8, 4, 8, 0)
                      : EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(LucideIcons.cornerUpRight,
                            size: 11, color: AppColors.bronze),
                        const SizedBox(width: 4),
                        Text(
                          'chat.forwarded'.tr(),
                          style: AppTypography.label(
                              size: 9, color: AppColors.bronze),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      _MentionAwareText(
                        text: textWithoutImages
                            .replaceFirst(_forwardedRegex, ''),
                        baseStyle: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          height: 1.35,
                        ),
                      ),
                      if (previewUrl != null)
                        ChatLinkPreviewCard(url: previewUrl),
                    ],
                  ),
                )
              else if (textWithoutImages.isNotEmpty)
                Padding(
                  padding: hasImages
                      ? const EdgeInsets.fromLTRB(8, 4, 8, 0)
                      : EdgeInsets.zero,
                  // #6 Emoji-Only Large: wenn die ganze Nachricht nur aus
                  // Emojis besteht (max 3), groesser darstellen ohne
                  // Bubble-Begrenzung. Wirkt wie iMessage/Telegram.
                  // Falls eine URL im Text steht, Link-Preview-Card direkt
                  // unter dem Text als zweites Column-Kind.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isEmojiOnly(textWithoutImages)
                          ? Text(
                              textWithoutImages,
                              style: AppTypography.body(
                                size: 32,
                                color: AppColors.ink,
                                height: 1.2,
                              ),
                            )
                          : _MentionAwareText(
                              text: textWithoutImages,
                              baseStyle: AppTypography.body(
                                size: 14,
                                color: AppColors.ink,
                                height: 1.4,
                              ),
                            ),
                      // C) Übersetzen — nur fremde Text-Nachrichten (kein Emoji-Only).
                      if (!mine && !_isEmojiOnly(textWithoutImages))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: TranslateInlineButton(text: textWithoutImages),
                        ),
                      if (previewUrl != null)
                        ChatLinkPreviewCard(url: previewUrl),
                    ],
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
                      Text('chat.editedTag'.tr(),
                          style: AppTypography.label(
                              size: 8, color: AppColors.inkSoft)),
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
            child: Text('common.loading'.tr(),
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

// ── System-Call-Card (zentriert, mit Icon + optional Rueckruf) ──────
class _SystemCallCard extends StatelessWidget {
  const _SystemCallCard({
    required this.type,
    required this.callId,
    required this.durationSec,
    required this.peerName,
    required this.conversationId,
    required this.viewerIsMine,
  });

  final String type;
  final String callId;
  final int durationSec;
  final String peerName;
  final String conversationId;

  /// True wenn der Viewer der urspruengliche Anrufer war. Wird nur
  /// genutzt um den Rueckruf-Button bei verpassten Anrufen zu
  /// unterdruecken (wenn DU angerufen hast und der andere verpasste,
  /// dann wuerdest du dich beim Tap selbst nochmal anrufen).
  final bool viewerIsMine;

  IconData get _icon {
    switch (type) {
      case 'missed':
        return LucideIcons.phoneMissed;
      case 'cancelled':
      case 'declined':
        return LucideIcons.phoneOff;
      default:
        return LucideIcons.phone;
    }
  }

  Color get _color {
    switch (type) {
      case 'missed':
        return AppColors.herzrot;
      case 'cancelled':
        return AppColors.amber;
      case 'declined':
        return AppColors.mute;
      default:
        return AppColors.lebenSoft;
    }
  }

  String _label() {
    switch (type) {
      case 'missed':
        return 'systemCall.missed'.tr();
      case 'cancelled':
        return 'systemCall.cancelled'.tr();
      case 'declined':
        return 'systemCall.declined'.tr();
      default:
        return 'systemCall.ended'.tr();
    }
  }

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  Future<void> _callBack(BuildContext context) async {
    Haptics.tap();
    // Peer-ID via dm_calls lookup — sicherer als den Namen zu nutzen.
    try {
      final peer = await DmCallService.peerOf(callId);
      final peerId = peer.peerId;
      if (peerId == null || peerId.isEmpty) return;
      final result = await DmCallService.start(
        conversationId: conversationId,
        calleeId: peerId,
        callType: peer.callType,
      );
      if (!context.mounted) return;
      if (!result.success ||
          result.callId == null ||
          result.roomName == null) {
        AppSnackBar.info(context, result.errorReason ?? 'systemCall.callbackFailed'.tr());
        return;
      }
      final encPeer = Uri.encodeComponent(peerName);
      final encRoom = Uri.encodeComponent(result.roomName!);
      context.push(
          '/dashboard/call/${result.callId}?room=$encRoom&peer=$encPeer');
    } catch (_) {/* fail-silent */}
  }

  @override
  Widget build(BuildContext context) {
    final showCallback = type == 'missed' && !viewerIsMine;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.elevated.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 18, color: _color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(),
                  style: AppTypography.body(
                    size: 12,
                    color: AppColors.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                if (durationSec > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      'systemCall.duration'
                          .tr(namedArgs: {'d': _formatDuration(durationSec)}),
                      style:
                          AppTypography.label(size: 9, color: AppColors.mute),
                    ),
                  ),
              ],
            ),
            if (showCallback) ...[
              const SizedBox(width: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _callBack(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.leben.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.leben.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.phone,
                          size: 11, color: AppColors.leben),
                      const SizedBox(width: 4),
                      Text(
                        'systemCall.callback'.tr(),
                        style: AppTypography.label(
                            size: 10, color: AppColors.leben),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// F26: Erkennt `[POSTCARD:<uuid>]`-Marker und gibt die postId zurück,
/// sonst null. Auto-Kontaktkarte bei DM-aus-Post.
final _postCardRegex = RegExp(
    r'^\[POSTCARD:([0-9a-fA-F-]{36})\]$',
    multiLine: false);
String? _postCardId(String s) {
  final m = _postCardRegex.firstMatch(s.trim());
  return m?.group(1);
}

/// F13: Erkennt `[CALL_INVITE:<roomName>]`-Marker und gibt den
/// LiveKit-Room-Namen zurück.
final _callInviteRegex = RegExp(
    r'^\[CALL_INVITE:([a-zA-Z0-9_-]{4,80})\]$',
    multiLine: false);
String? _callInviteRoom(String s) {
  final m = _callInviteRegex.firstMatch(s.trim());
  return m?.group(1);
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

/// Rendert Text mit @mentions als bronze-highlighted spans.
/// Stateful damit TapGestureRecognizer pro Mention nur 1x erzeugt +
/// in dispose() abgeräumt wird (LEAK-Fix: pro Bubble-Rebuild wurde
/// vorher ein neuer Recognizer leak't → App hängte nach längerem Chat).
class _MentionAwareText extends StatefulWidget {
  const _MentionAwareText({required this.text, required this.baseStyle});
  final String text;
  final TextStyle baseStyle;

  static final _re = RegExp(r'@([\p{L}0-9._-]+)', unicode: true);

  @override
  State<_MentionAwareText> createState() => _MentionAwareTextState();
}

class _MentionAwareTextState extends State<_MentionAwareText> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<InlineSpan>? _spans;
  String? _builtFor;

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  Future<void> _openMention(String name) async {
    final id = await ProfilesRepository.idByDisplayName(name);
    if (id == null || !mounted) return;
    GoRouter.of(context).go('/dashboard/profile/$id');
  }

  void _buildSpans() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    int last = 0;
    final text = widget.text;
    for (final m in _MentionAwareText._re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, m.start),
          style: widget.baseStyle,
        ));
      }
      final name = m.group(1) ?? '';
      final rec = TapGestureRecognizer()..onTap = () => _openMention(name);
      _recognizers.add(rec);
      spans.add(TextSpan(
        text: m.group(0),
        style: widget.baseStyle.copyWith(
          color: AppColors.bronze,
          fontWeight: FontWeight.w700,
        ),
        recognizer: rec,
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: widget.baseStyle));
    }
    _spans = spans;
    _builtFor = text;
  }

  @override
  Widget build(BuildContext context) {
    // Spans nur neu bauen wenn Text sich geändert hat — Recognizers
    // bleiben sonst stabil über Parent-Rebuilds.
    if (_builtFor != widget.text) {
      _buildSpans();
    }
    if (_spans == null || _spans!.isEmpty) {
      return Text(widget.text, style: widget.baseStyle);
    }
    return RichText(text: TextSpan(children: _spans));
  }
}

/// Standort-Karte für [LOC:lat:lng]-Nachrichten. Zeigt eine kompakte
/// Vorschau (Pin + Koordinaten) und öffnet bei Tap die Karte extern
/// (Google Maps). Bewusst KEINE inline-Karte pro Bubble (Perf in langen
/// Listen) — die externe Karte ist die robuste WhatsApp-ähnliche Lösung.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.lat, required this.lng, required this.mine});
  final double lat;
  final double lng;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final coords =
        '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => safeLaunchUrl(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        ),
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            color: AppColors.elevated.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.bronze.withValues(alpha: 0.35), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stilisierter „Karten"-Streifen mit Pin (kein Netzwerk-Tile).
              Container(
                height: 84,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(13)),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.bronze.withValues(alpha: 0.22),
                      AppColors.bronze.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(LucideIcons.mapPin,
                      size: 34, color: AppColors.bronze),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('chat.location_message'.tr(),
                              style: AppTypography.label(
                                  size: 12, color: AppColors.ink)),
                          const SizedBox(height: 2),
                          Text(coords,
                              style: AppTypography.caption(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.externalLink,
                        size: 16, color: AppColors.bronze),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
