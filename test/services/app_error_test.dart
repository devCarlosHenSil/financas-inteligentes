// test/services/app_error_test.dart
//
// Testa a classificação de erros, factories e getters do AppError.
// Não depende de Firebase — usa exceções genéricas.

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:financas_inteligentes/errors/app_error.dart';

void main() {
  // ── AppError factories manuais ───────────────────────────────────────────────

  group('AppError.validation', () {
    test('cria erro com tipo validation', () {
      final e = AppError.validation('Campo obrigatório.');
      expect(e.type, AppErrorType.validation);
      expect(e.userMessage, 'Campo obrigatório.');
      expect(e.isValidation, isTrue);
      expect(e.isNetwork, isFalse);
    });

    test('mensagem técnica contém "ValidationError"', () {
      final e = AppError.validation('Valor inválido.');
      expect(e.technicalMessage, contains('ValidationError'));
    });
  });

  group('AppError.business', () {
    test('cria erro com tipo business', () {
      final e = AppError.business('CSV inválido: coluna faltando.');
      expect(e.type, AppErrorType.business);
      expect(e.isBusiness, isTrue);
      expect(e.userMessage, 'CSV inválido: coluna faltando.');
    });
  });

  group('AppError.network', () {
    test('cria erro com tipo network', () {
      final e = AppError.network('Sem conexão.');
      expect(e.type, AppErrorType.network);
      expect(e.isNetwork, isTrue);
    });
  });

  // ── AppError.from — classificação automática ─────────────────────────────────

  group('AppError.from — FirebaseAuthException', () {
    FirebaseAuthException makeAuthEx(String code) =>
        FirebaseAuthException(code: code);

    test('classifica como auth', () {
      final e = AppError.from(makeAuthEx('wrong-password'));
      expect(e.type, AppErrorType.auth);
      expect(e.isAuth, isTrue);
    });

    test('wrong-password tem mensagem amigável', () {
      final e = AppError.from(makeAuthEx('wrong-password'));
      expect(e.userMessage, isNotEmpty);
      expect(e.userMessage, isNot(contains('wrong-password')));
    });

    test('user-not-found tem mensagem amigável', () {
      final e = AppError.from(makeAuthEx('user-not-found'));
      expect(e.userMessage, isNotEmpty);
    });

    test('mensagem técnica contém o código original', () {
      final e = AppError.from(makeAuthEx('too-many-requests'));
      expect(e.technicalMessage, contains('too-many-requests'));
    });

    test('código desconhecido gera erro de auth genérico', () {
      final e = AppError.from(makeAuthEx('unknown-code-xyz'));
      expect(e.type, AppErrorType.auth);
      expect(e.userMessage, isNotEmpty);
    });
  });

  group('AppError.from — erros de rede genéricos', () {
    test('SocketException é classificada como network', () {
      final e = AppError.from(Exception('SocketException: connection refused'));
      expect(e.type, AppErrorType.network);
    });

    test('TimeoutException é classificada como network', () {
      final e = AppError.from(Exception('TimeoutException: timeout'));
      expect(e.type, AppErrorType.network);
    });

    test('failed host lookup é classificado como network', () {
      final e = AppError.from(Exception('Failed host lookup: brapi.dev'));
      expect(e.type, AppErrorType.network);
    });
  });

  group('AppError.from — erros genéricos', () {
    test('exceção desconhecida vira unknown', () {
      final e = AppError.from(Exception('Algo deu muito errado'));
      expect(e.type, AppErrorType.unknown);
      expect(e.isUnknown, isTrue);
    });

    test('originalException é preservado', () {
      final original = Exception('original');
      final e = AppError.from(original);
      expect(e.originalException, same(original));
    });

    test('stackTrace é preservado quando fornecido', () {
      StackTrace? captured;
      try {
        throw Exception('test');
      } catch (_, st) {
        captured = st;
      }
      final e = AppError.from(Exception('test'), captured);
      expect(e.stackTrace, isNotNull);
    });
  });

  // ── Getters de conveniência ──────────────────────────────────────────────────

  group('AppError getters', () {
    test('isFirestore retorna true apenas para tipo firestore', () {
      final e = AppError(
        type: AppErrorType.firestore,
        userMessage: 'Erro no banco.',
        technicalMessage: 'FirebaseException',
      );
      expect(e.isFirestore, isTrue);
      expect(e.isAuth, isFalse);
    });

    test('toString contém tipo e mensagem técnica', () {
      final e = AppError.validation('Campo vazio.');
      final str = e.toString();
      expect(str, contains('validation'));
      expect(str, contains('ValidationError'));
    });
  });
}
