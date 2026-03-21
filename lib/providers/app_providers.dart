import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:financas_inteligentes/providers/auth_provider.dart';
import 'package:financas_inteligentes/providers/transaction_provider.dart';
import 'package:financas_inteligentes/providers/investment_provider.dart';
import 'package:financas_inteligentes/providers/shopping_provider.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/services/api_service.dart';

/// Configura a árvore de providers do app.
///
/// Uso em main.dart:
/// ```dart
/// runApp(AppProviders(child: MyApp()));
/// ```
///
/// Hierarquia:
///   AuthProvider         — sessão de usuário (singleton, vive toda a app)
///   FirestoreService     — instância única, injetada nos providers filhos
///   ApiService           — instância única, injetada no InvestmentProvider
///   TransactionProvider  — depende de FirestoreService
///   InvestmentProvider   — depende de FirestoreService + ApiService
///   ShoppingProvider     — depende de FirestoreService
class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Autenticação — criado primeiro pois outros providers dependem do userId
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),

        // Serviços (não são ChangeNotifier — usamos Provider puro)
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),

        Provider<ApiService>(
          create: (_) => ApiService(),
        ),

        // Providers de domínio — recebem serviços via ProxyProvider
        ChangeNotifierProxyProvider<FirestoreService, TransactionProvider>(
          create: (ctx) => TransactionProvider(
            ctx.read<FirestoreService>(),
          ),
          update: (ctx, service, previous) =>
              previous ?? TransactionProvider(service),
        ),

        ChangeNotifierProxyProvider2<FirestoreService, ApiService,
            InvestmentProvider>(
          create: (ctx) => InvestmentProvider(
            ctx.read<FirestoreService>(),
            ctx.read<ApiService>(),
          ),
          update: (ctx, firestoreService, apiService, previous) =>
              previous ?? InvestmentProvider(firestoreService, apiService),
        ),

        ChangeNotifierProxyProvider<FirestoreService, ShoppingProvider>(
          create: (ctx) => ShoppingProvider(
            ctx.read<FirestoreService>(),
          ),
          update: (ctx, service, previous) =>
              previous ?? ShoppingProvider(service),
        ),
      ],
      child: child,
    );
  }
}
