// test/widgets/login_screen_test.dart
//
// _FakeAuth estende ChangeNotifier diretamente — sem herdar AuthProvider real,
// sem conflito com firebase_auth.AuthProvider.
// O provider é registrado como o tipo concreto _FakeAuth, exposto via
// ChangeNotifierProvider<app.AuthProvider> usando alias de import.

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:financas_inteligentes/providers/auth_provider.dart'
    as app show AuthProvider;
import 'package:financas_inteligentes/screens/login_screen.dart';

// ── Fake completamente isolado do Firebase ────────────────────────────────────

class _FakeAuth extends ChangeNotifier implements app.AuthProvider {
  _FakeAuth({bool simulateSuccess = true})
      : _simulateSuccess = simulateSuccess;

  final bool _simulateSuccess;

  bool signInCalled    = false;
  bool registerCalled  = false;

  @override User?   get user                 => null;
  @override bool    get isLoading            => false;
  @override bool    get isAuthenticated      => false;
  @override String? get errorMessage         => null;
  @override String? get photoUrl             => null;
  @override String? get currentProvider      => null;
  @override bool    get appleSignInAvailable => false;
  @override String  get displayLabel         => 'Teste';
  @override String  get displayInitial       => 'T';

  @override
  Future<bool> signIn({required String email, required String password}) async {
    signInCalled = true;
    return _simulateSuccess;
  }

  @override
  Future<bool> register({required String email, required String password}) async {
    registerCalled = true;
    return _simulateSuccess;
  }

  @override Future<bool> signInWithGoogle() async => _simulateSuccess;
  @override Future<bool> signInWithApple()  async => _simulateSuccess;
  @override Future<void> signOut()          async {}
  @override void clearError() {}
}

// ── Helper de montagem ────────────────────────────────────────────────────────

Widget _buildLoginScreen(_FakeAuth auth) {
  return MaterialApp(
    home: ChangeNotifierProvider<app.AuthProvider>.value(
      value: auth,
      child: const LoginScreen(),
    ),
  );
}

// ── Testes ────────────────────────────────────────────────────────────────────

void main() {
  group('LoginScreen — renderização', () {
    testWidgets('exibe campo de e-mail', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuth()));
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('exibe campo de senha', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuth()));
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('exibe botão Entrar', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuth()));
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('exibe botão Criar conta', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuth()));
      expect(find.text('Criar conta'), findsOneWidget);
    });

    testWidgets('exibe botão Continuar com Google', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuth()));
      expect(find.text('Continuar com Google'), findsOneWidget);
    });

    testWidgets('NAO exibe botão Apple em plataforma nao-iOS', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuth()));
      expect(find.text('Continuar com Apple'), findsNothing);
    });

    testWidgets('exibe icone de carteira no topo', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuth()));
      expect(
        find.byIcon(Icons.account_balance_wallet_rounded),
        findsOneWidget,
      );
    });
  });

  group('LoginScreen — validacao de campos vazios', () {
    testWidgets('exibe SnackBar quando e-mail vazio ao clicar Entrar',
        (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(_buildLoginScreen(auth));
      await tester.tap(find.text('Entrar'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(auth.signInCalled, isFalse);
    });

    testWidgets('exibe SnackBar quando senha vazia ao clicar Entrar',
        (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(_buildLoginScreen(auth));
      await tester.enterText(find.byType(TextField).first, 'usuario@teste.com');
      await tester.tap(find.text('Entrar'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(auth.signInCalled, isFalse);
    });

    testWidgets('exibe SnackBar quando campos vazios ao clicar Criar conta',
        (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(_buildLoginScreen(auth));
      await tester.tap(find.text('Criar conta'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(auth.registerCalled, isFalse);
    });
  });

  group('LoginScreen — interacao com campos preenchidos', () {
    testWidgets('chama signIn quando e-mail e senha preenchidos', (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(_buildLoginScreen(auth));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'usuario@teste.com');
      await tester.enterText(fields.at(1), 'senha123');
      await tester.tap(find.text('Entrar'));
      await tester.pump();
      expect(auth.signInCalled, isTrue);
    });

    testWidgets('chama register quando campos preenchidos e clica Criar conta',
        (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(_buildLoginScreen(auth));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'novo@teste.com');
      await tester.enterText(fields.at(1), 'senha456');
      await tester.tap(find.text('Criar conta'));
      await tester.pump();
      expect(auth.registerCalled, isTrue);
    });
  });

  group('LoginScreen — visibilidade da senha', () {
    testWidgets('senha comeca oculta (obscureText)', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuth()));
      final senhaField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(senhaField.obscureText, isTrue);
    });

    testWidgets('toggle alterna visibilidade da senha', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuth()));
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      final senhaField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(senhaField.obscureText, isFalse);
    });
  });
}
