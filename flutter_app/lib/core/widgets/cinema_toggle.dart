import 'package:flutter/material.dart';

import '../theme/colors.dart';

class CinemaToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const CinemaToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: 'Schalter',
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? MnColors.amber : MnColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: value ? MnColors.amber : MnColors.line,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? MnColors.voidColor : MnColors.mute,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
