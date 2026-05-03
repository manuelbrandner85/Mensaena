import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/buttons.dart';

/// Landing-Page – Hero + CTA. Pendant zu /landing.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Mensaena',
                    style: Theme.of(context).textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nachbarschaftshilfe – einfach gemacht.',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  BtnPrimary(
                    onPressed: () => context.go('${Routes.auth}?mode=register'),
                    label: 'Jetzt starten',
                    size: BtnSize.large,
                  ),
                  const SizedBox(height: 12),
                  BtnGhost(
                    onPressed: () => context.go(Routes.auth),
                    label: 'Bereits registriert? Anmelden',
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
