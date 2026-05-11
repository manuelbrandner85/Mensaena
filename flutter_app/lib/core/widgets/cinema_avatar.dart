import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

enum AvatarSize { xs, sm, md, lg, xl }

enum PresenceState { online, available, offline }

/// Profile-Orb mit Ring (Presence) + CachedNetworkImage Fallback.
class CinemaAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? displayName;
  final AvatarSize size;
  final PresenceState presence;
  final VoidCallback? onTap;

  const CinemaAvatar({
    super.key,
    this.imageUrl,
    this.displayName,
    this.size = AvatarSize.md,
    this.presence = PresenceState.offline,
    this.onTap,
  });

  double get _dim {
    switch (size) {
      case AvatarSize.xs: return MnDimensions.avatarXs;
      case AvatarSize.sm: return MnDimensions.avatarSm;
      case AvatarSize.md: return MnDimensions.avatarMd;
      case AvatarSize.lg: return MnDimensions.avatarLg;
      case AvatarSize.xl: return MnDimensions.avatarXl;
    }
  }

  Color get _ringColor {
    switch (presence) {
      case PresenceState.online: return MnColors.leben;
      case PresenceState.available: return MnColors.amber;
      case PresenceState.offline: return MnColors.line;
    }
  }

  String get _initials {
    final n = (displayName ?? '').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dim = _dim;
    final hasImage = (imageUrl ?? '').isNotEmpty;
    final ringPulse = presence == PresenceState.online;

    final orb = Container(
      width: dim,
      height: dim,
      decoration: BoxDecoration(
        color: MnColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: _ringColor, width: 2),
        boxShadow: ringPulse
            ? [
                BoxShadow(color: MnColors.leben.withValues(alpha: 0.4), blurRadius: 10),
              ]
            : null,
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: MnColors.elevated),
                errorWidget: (_, __, ___) => _initialsWidget(dim),
              )
            : _initialsWidget(dim),
      ),
    );

    return Semantics(
      label: displayName ?? 'Profil',
      button: onTap != null,
      child: onTap == null
          ? orb
          : InkWell(
              borderRadius: BorderRadius.circular(dim),
              onTap: onTap,
              child: orb,
            ),
    );
  }

  Widget _initialsWidget(double dim) => Center(
        child: Text(
          _initials,
          style: MnTypography.body(
            size: dim * 0.4,
            color: MnColors.mute,
            weight: FontWeight.w600,
          ),
        ),
      );
}
