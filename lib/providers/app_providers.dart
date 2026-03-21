import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:financas_inteligentes/providers/auth_provider.dart';
import 'package:financas_inteligentes/providers/transaction_provider.dart';
import 'package:financas_inteligentes/providers/investment_provider.dart';
import 'package:financas_inteligentes/providers/shopping_provider.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/services/market_cache_service.dart';

/// Configura a árvore de providers do app.
///
/// Hierarquia:
///   AuthProvider
///   FirestoreService
///   ApiService
///   MarketCacheService          ← cache local de mercado
///   TransactionProvider         ← depende de FirestoreService
///   InvestmentProvider          ← depende de FirestoreService + ApiService + MarketCacheService
///   ShoppingProvider            ← depende de FirestoreService
class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),

        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),

        Provider<ApiService>(
          create: (_) => ApiService(),
        ),

        Provider<MarketCacheService>(
          create: (_) => MarketCacheService(),
        ),

        ChangeNotifierProxyProvider<FirestoreService, TransactionProvider>(
          create: (ctx) => TransactionProvider(ctx.read<FirestoreService>()),
          update: (ctx, service, previous) =>
              previous ?? TransactionProvider(service),
        ),

        ChangeNotifierProxyProvider3<
            FirestoreService,
            ApiService,
            MarketCacheService,
            InvestmentProvider>(
          create: (ctx) => InvestmentProvider(
            ctx.read<FirestoreService>(),
            ctx.read<ApiService>(),
            cache: ctx.read<MarketCacheService>(),
          ),
          update: (ctx, fs, api, cache, previous) =>
              previous ?? InvestmentProvider(fs, api, cache: cache),
        ),

        ChangeNotifierProxyProvider<FirestoreService, ShoppingProvider>(
          create: (ctx) => ShoppingProvider(ctx.read<FirestoreService>()),
          update: (ctx, service, previous) =>
              previous ?? ShoppingProvider(service),
        ),
      ],
      child: child,
    );
  }
}
