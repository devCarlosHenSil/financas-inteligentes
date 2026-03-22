import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth         = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User?   _user;
  bool    _isLoading    = false;
  String? _errorMessage;

  AuthProvider() {
    _user = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User?   get user            => _user;
  bool    get isLoading       => _isLoading;
  bool    get isAuthenticated => _user != null;
  String? get errorMessage    => _errorMessage;
  String? get photoUrl        => _user?.photoURL;

  String? get currentProvider {
    final info = _user?.providerData;
    if (info == null || info.isEmpty) return null;
    final id = info.first.providerId;
    if (id.contains('google'))   return 'google';
    if (id.contains('apple'))    return 'apple';
    if (id.contains('password')) return 'password';
    return id;
  }

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

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
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

  Future<bool> register({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
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

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        final result = await _auth.signInWithPopup(provider);
        _setLoading(false);
        return result.user != null;
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return false;
      }

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

  Future<void> signOut() async {
    if (!kIsWeb) {
      try { await _googleSignIn.signOut(); } catch (_) {}
    }
    await _auth.signOut();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':           return 'E-mail nao cadastrado.';
      case 'wrong-password':           return 'Senha incorreta.';
      case 'invalid-credential':       return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':     return 'E-mail ja cadastrado.';
      case 'weak-password':            return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'invalid-email':            return 'E-mail invalido.';
      case 'too-many-requests':        return 'Muitas tentativas. Aguarde e tente novamente.';
      case 'network-request-failed':   return 'Sem conexao com a internet.';
      case 'account-exists-with-different-credential':
        return 'Ja existe conta com esse e-mail em outro metodo de login.';
      case 'user-disabled':            return 'Esta conta foi desativada.';
      default:                         return 'Erro de autenticacao ($code).';
    }
  }
}
