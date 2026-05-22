import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mensaena/config/theme/app_theme.dart';

/// Smoke-Test: stellt sicher, dass AppTheme.dark instantiierbar ist.
/// SupabaseService.init() wird hier bewusst NICHT aufgerufen — der Test
/// laeuft ohne Netzwerk.
void main() {
  testWidgets('AppTheme.dark wird angewendet', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Text('Mensaena')),
      ),
    );
    expect(find.text('Mensaena'), findsOneWidget);
  });
}
