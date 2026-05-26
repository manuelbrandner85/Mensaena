/// SKILL: mensaena-features (F35)
/// Verifiziertes-Badge: kleines blaues ShieldCheck-Icon neben Name.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({this.size = 14, this.isVerified = true, super.key});
  final double size;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        LucideIcons.shieldCheck,
        size: size,
        color: const Color(0xFF38BDF8),
      ),
    );
  }
}
