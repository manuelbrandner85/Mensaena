import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// Einheitliche, persistente Fehler-Box für Formulare. Pendant zum inline
/// `_error`-Block des ModuleCreatePostScreen — damit alle Create-Screens
/// Speicher-/Validierungsfehler identisch darstellen (statt mancherorts nur
/// blanker roter Text).
class FormErrorBox extends StatelessWidget {
  const FormErrorBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.herzrot.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.herzrot.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: AppTypography.body(size: 13, color: AppColors.herzrotWarm),
      ),
    );
  }
}
