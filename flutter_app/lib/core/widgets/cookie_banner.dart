import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';
import 'glow_button.dart';

const _cookieAcceptedKey = 'cinema.cookie_accepted_v1';

class CookieBanner extends StatefulWidget {
  const CookieBanner({super.key});

  @override
  State<CookieBanner> createState() => _CookieBannerState();
}

class _CookieBannerState extends State<CookieBanner> {
  bool? _accepted;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _accepted = p.getBool(_cookieAcceptedKey) ?? false);
    });
  }

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cookieAcceptedKey, true);
    if (mounted) setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted == null || _accepted == true) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MnColors.raised.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                border: Border.all(color: MnColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Wir verwenden technisch notwendige Daten fuer Auth und Realtime.',
                    style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GlowButton(
                        label: 'Datenschutz',
                        variant: GlowVariant.ghost,
                        compact: true,
                        onPressed: () => GoRouter.of(context).push('/datenschutz'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GlowButton(
                          label: 'Verstanden',
                          variant: GlowVariant.primary,
                          compact: true,
                          fullWidth: true,
                          onPressed: _accept,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
