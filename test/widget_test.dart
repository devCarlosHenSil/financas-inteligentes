import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:financas_inteligentes/theme/theme_controller.dart';
import 'package:financas_inteligentes/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final themeController = ThemeController(
      prefs: prefs,
      initialMode: ThemeMode.light,
    );

    await tester.pumpWidget(MyApp(themeController: themeController));
  });
}
