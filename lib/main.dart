import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:financas_inteligentes/providers/app_providers.dart';
import 'package:financas_inteligentes/screens/login_screen.dart';
import 'package:financas_inteligentes/screens/dashboard_screen.dart';
import 'package:financas_inteligentes/services/notification_service.dart';
import 'package:financas_inteligentes/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa dados de locale pt_BR para DateFormat funcionar em todas as plataformas
  await initializeDateFormatting('pt_BR');

  String? startupError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
          Locale('en', 'US'),
        ],
        // _AuthGate escuta authStateChanges e decide Login x Dashboard
        home: hasStartupError
            ? _StartupErrorScreen(message: startupError!)
            : const _AuthGate(),
        routes: {
          '/login':     (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
        },
      ),
    );
  }
}

// ── AuthGate ──────────────────────────────────────────────────────────────────
//
// Escuta FirebaseAuth.authStateChanges() e redireciona automaticamente:
//   - null  → LoginScreen
//   - User  → DashboardScreen
//
// Garante que após signIn o usuário vai para o Dashboard sem Navigator.push
// manual, e após signOut volta para Login sem referência stale.

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Aguarda a primeira emissão do stream (verificação de sessão)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final user = snapshot.data;
        if (user != null) {
          return const DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

// ── SplashScreen ──────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              size: 64,
              color: colorScheme.onPrimary,
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: colorScheme.onPrimary,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isFirebaseWebImportError = kIsWeb && message.contains('firebasejs/');

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
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
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
