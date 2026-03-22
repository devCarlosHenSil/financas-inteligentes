import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_inteligentes/main.dart';

void main() {
  testWidgets('App inicializa sem erro de startup', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(startupError: null));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
