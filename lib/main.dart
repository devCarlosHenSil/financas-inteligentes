import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:financas_inteligentes/providers/app_providers.dart';
import 'package:financas_inteligentes/providers/auth_provider.dart';
import 'package:financas_inteligentes/screens/login_screen.dart';
import 'package:financas_inteligentes/screens/dashboard_screen.dart';
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

  runApp(
    AppProviders(
      child: MyApp(startupError: startupError),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    final hasStartupError = startupError != null && startupError!.isNotEmpty;

    return MaterialApp(
      title: 'Finanças Inteligentes',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // Roteamento reativo baseado no AuthProvider —
      // quando o usuário desloga, a home volta automaticamente para LoginScreen
      home: hasStartupError
          ? _StartupErrorScreen(message: startupError!)
          : const _AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

/// Roteador reativo: observa o AuthProvider e decide qual tela exibir.
/// Substitui a navegação imperativa com pushReplacementNamed que existia
/// em cada tela — agora o app reage automaticamente ao estado de sessão.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isAuthenticated ? const DashboardScreen() : const LoginScreen();
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
