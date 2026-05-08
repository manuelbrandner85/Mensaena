import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/cards.dart';

/// Platzhalter-Seite für Module, die noch portiert werden müssen.
/// Jede dieser Stubs entspricht einer Web-Seite und wird Schritt für
/// Schritt durch eine vollwertige Implementierung ersetzt.
class StubPage extends StatelessWidget {
  const StubPage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            accent: true,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Dieses Modul wird gerade in Flutter portiert. '
                  'Logik, Layout und Verhalten werden 1:1 aus der Web-App übernommen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
