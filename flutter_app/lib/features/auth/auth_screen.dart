import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/shadows.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_tabs.dart';
import 'login_form.dart';
import 'register_form.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      level: AtmosphereLevel.immersive,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Text(
                    'Mensaena',
                    style: MnTypography.display(
                      size: 34,
                      shadows: [
                        Shadow(
                          color: MnColors.amber.withValues(alpha: 0.5),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nachbarschaftshilfe — kostenlos, werbefrei.',
                    style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: MnColors.raised,
                      borderRadius: BorderRadius.circular(MnDimensions.radiusModal),
                      boxShadow: MnShadows.raised,
                      border: Border.all(color: MnColors.line),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: CinemaTabs(
                            controller: _tabs,
                            labels: const ['Anmelden', 'Registrieren'],
                          ),
                        ),
                        SizedBox(
                          height: 540,
                          child: TabBarView(
                            controller: _tabs,
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(20),
                                child: LoginForm(),
                              ),
                              Padding(
                                padding: EdgeInsets.all(20),
                                child: RegisterForm(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
