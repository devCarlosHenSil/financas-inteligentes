import 'package:financas_inteligentes/providers/investment_provider.dart';
import 'package:financas_inteligentes/screens/investments/tabs/patrimonio_tab.dart';
import 'package:financas_inteligentes/screens/investments/tabs/proventos_tab.dart';
import 'package:financas_inteligentes/screens/investments/tabs/rentabilidade_tab.dart';
import 'package:financas_inteligentes/screens/investments/tabs/resumo_tab.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_launch_dialog.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvestmentProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              // ── AppBar manual ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Investimentos',
                        style: textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          context.read<InvestmentProvider>().refreshMarketData(),
                      icon: const Icon(Icons.refresh),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => showLaunchDialog(
                        context: context,
                        api: context.read<ApiService>(),
                        service: context.read<FirestoreService>(),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar lançamento'),
                    ),
                  ],
                ),
              ),

              // ── TabBar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TabBar(
                  labelColor: colorScheme.onSurface,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicatorColor: colorScheme.primary,
                  indicatorWeight: 2,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: colorScheme.outlineVariant,
                  labelStyle: textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Resumo'),
                    Tab(text: 'Proventos'),
                    Tab(text: 'Patrimônio'),
                    Tab(text: 'Rentabilidade'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── TabBarView ────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  children: [
                    const ResumoTab(),
                    const ProventosTab(),
                    PatrimonioTab(investments: inv.investments),
                    const RentabilidadeTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
