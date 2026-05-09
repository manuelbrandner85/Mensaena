import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import 'mandatory_update_screen.dart';
import 'update_service.dart';

/// Wrapper, der die App-UI blockiert solange ein Pflicht-Update aussteht.
/// Während des Initial-Checks wird ein dezenter Splash gezeigt.
/// Was-ist-Neu-Sheet wird separat im AppShell getriggert (braucht
/// einen Material-Context unterhalb von MaterialApp.router).
class UpdateGate extends ConsumerWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCheck = ref.watch(updateCheckProvider);
    return asyncCheck.when(
      loading: () => const _UpdateSplash(),
      error: (e, _) => child,
      data: (state) {
        if (state.mandatoryRelease != null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Theme.of(context),
            home: MandatoryUpdateScreen(release: state.mandatoryRelease!),
          );
        }
        return child;
      },
    );
  }
}

class _UpdateSplash extends StatelessWidget {
  const _UpdateSplash();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary500, AppColors.primary700],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
