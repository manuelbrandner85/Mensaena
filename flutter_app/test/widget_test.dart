// Smoke-Test: stellt sicher, dass das Theme + Buttons-Widget rendert.
// Der Standard-Test, den `flutter create` generiert, referenziert MyApp –
// unsere App-Klasse heißt MensaenaApp. Diese Datei überschreibt den Default.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mensaena/core/theme/mensaena_theme.dart';
import 'package:mensaena/widgets/buttons.dart';

void main() {
  testWidgets('BtnPrimary rendert mit Label', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MensaenaTheme.dark,
        home: Scaffold(
          body: BtnPrimary(onPressed: () {}, label: 'Test'),
        ),
      ),
    );
    expect(find.text('Test'), findsOneWidget);
  });
}
