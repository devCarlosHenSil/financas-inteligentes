// test/widget_test.dart
//
// Smoke test do Finanças Inteligentes.
// Verifica que o app inicializa sem crash quando Firebase não está disponível.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:financas_inteligentes/main.dart';
import 'package:financas_inteligentes/theme/theme_controller.dart';

void main() {
  testWidgets('App smoke test — inicializa sem crash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final themeController = ThemeController(
      prefs: prefs,
      initialMode: ThemeController.resolveThemeMode(prefs),
    );

    await tester.pumpWidget(
      MyApp(
        startupError: 'Firebase não disponível em ambiente de teste.',
        themeController: themeController,
      ),
    );

    await tester.pump();

    expect(find.text('Falha ao iniciar app'), findsOneWidget);
  });
}
