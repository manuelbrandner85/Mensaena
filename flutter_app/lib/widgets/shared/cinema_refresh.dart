/// SKILL: mensaena-design
/// Einheitliches, gebrandetes Pull-to-Refresh im Cinema-Look (Bronze auf
/// dunkler Glass-Fläche). Ein Wrapper statt pro Screen RefreshIndicator-
/// Styling zu wiederholen.
library;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class CinemaRefresh extends StatelessWidget {
  const CinemaRefresh({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.bronze,
      backgroundColor: AppColors.surface,
      strokeWidth: 2.6,
      displacement: 44,
      child: child,
    );
  }
}
