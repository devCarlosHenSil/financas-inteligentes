import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Gerencia o estado de autenticação do app.
///
/// Expõe o [User] atual, o status de carregamento durante operações de
/// login/registro e métodos utilitários de autenticação.
///
/// Resolução do bug anterior:
///   - FirestoreService usava `userId` fixo no construtor.
///   - Agora o userId é sempre lido via `FirebaseAuth.instance.currentUser?.uid`
///     diretamente no getter de FirestoreService, eliminando o stale reference.
///   - AuthProvider centraliza a navegação pós-login/logout para que cada
///     tela não precise manter sua própria referência ao FirebaseAuth.
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    // Inicia com o usuário atual (caso o app seja reaberto com sessão ativa)
    _user = _auth.currentUser;

    // Reage a mudanças de autenticação (login, logout, token refresh)
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  // ── Getters públicos ──────────────────────────────────────────────────────

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;

  /// Retorna o nome de exibição do usuário para a UI.
  /// Prioridade: displayName → email → 'Usuário'
  String get displayLabel {
    if (_user == null) return 'Convidado';
    final name = _user!.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return _user!.email ?? 'Usuário';
  }

  /// Inicial do nome para o avatar.
  String get displayInitial {
    final label = displayLabel;
    return label.isNotEmpty ? label[0].toUpperCase() : 'U';
  }

  // ── Operações de autenticação ─────────────────────────────────────────────

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setLoading(false);
      return false;
    } catch (_) {
      _errorMessage = 'Erro inesperado. Tente novamente.';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setLoading(false);
      return false;
    } catch (_) {
      _errorMessage = 'Erro inesperado. Tente novamente.';
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // _user será atualizado via authStateChanges listener acima
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'E-mail não cadastrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'email-already-in-use':
        return 'E-mail já cadastrado.';
      case 'weak-password':
        return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde e tente novamente.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      default:
        return 'Erro de autenticação ($code).';
    }
  }
}
