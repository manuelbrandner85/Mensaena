/// SKILL: mensaena-design (Higgsfield-Cinematic)
/// DashboardDorfHeader — lebendiger, tageszeitabhängiger Dorf-Header oben
/// im Dashboard. Wählt je nach Uhrzeit ein passendes Higgsfield-Dorf-Still
/// (Morgen-Nebel / Abend-Sonnenuntergang / Nacht-Sterne) und zeigt darüber
/// eine zur Tageszeit passende Begrüßung. Nutzt das bewährte CinematicBackdrop
/// (EffectsGate-integriert, Ken-Burns, crash-sicherer Fallback).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/cinematic_backdrop.dart';

class DashboardDorfHeader extends StatelessWidget {
  const DashboardDorfHeader({super.key});

  ({String asset, String greetKey}) _forHour(int h) {
    if (h >= 5 && h < 11) {
      return (asset: 'assets/images/dorf_morning.webp', greetKey: 'dorfhero.morning');
    }
    if (h >= 11 && h < 18) {
      return (asset: 'assets/images/dorf_dusk.webp', greetKey: 'dorfhero.day');
    }
    if (h >= 18 && h < 22) {
      return (asset: 'assets/images/dorf_dusk.webp', greetKey: 'dorfhero.evening');
    }
    return (asset: 'assets/images/dorf_night.webp', greetKey: 'dorfhero.night');
  }

  @override
  Widget build(BuildContext context) {
    final pick = _forHour(DateTime.now().hour);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 168,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CinematicBackdrop(
                asset: pick.asset,
                topScrim: 0.30,
                bottomScrim: 0.88,
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pick.greetKey.tr(),
                        style: AppTypography.display(
                          size: 24,
                          color: AppColors.ink,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'splash.tagline'.tr(),
                        style: AppTypography.label(
                          size: 10,
                          color: AppColors.bronze,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
