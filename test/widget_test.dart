// test/widget_test.dart
//
// Testa que MyApp renderiza sem travar quando Firebase não está disponível.
// Usa startupError para simular o caminho de erro sem precisar do Firebase real.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_inteligentes/main.dart';

void main() {
  testWidgets('App exibe tela de erro quando startupError não é nulo',
      (WidgetTester tester) async {
    // Passa um erro simulado — evita chamar Firebase.initializeApp()
    await tester.pumpWidget(
      const MyApp(startupError: 'Firebase indisponivel no teste'),
    );
    await tester.pump();

    // Com startupError preenchido, deve mostrar a tela de erro de startup
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Falha ao iniciar app'), findsOneWidget);
  });

  testWidgets('App exibe tela de erro com mensagem legível',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(startupError: 'no-app'),
    );
    await tester.pump();

    expect(find.textContaining('Firebase'), findsAtLeastNWidgets(1));
  });
}
