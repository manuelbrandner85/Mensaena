/// SKILL: mensaena-features
/// Wrapper der live_rooms.room_name → live_rooms.id auflöst und dann
/// LivestreamChat damit rendert. Vermeidet dass live_room_screen
/// direkt mit der DB-uuid arbeiten muss.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import 'livestream_chat.dart';

final _roomIdByNameProvider =
    FutureProvider.autoDispose.family<String?, String>(
        (ref, roomName) async {
  try {
    final row = await sb
        .from('live_rooms')
        .select('id')
        .eq('room_name', roomName)
        .maybeSingle();
    return row?['id'] as String?;
  } catch (_) {
    return null;
  }
});

class LivestreamChatByRoomName extends ConsumerWidget {
  const LivestreamChatByRoomName({required this.roomName, super.key});
  final String roomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_roomIdByNameProvider(roomName));
    return async.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.bronze),
        ),
      ),
      error: (_, __) => SizedBox(
        height: 200,
        child: Center(
          child: Text('live.chatUnavailable'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.mute)),
        ),
      ),
      data: (id) {
        if (id == null) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text('live.chatUnavailable'.tr(),
                  style:
                      AppTypography.body(size: 12, color: AppColors.mute)),
            ),
          );
        }
        return LivestreamChat(roomId: id);
      },
    );
  }
}
