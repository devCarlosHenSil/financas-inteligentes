import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:financas_inteligentes/providers/app_providers.dart';
import 'package:financas_inteligentes/screens/login_screen.dart';
import 'package:financas_inteligentes/screens/dashboard_screen.dart';
import 'package:financas_inteligentes/services/notification_service.dart';
import 'package:financas_inteligentes/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (error) {
    startupError = error.toString();
  }

  // Inicializa o serviço de notificações (não-fatal se falhar)
  if (!kIsWeb) {
    try {
      await NotificationService.instance.init();
    } catch (_) {
      // Silencioso — notificações são opcionais
    }
  }

  runApp(MyApp(startupError: startupError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    final hasStartupError = startupError != null && startupError!.isNotEmpty;

    return AppProviders(
      child: MaterialApp(
        title: 'Finanças Inteligentes',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: hasStartupError
            ? _StartupErrorScreen(message: startupError!)
            : const _AuthGate(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
        },
      ),
    );
  }
}

// ── AuthGate ──────────────────────────────────────────────────────────────────
//
// Escuta authStateChanges do Firebase via AuthProvider e decide qual tela
// exibir sem depender de Navigator.pushReplacementNamed nas telas filhas.
//
// Fluxo:
//   - null (não autenticado)  → LoginScreen
//   - User  (autenticado)     → DashboardScreen
//   - Transição               → SplashScreen (evita flash de tela errada)
//
// Por que usar StreamBuilder aqui em vez de apenas context.watch<AuthProvider>:
//   O AuthProvider inicializa com FirebaseAuth.instance.currentUser no construtor,
//   mas o stream pode ainda estar carregando na primeira frame. O StreamBuilder
//   garante que a decisão seja sempre baseada no estado mais recente do Firebase,
//   não no snapshot inicial do provider.

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Aguardando resposta do Firebase (primeira frame)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // Erro no stream de autenticação — exibe tela de login por segurança
        if (snapshot.hasError) {
          return const LoginScreen();
        }

        // Usuário autenticado → Dashboard
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }

        // Não autenticado → Login
        return const LoginScreen();
      },
    );
  }
}

// ── SplashScreen ──────────────────────────────────────────────────────────────
//
// Exibida apenas durante a verificação inicial do estado de autenticação
// (tipicamente < 300ms). Evita o "flash" de LoginScreen para DashboardScreen
// em usuários que já estavam logados.

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              size: 56,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── StartupErrorScreen ────────────────────────────────────────────────────────

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isFirebaseWebImportError =
        kIsWeb && message.contains('firebasejs/');

    return Scaffold(
      appBar: AppBar(title: const Text('Falha ao iniciar app')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Não foi possível inicializar o Firebase neste ambiente.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (isFirebaseWebImportError)
              const Text(
                'Foi detectada falha ao carregar os módulos JS do Firebase no Web. '
                'Verifique conectividade/bloqueios de rede (gstatic) e rode novamente.',
              ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                message,
                style:
                    const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dica: se estiver rodando no Chrome corporativo/restrito, teste em outra rede '
              'ou navegador sem bloqueio de CDN.',
            ),
          ],
        ),
      ),
    );
  }
}
