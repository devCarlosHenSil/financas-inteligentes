import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Gerencia autenticacao, perfil e upload de foto do usuario.
///
/// ## Metodos de perfil
///   - [updateDisplayName]  → atualiza nome de exibicao
///   - [updatePhotoFromFile]→ faz upload para Firebase Storage e atualiza photoURL
///   - [updatePassword]     → troca de senha (requer reautenticacao)
///   - [deleteAccount]      → exclui a conta permanentemente
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth  _auth         = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;

  User?   _user;
  bool    _isLoading       = false;
  bool    _isUpdatingProfile = false;
  String? _errorMessage;

  AuthProvider() {
    _user = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  User?   get user               => _user;
  bool    get isLoading          => _isLoading;
  bool    get isUpdatingProfile  => _isUpdatingProfile;
  bool    get isAuthenticated    => _user != null;
  String? get errorMessage       => _errorMessage;
  String? get photoUrl           => _user?.photoURL;
  String? get email              => _user?.email;

  String? get currentProvider {
    final info = _user?.providerData;
    if (info == null || info.isEmpty) return null;
    final id = info.first.providerId;
    if (id.contains('google'))   return 'google';
    if (id.contains('apple'))    return 'apple';
    if (id.contains('password')) return 'password';
    return id;
  }

  /// Prioridade: displayName → email → 'Usuario'
  String get displayLabel {
    if (_user == null) return 'Convidado';
    final name = _user!.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return _user!.email ?? 'Usuario';
  }

  String get displayInitial {
    final label = displayLabel;
    return label.isNotEmpty ? label[0].toUpperCase() : 'U';
  }

  bool get appleSignInAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// True se o provedor atual suporta troca de senha
  bool get canChangePassword => currentProvider == 'password';

  // ── Login e-mail/senha ────────────────────────────────────────────────────

  Future<bool> signIn({required String email, required String password}) async {
    return signInWithEmailPassword(email: email, password: password);
  }

  Future<bool> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password;
    try {
      await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: normalizedPassword,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        _errorMessage =
            '${_mapAuthError(e.code)} Se sua conta foi criada com Google/Apple, '
            'entre pelo botão social correspondente.';
      } else {
        _errorMessage = _mapAuthError(e.code);
      }
      _setLoading(false);
      return false;
    } catch (_) {
      _errorMessage = 'Erro inesperado. Tente novamente.';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password;
    try {
      await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: normalizedPassword,
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

  // ── Login social ──────────────────────────────────────────────────────────

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        try {
          final result = await _auth.signInWithPopup(provider);
          _setLoading(false);
          return result.user != null;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-blocked' || e.code == 'popup-closed-by-user') {
            await _auth.signInWithRedirect(provider);
            _setLoading(false);
            return true;
          }
          rethrow;
        }
      }
      _googleSignIn ??= GoogleSignIn();
      final googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) { _setLoading(false); return false; }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (!msg.contains('cancel') && !msg.contains('abort')) {
        _errorMessage = 'Erro ao entrar com Google. Tente novamente.';
      }
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    if (!appleSignInAvailable) {
      _errorMessage = 'Login com Apple disponivel apenas em iOS e macOS.';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken:     appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final result = await _auth.signInWithCredential(oauthCredential);
      if (result.additionalUserInfo?.isNewUser == true) {
        final fullName = [appleCredential.givenName, appleCredential.familyName]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
        if (fullName.isNotEmpty) await result.user?.updateDisplayName(fullName);
      }
      _setLoading(false);
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        _errorMessage = 'Erro ao entrar com Apple: ${e.message}';
      }
      _setLoading(false);
      return false;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setLoading(false);
      return false;
    } catch (_) {
      _errorMessage = 'Erro ao entrar com Apple. Tente novamente.';
      _setLoading(false);
      return false;
    }
  }

  // ── Perfil ────────────────────────────────────────────────────────────────

  /// Atualiza o nome de exibicao do usuario.
  Future<bool> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'O nome nao pode estar vazio.';
      notifyListeners();
      return false;
    }
    _setUpdatingProfile(true);
    _errorMessage = null;
    try {
      await _user!.updateDisplayName(trimmed);
      await _user!.reload();
      _user = _auth.currentUser;
      _setUpdatingProfile(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setUpdatingProfile(false);
      return false;
    } catch (_) {
      _errorMessage = 'Erro ao atualizar nome. Tente novamente.';
      _setUpdatingProfile(false);
      return false;
    }
  }

  /// Faz upload da foto para Firebase Storage e atualiza photoURL.
  /// Em plataformas Web, recebe bytes; em mobile recebe File.
  Future<bool> updatePhotoFromFile(File file) async {
    _setUpdatingProfile(true);
    _errorMessage = null;
    try {
      final uid = _user!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child('usuarios/$uid/avatar.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _user!.updatePhotoURL(url);
      await _user!.reload();
      _user = _auth.currentUser;
      _setUpdatingProfile(false);
      return true;
    } on FirebaseException catch (e) {
      _errorMessage = 'Erro no upload da foto: ${e.message}';
      _setUpdatingProfile(false);
      return false;
    } catch (_) {
      _errorMessage = 'Erro ao atualizar foto. Tente novamente.';
      _setUpdatingProfile(false);
      return false;
    }
  }

  /// Atualiza foto a partir de bytes (Web / file_picker).
  Future<bool> updatePhotoFromBytes(Uint8List bytes, String extension) async {
    _setUpdatingProfile(true);
    _errorMessage = null;
    try {
      final uid = _user!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child('usuarios/$uid/avatar.$extension');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();
      await _user!.updatePhotoURL(url);
      await _user!.reload();
      _user = _auth.currentUser;
      _setUpdatingProfile(false);
      return true;
    } on FirebaseException catch (e) {
      _errorMessage = 'Erro no upload da foto: ${e.message}';
      _setUpdatingProfile(false);
      return false;
    } catch (_) {
      _errorMessage = 'Erro ao atualizar foto. Tente novamente.';
      _setUpdatingProfile(false);
      return false;
    }
  }

  /// Troca a senha (disponivel apenas para provedor email/senha).
  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!canChangePassword) {
      _errorMessage = 'Troca de senha nao disponivel para este metodo de login.';
      notifyListeners();
      return false;
    }
    if (newPassword.length < 6) {
      _errorMessage = 'A nova senha deve ter pelo menos 6 caracteres.';
      notifyListeners();
      return false;
    }
    _setUpdatingProfile(true);
    _errorMessage = null;
    try {
      // Reautentica antes de trocar a senha
      final credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: currentPassword,
      );
      await _user!.reauthenticateWithCredential(credential);
      await _user!.updatePassword(newPassword);
      _setUpdatingProfile(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setUpdatingProfile(false);
      return false;
    } catch (_) {
      _errorMessage = 'Erro ao trocar senha. Tente novamente.';
      _setUpdatingProfile(false);
      return false;
    }
  }

  /// Exclui a conta permanentemente (requer reautenticacao).
  Future<bool> deleteAccount({String? currentPassword}) async {
    _setUpdatingProfile(true);
    _errorMessage = null;
    try {
      if (canChangePassword && currentPassword != null) {
        final credential = EmailAuthProvider.credential(
          email: _user!.email!,
          password: currentPassword,
        );
        await _user!.reauthenticateWithCredential(credential);
      }
      await _user!.delete();
      _setUpdatingProfile(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setUpdatingProfile(false);
      return false;
    } catch (_) {
      _errorMessage = 'Erro ao excluir conta. Tente novamente.';
      _setUpdatingProfile(false);
      return false;
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    if (!kIsWeb && _googleSignIn != null) {
      try { await _googleSignIn!.signOut(); } catch (_) {}
    }
    await _auth.signOut();
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

  void _setUpdatingProfile(bool value) {
    _isUpdatingProfile = value;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':           return 'E-mail nao cadastrado.';
      case 'wrong-password':           return 'Senha incorreta.';
      case 'invalid-credential':       return 'E-mail ou senha incorretos.';
      case 'invalid-login-credentials': return 'E-mail ou senha incorretos.';
      case 'missing-email':            return 'Informe seu e-mail.';
      case 'missing-password':         return 'Informe sua senha.';
      case 'email-already-in-use':     return 'E-mail ja cadastrado.';
      case 'weak-password':            return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'invalid-email':            return 'E-mail invalido.';
      case 'too-many-requests':        return 'Muitas tentativas. Aguarde e tente novamente.';
      case 'network-request-failed':   return 'Sem conexao com a internet.';
      case 'operation-not-allowed':
        return 'Login com e-mail e senha está desativado no Firebase. '
            'Ative o provedor "E-mail/senha" no Console.';
      case 'requires-recent-login':    return 'Por seguranca, faca login novamente antes de continuar.';
      case 'account-exists-with-different-credential':
        return 'Ja existe conta com esse e-mail em outro metodo de login.';
      case 'user-disabled':            return 'Esta conta foi desativada.';
      default:                         return 'Erro de autenticacao ($code).';
    }
  }
}
