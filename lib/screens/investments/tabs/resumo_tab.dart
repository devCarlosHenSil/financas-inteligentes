import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/providers/investment_provider.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_charts.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ResumoTab extends StatelessWidget {
  const ResumoTab({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvestmentProvider>();
    final textTheme = Theme.of(context).textTheme;
    // colorScheme usado apenas dentro de _AssetGroupCard, não aqui
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final investments = inv.investments;
    final patrimonio = inv.patrimonio;
    final totalInvestido = inv.totalInvestido;
    final dist = distributionByType(investments);
    final grouped = groupedByType(investments);
    final quotes = inv.quotes;

    final w = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumo dos Investimentos',
              style:
                  textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (inv.loadingMarket) const LinearProgressIndicator(),
          GridView.count(
            crossAxisCount: w > 1100 ? 4 : w > 640 ? 2 : 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            childAspectRatio: w > 1400
                ? 3.0
                : w > 1100
                    ? 2.4
                    : w > 800
                        ? 2.0
                        : w > 640
                            ? 1.7
                            : 2.6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              SummaryCard(
                title: 'Patrimônio total',
                value: currency.format(patrimonio),
                subtitle: 'Valor investido: ${currency.format(totalInvestido)}',
                icon: Icons.account_balance_wallet_outlined,
              ),
              SummaryCard(
                title: 'Lucro estimado',
                value: currency.format(
                    (patrimonio - totalInvestido).clamp(-999999999, 999999999)),
                subtitle: 'Com base nos lançamentos da carteira',
                icon: Icons.trending_up,
              ),
              SummaryCard(
                title: 'Ativos cadastrados',
                value: investments.length.toString(),
                subtitle: '${grouped.length} classes de ativos',
                icon: Icons.pie_chart_outline,
              ),
              SummaryCard(
                title: 'Moedas e cripto',
                value:
                    'USD ${quotes['USD']?.toStringAsFixed(2) ?? '0.00'} • BTC ${quotes['BTC']?.toStringAsFixed(0) ?? '0'}',
                subtitle:
                    'EUR ${quotes['EUR']?.toStringAsFixed(2) ?? '0.00'} • ETH ${quotes['ETH']?.toStringAsFixed(0) ?? '0'}',
                icon: Icons.currency_exchange,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SectionCard(
                  height: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Evolução dos lançamentos',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Expanded(child: EvolutionBarChart(investments)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionCard(
                  height: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ativos na carteira',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Expanded(child: DistributionPieChart(dist)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meus Ativos (${investments.length})',
                    style: textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...grouped.entries.map((entry) {
                  final total = entry.value.fold<double>(
                      0, (sum, i) => sum + i.valorInvestido);
                  final distTotal =
                      dist.values.fold<double>(0, (s, v) => s + v);
                  final pct = distTotal == 0
                      ? 0.0
                      : ((dist[entry.key] ?? 0) / distTotal) * 100;

                  return _AssetGroupCard(
                    typeLabel: entry.key,
                    items: entry.value,
                    total: total,
                    pct: pct,
                    currency: currency,
                    onDelete: (id) =>
                        context.read<InvestmentProvider>().deleteInvestment(id),
                  );
                }),
                if (grouped.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('Sem investimentos cadastrados.')),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: TopListCard('Top ETFs do dia', inv.topEtfs)),
              const SizedBox(width: 10),
              Expanded(child: TopListCard('Top FIIs do dia', inv.topFiis)),
              const SizedBox(width: 10),
              Expanded(child: TopListCard('Top Ações do dia', inv.topStocks)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widget auxiliar interno da aba ────────────────────────────────────────────

class _AssetGroupCard extends StatelessWidget {
  const _AssetGroupCard({
    required this.typeLabel,
    required this.items,
    required this.total,
    required this.pct,
    required this.currency,
    required this.onDelete,
  });

  final String typeLabel;
  final List<InvestmentModel> items;
  final double total;
  final double pct;
  final NumberFormat currency;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(typeLabel,
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            subtitle: Text(
                'Ativos ${items.length} • Valor total ${currency.format(total)} • % na carteira ${pct.toStringAsFixed(1)}%'),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Ativo')),
                DataColumn(label: Text('Operação')),
                DataColumn(label: Text('Data')),
                DataColumn(label: Text('Valor')),
                DataColumn(label: Text('Ações')),
              ],
              rows: items.map((inv) {
                final parts =
                    inv.nome.split('•').map((e) => e.trim()).toList();
                final ativo = parts.length > 1 ? parts[1] : inv.nome;
                final operacao = parts.length > 2
                    ? parts[2]
                    : (inv.valorInvestido >= 0 ? 'Compra' : 'Venda');
                return DataRow(cells: [
                  DataCell(Text(ativo)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: operacao == 'Venda'
                            ? colorScheme.errorContainer
                            : colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        operacao,
                        style: TextStyle(
                          color: operacao == 'Venda'
                              ? colorScheme.error
                              : colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                      Text(DateFormat('dd/MM/yyyy').format(inv.data))),
                  DataCell(Text(currency.format(inv.valorInvestido))),
                  DataCell(IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDelete(inv.id),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
