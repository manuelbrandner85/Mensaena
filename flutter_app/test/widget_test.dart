import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mensaena/config/theme/app_colors.dart';
import 'package:mensaena/config/theme/app_theme.dart';

/// Smoke-Tests: stellt sicher, dass das Theme + die Cinema-Dark-Palette
/// korrekt aufgebaut sind. SupabaseService.init() wird hier bewusst NICHT
/// aufgerufen — die Tests laufen ohne Netzwerk.
void main() {
  testWidgets('AppTheme.dark wird angewendet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Text('Mensaena')),
      ),
    );
    expect(find.text('Mensaena'), findsOneWidget);
  });

  test('Cinema-Dark-Palette: Brand-Akzente stabil', () {
    expect(AppColors.amber, const Color(0xFFF59E0B));
    expect(AppColors.voidColor, const Color(0xFF0A0F1C));
    expect(AppColors.herzrot, const Color(0xFFEF4444));
    expect(AppColors.leben, const Color(0xFF22C55E));
  });

  test('AppTheme.dark hat dunkles ColorScheme', () {
    final t = AppTheme.dark;
    expect(t.brightness, Brightness.dark);
    expect(t.colorScheme.brightness, Brightness.dark);
  });
}
