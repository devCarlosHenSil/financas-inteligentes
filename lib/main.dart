import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:financas_inteligentes/screens/login_screen.dart';
import 'package:financas_inteligentes/screens/dashboard_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (error) {
    startupError = error.toString();
  }

  runApp(MyApp(startupError: startupError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    final hasStartupError = startupError != null && startupError!.isNotEmpty;

    return MaterialApp(
      title: 'Finanças Inteligentes',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: hasStartupError
          ? _StartupErrorScreen(message: startupError!)
          : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
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
