/// SKILL: mensaena-features (Phase 10 E3)
/// SkyWidget — kombiniert Weather + Moon + Sun in einem PageView.
/// 3 Seiten + Dot-Indicator. Spart 2 Slots auf dem Dashboard und
/// erlaubt schnellen Swipe zwischen den 3 Himmel-Datenquellen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import 'moon_widget.dart';
import 'sun_widget.dart';
import 'weather_widget.dart';

class SkyWidget extends ConsumerStatefulWidget {
  const SkyWidget({required this.lat, required this.lng, super.key});
  final double lat;
  final double lng;

  @override
  ConsumerState<SkyWidget> createState() => _SkyWidgetState();
}

class _SkyWidgetState extends ConsumerState<SkyWidget> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              WeatherWidget(lat: widget.lat, lng: widget.lng),
              const SunWidget(),
              const MoonWidget(),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final active = i == _page;
            return GestureDetector(
              onTap: () => _ctrl.animateToPage(
                i,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.bronze
                      : AppColors.mute.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
