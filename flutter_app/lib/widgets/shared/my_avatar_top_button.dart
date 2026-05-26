/// SKILL: mensaena-features (UX-Welle1 P1)
/// Avatar oben rechts in der AppBar — 1-Tap zum eigenen Profil.
/// Bronze-Ring-Glow im Cinema-Hyperreal-Stil.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/supabase_service.dart';

final _myAvatarUrlProvider = FutureProvider.autoDispose<String?>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return null;
  try {
    final p = await ProfilesRepository.getMine();
    return p?.avatarUrl;
  } catch (_) {
    return null;
  }
});

class MyAvatarTopButton extends ConsumerWidget {
  const MyAvatarTopButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const SizedBox.shrink();
    final avatar = ref.watch(_myAvatarUrlProvider).maybeWhen(
          data: (u) => u,
          orElse: () => null,
        );
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/dashboard/profile/$uid'),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Cinema-Bronze-Ring + leichter Glow.
            border: Border.all(
                color: AppColors.bronze.withValues(alpha: 0.55), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.bronze.withValues(alpha: 0.18),
                blurRadius: 6,
              ),
            ],
          ),
          child: ClipOval(
            child: avatar != null
                ? CachedNetworkImage(
                    imageUrl: avatar,
                    width: 30,
                    height: 30,
                    memCacheWidth: 60,
                    memCacheHeight: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallback(),
                  )
                : _fallback(),
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.elevated,
        alignment: Alignment.center,
        child: const Text('?',
            style: TextStyle(
                color: AppColors.bronze, fontWeight: FontWeight.w700)),
      );
}
