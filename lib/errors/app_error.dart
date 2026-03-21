import 'package:firebase_auth/firebase_auth.dart';

// ── Categorias de erro ─────────────────────────────────────────────────────────

/// Categoria do erro — usada para icone, cor e ação sugerida na UI.
enum AppErrorType {
  /// Falha de rede ou API externa (BRAPI, CoinGecko, AwesomeAPI).
  network,

  /// Erro de autenticação Firebase Auth.
  auth,

  /// Erro de leitura/gravação no Firestore.
  firestore,

  /// Validação de formulário (campo obrigatório, formato inválido, etc.).
  validation,

  /// Erro de negócio controlado (ex.: arquivo inválido na importação CSV).
  business,

  /// Erro inesperado / não classificado.
  unknown,
}

// ── AppError ───────────────────────────────────────────────────────────────────

/// Erro padronizado do Finanças Inteligentes.
///
/// Substitui o antipadrão `_error = e.toString()` espalhado nos providers.
///
/// ## Criação
///
/// ```dart
/// // A partir de uma exceção capturada:
/// final error = AppError.from(e);
///
/// // Manualmente (validação):
/// final error = AppError.validation('Selecione uma categoria.');
///
/// // Negócio:
/// final error = AppError.business('Arquivo CSV inválido: coluna faltando.');
/// ```
///
/// ## Exibição
///
/// ```dart
/// // Mensagem amigável para o usuário:
/// ScaffoldMessenger.of(context).showSnackBar(
///   SnackBar(content: Text(error.userMessage)),
/// );
///
/// // Log técnico (debug):
/// debugPrint(error.technicalMessage);
/// ```
class AppError {
  const AppError({
    required this.type,
    required this.userMessage,
    required this.technicalMessage,
    this.originalException,
    this.stackTrace,
  });

  /// Categoria do erro.
  final AppErrorType type;

  /// Mensagem legível para o usuário final (sem detalhes técnicos).
  final String userMessage;

  /// Mensagem técnica completa para logs/debug.
  final String technicalMessage;

  /// Exceção original capturada (pode ser null para erros manuais).
  final Object? originalException;

  /// StackTrace original (disponível quando capturado via `on ... catch`).
  final StackTrace? stackTrace;

  // ── Factory: classificação automática ─────────────────────────────────────

  /// Cria um [AppError] a partir de qualquer exceção capturada.
  /// Classifica automaticamente o tipo com base na exceção.
  factory AppError.from(Object error, [StackTrace? stackTrace]) {
    // FirebaseAuthException
    if (error is FirebaseAuthException) {
      return AppError(
        type: AppErrorType.auth,
        userMessage: _mapAuthError(error.code),
        technicalMessage: 'FirebaseAuthException [${error.code}]: ${error.message}',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // FirebaseException (Firestore, Storage, etc.)
    if (error is FirebaseException) {
      return AppError(
        type: AppErrorType.firestore,
        userMessage: _mapFirestoreError(error.code),
        technicalMessage: 'FirebaseException [${error.plugin}/${error.code}]: ${error.message}',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // Erros de rede (Uri, SocketException, TimeoutException, etc.)
    final msg = error.toString().toLowerCase();
    if (_isNetworkError(msg)) {
      return AppError(
        type: AppErrorType.network,
        userMessage: 'Sem conexão com a internet. Verifique sua rede e tente novamente.',
        technicalMessage: 'NetworkError: $error',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // Erro genérico
    return AppError(
      type: AppErrorType.unknown,
      userMessage: 'Ocorreu um erro inesperado. Tente novamente.',
      technicalMessage: 'UnknownError: $error',
      originalException: error,
      stackTrace: stackTrace,
    );
  }

  // ── Factories manuais ──────────────────────────────────────────────────────

  factory AppError.validation(String message) => AppError(
        type: AppErrorType.validation,
        userMessage: message,
        technicalMessage: 'ValidationError: $message',
      );

  factory AppError.business(String message) => AppError(
        type: AppErrorType.business,
        userMessage: message,
        technicalMessage: 'BusinessError: $message',
      );

  factory AppError.network(String message) => AppError(
        type: AppErrorType.network,
        userMessage: message,
        technicalMessage: 'NetworkError: $message',
      );

  // ── Helpers de classificação ───────────────────────────────────────────────

  static bool _isNetworkError(String msg) {
    return msg.contains('socketexception') ||
        msg.contains('timeoutexception') ||
        msg.contains('network') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup') ||
        msg.contains('no address associated');
  }

  static String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'E-mail não cadastrado.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'weak-password':
        return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'invalid-email':
        return 'Endereço de e-mail inválido.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde e tente novamente.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      default:
        return 'Erro de autenticação. Tente novamente.';
    }
  }

  static String _mapFirestoreError(String? code) {
    switch (code) {
      case 'permission-denied':
        return 'Sem permissão para acessar estes dados.';
      case 'not-found':
        return 'Dado não encontrado.';
      case 'unavailable':
        return 'Serviço temporariamente indisponível. Tente mais tarde.';
      case 'deadline-exceeded':
        return 'Tempo de resposta excedido. Verifique sua conexão.';
      default:
        return 'Erro ao acessar o banco de dados.';
    }
  }

  // ── Utilitários ────────────────────────────────────────────────────────────

  @override
  String toString() => 'AppError(${type.name}): $technicalMessage';

  bool get isNetwork    => type == AppErrorType.network;
  bool get isAuth       => type == AppErrorType.auth;
  bool get isFirestore  => type == AppErrorType.firestore;
  bool get isValidation => type == AppErrorType.validation;
  bool get isBusiness   => type == AppErrorType.business;
  bool get isUnknown    => type == AppErrorType.unknown;
}
