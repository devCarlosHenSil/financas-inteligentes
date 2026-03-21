import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:financas_inteligentes/errors/app_error.dart';

class ErrorHandler {
  ErrorHandler._();

  static final ErrorHandler instance = ErrorHandler._();

  ValueChanged<AppError>? onCriticalError;
  ValueChanged<AppError>? onErrorLogged;

  void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      final error = AppError(
        type: AppErrorType.unknown,
        userMessage: 'Ocorreu um erro inesperado no aplicativo.',
        technicalMessage: details.exceptionAsString(),
        originalException: details.exception,
        stackTrace: details.stack,
      );
      _log(error);
      _report(error);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      final appError = AppError.from(error, stack);
      _log(appError);
      _report(appError);
      return true;
    };
  }

  AppError handle(Object error, [StackTrace? stackTrace]) {
    final appError = AppError.from(error, stackTrace);
    _log(appError);
    return appError;
  }

  AppError validation(String message) {
    final error = AppError.validation(message);
    _log(error);
    return error;
  }

  AppError business(String message) {
    final error = AppError.business(message);
    _log(error);
    return error;
  }

  void showSnackBar(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(_iconForType(error.type), color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(error.userMessage,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: _colorForType(error.type),
          duration: error.isValidation
              ? const Duration(seconds: 3)
              : const Duration(seconds: 5),
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Tentar novamente',
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  Future<void> showDialog(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    String? title,
  }) async {
    if (!context.mounted) return;

    await showAdaptiveDialog<void>(
      context: context,
      barrierDismissible: !error.isAuth,
      builder: (ctx) => AlertDialog.adaptive(
        title: Row(
          children: [
            Icon(_iconForType(error.type), color: _colorForType(error.type)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title ?? _titleForType(error.type),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(error.userMessage),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: const Text('Tentar novamente'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _log(AppError error) {
    if (kDebugMode) {
      debugPrint('┌─ [ErrorHandler] ${error.type.name.toUpperCase()} ─────────────');
      debugPrint('│  ${error.technicalMessage}');
      if (error.stackTrace != null) {
        debugPrint('│  StackTrace: ${error.stackTrace.toString().split('\n').take(5).join('\n│  ')}');
      }
      debugPrint('└────────────────────────────────────────────────────────');
    }
    onErrorLogged?.call(error);
  }

  void _report(AppError error) {
    if (error.isValidation || error.isBusiness) return;
    onCriticalError?.call(error);
  }

  IconData _iconForType(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:    return Icons.wifi_off_outlined;
      case AppErrorType.auth:       return Icons.lock_outline;
      case AppErrorType.firestore:  return Icons.cloud_off_outlined;
      case AppErrorType.validation: return Icons.info_outline;
      case AppErrorType.business:   return Icons.warning_amber_outlined;
      case AppErrorType.unknown:    return Icons.error_outline;
    }
  }

  Color _colorForType(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:    return Colors.orange.shade700;
      case AppErrorType.auth:       return Colors.red.shade700;
      case AppErrorType.firestore:  return Colors.deepOrange.shade700;
      case AppErrorType.validation: return Colors.blueGrey.shade700;
      case AppErrorType.business:   return Colors.amber.shade800;
      case AppErrorType.unknown:    return Colors.red.shade900;
    }
  }

  String _titleForType(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:    return 'Sem conexão';
      case AppErrorType.auth:       return 'Erro de autenticação';
      case AppErrorType.firestore:  return 'Erro no banco de dados';
      case AppErrorType.validation: return 'Atenção';
      case AppErrorType.business:   return 'Aviso';
      case AppErrorType.unknown:    return 'Erro inesperado';
    }
  }
}

mixin ErrorHandlerMixin on ChangeNotifier {
  AppError? _appError;

  AppError? get appError => _appError;
  String?   get error    => _appError?.userMessage;

  void clearError() {
    _appError = null;
    notifyListeners();
  }

  Future<T> runSafe<T>(
    Future<T> Function() fn, {
    required T fallback,
    bool notify = true,
  }) async {
    try {
      _appError = null;
      return await fn();
    } catch (e, st) {
      _appError = ErrorHandler.instance.handle(e, st);
      if (notify) notifyListeners();
      return fallback;
    }
  }

  Future<void> runSafeVoid(
    Future<void> Function() fn, {
    bool notify = true,
  }) async {
    try {
      _appError = null;
      await fn();
    } catch (e, st) {
      _appError = ErrorHandler.instance.handle(e, st);
      if (notify) notifyListeners();
    }
  }
}
