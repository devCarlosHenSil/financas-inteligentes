import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/providers/investment_provider.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_charts.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// ── Helpers de cálculo real ───────────────────────────────────────────────────

/// Retorna o ticker/nome do ativo a partir do nome completo do lançamento.
/// Formato: "Tipo • Ativo • Operação"
String _ativoFromNome(String nome) {
  final parts = nome.split('•').map((e) => e.trim()).toList();
  return parts.length > 1 ? parts[1] : nome;
}

/// Agrupa investimentos por ativo (segunda parte do nome) e soma os valores.
/// Filtra apenas compras (valorInvestido > 0) para evitar distorção dos gráficos.
Map<String, double> _distributionByAtivo(List<InvestmentModel> data) {
  final dist = <String, double>{};
  for (final inv in data) {
    if (inv.valorInvestido <= 0) continue; // ignora vendas
    final ativo = _ativoFromNome(inv.nome);
    dist.update(ativo, (v) => v + inv.valorInvestido,
        ifAbsent: () => inv.valorInvestido);
  }
  // Ordena por valor decrescente e retorna top 10
  final sorted = dist.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted.take(10));
}

/// Filtra investimentos por tipo (primeira parte do nome).
/// Ex.: tipo = 'Ações' → retorna apenas lançamentos de ações.
List<InvestmentModel> _filterByTipo(
    List<InvestmentModel> data, String tipo) {
  return data
      .where((inv) =>
          inv.valorInvestido > 0 &&
          inv.nome.split('•').first.trim().toLowerCase() ==
              tipo.toLowerCase())
      .toList();
}

/// Converte uma lista de InvestmentModel em LegendEntry por ativo,
/// usando uma paleta HSV distribuída uniformemente.
List<LegendEntry> _toAtivoEntries(List<InvestmentModel> data) {
  final dist = _distributionByAtivo(data);
  if (dist.isEmpty) return [];
  final total = dist.length;
  return dist.entries.toList().asMap().entries.map((e) {
    final hue = (e.key * 360 / total) % 360;
    return LegendEntry(
      label: e.value.key,
      amount: e.value.value,
      color: HSVColor.fromAHSV(1, hue, 0.65, 0.85).toColor(),
    );
  }).toList();
}

/// Calcula a evolução mensal dos últimos 12 meses a partir dos lançamentos reais.
///
/// Retorna duas listas paralelas:
///   [applied] — soma acumulada dos aportes até aquele mês
///   [gain]    — ganho estimado (6% a.a. simples sobre o acumulado do mês)
({List<double> applied, List<double> gain}) _calcEvolucao(
    List<InvestmentModel> data, List<DateTime> months) {
  // Soma de aportes (compras - vendas) por mês
  final monthlyNet = <int, double>{};
  for (final inv in data) {
    final key = DateTime(inv.data.year, inv.data.month).millisecondsSinceEpoch;
    monthlyNet.update(key, (v) => v + inv.valorInvestido,
        ifAbsent: () => inv.valorInvestido);
  }

  final applied = <double>[];
  final gain = <double>[];
  double acumulado = 0;

  for (final month in months) {
    final key = DateTime(month.year, month.month).millisecondsSinceEpoch;
    acumulado += monthlyNet[key] ?? 0;
    final acumuladoPos = acumulado < 0 ? 0.0 : acumulado;
    applied.add(acumuladoPos);
    // Ganho estimado: 6% a.a. → 0.5% a.m. sobre o valor acumulado
    gain.add(acumuladoPos * 0.005);
  }

  return (applied: applied, gain: gain);
}

// ── PatrimonioTab ─────────────────────────────────────────────────────────────
//
// P2-B: todos os dados agora calculados sobre InvestmentModel reais.
//
// REMOVIDO — valores hardcoded: BBAS3, WEGE3, ITSA3, GARE11, etc.
// REMOVIDO — appliedSeed, gainSeed com fórmulas arbitrárias
// ADICIONADO — _calcEvolucao: evolução mensal real dos aportes
// ADICIONADO — _toAtivoEntries: donut por ativo real
// ADICIONADO — _filterByTipo: filtra ações, FIIs, renda fixa, cripto reais
//
// Estado vazio: cada seção exibe "Sem lançamentos de [tipo]." quando
// não há dados — sem fallback para valores fictícios.

class PatrimonioTab extends StatelessWidget {
  const PatrimonioTab({super.key, required this.investments});
  final List<InvestmentModel> investments;

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvestmentProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();

    // ── Eixo de meses (últimos 12) ────────────────────────────────────────
    final months = List.generate(
      12,
      (i) => DateTime(now.year, now.month - 11 + i),
    );
    final labels =
        months.map((m) => DateFormat('MM/yy').format(m)).toList();

    // ── Evolução real do patrimônio ───────────────────────────────────────
    final evolucao = _calcEvolucao(investments, months);

    // ── Distribuição por tipo (consolidação geral) ────────────────────────
    final distPorTipo = distributionByType(investments);
    final consolidacao = distPorTipo.isNotEmpty
        ? distPorTipo.entries.toList().asMap().entries.map((e) {
            final hue = (e.key * 360 / distPorTipo.length) % 360;
            return LegendEntry(
              label: e.value.key,
              amount: e.value.value.abs(),
              color: HSVColor.fromAHSV(1, hue, 0.65, 0.85).toColor(),
            );
          }).toList()
        : <LegendEntry>[];

    // ── Distribuição por ativo — Ações ────────────────────────────────────
    final acoesData = _filterByTipo(investments, 'Ações');
    final acoes = _toAtivoEntries(acoesData);

    // ── Distribuição por ativo — FIIs ─────────────────────────────────────
    final fiisData = _filterByTipo(investments, 'FIIs');
    final fiis = _toAtivoEntries(fiisData);

    // ── Distribuição por ativo — Renda Fixa ───────────────────────────────
    final rendaFixaData = _filterByTipo(
        investments, 'Renda Fixa (CDB,LCI,LCA,LC,LF,RDB)');
    final rendaFixa = _toAtivoEntries(rendaFixaData);

    // ── Totais por seção (para exibir no header de cada card) ─────────────
    double somaAtivos(List<InvestmentModel> data) =>
        data.fold(0.0, (s, i) => s + i.valorInvestido);

    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Evolução do Patrimônio ──────────────────────────────────────
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Evolução do Patrimônio',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    FilterPill('12 Meses',
                        leading: Icons.calendar_month_outlined),
                    const SizedBox(width: 8),
                    FilterPill('Todos os tipos', leading: Icons.tune),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    LegendDot(
                        color: colorScheme.tertiary,
                        label: 'Valor acumulado'),
                    const SizedBox(width: 14),
                    LegendDot(
                        color: colorScheme.tertiaryContainer,
                        label: 'Ganho estimado (0,5% a.m.)'),
                  ],
                ),
                const SizedBox(height: 12),
                investments.isEmpty
                    ? _emptyState(context,
                        'Adicione lançamentos para ver a evolução do patrimônio.')
                    : SizedBox(
                        height: 260,
                        child: PatrimonioBarChart(
                          labels: labels,
                          applied: evolucao.applied,
                          gain: evolucao.gain,
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Consolidação ───────────────────────────────────────────────
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Consolidação do patrimônio',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    InvestmentSegmentedControl(
                      options: const [
                        'Tipo de ativos',
                        'Ativos',
                        'Exposição ao exterior',
                      ],
                      selected: inv.patrimonioConsolidacao,
                      onChanged: (v) => context
                          .read<InvestmentProvider>()
                          .setPatrimonioConsolidacao(v),
                    ),
                    const SizedBox(width: 12),
                    Text('Posição ideal',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: inv.showIdealConsolidacao,
                      onChanged: (v) => context
                          .read<InvestmentProvider>()
                          .setShowIdealConsolidacao(v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: consolidacao.isEmpty
                      ? _emptyState(context,
                          'Sem lançamentos cadastrados para consolidar.')
                      : DonutChartWithLegend(consolidacao),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Ações ──────────────────────────────────────────────────────
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ações',
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (acoesData.isNotEmpty)
                          Text(
                            'Total: ${fmt.format(somaAtivos(acoesData))} • ${acoesData.length} lançamento${acoesData.length != 1 ? 's' : ''}',
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                    const Spacer(),
                    InvestmentSegmentedControl(
                      options: const [
                        'Consolidado',
                        'Por tipo',
                        'Por segmento',
                      ],
                      selected: inv.patrimonioAcoes,
                      onChanged: (v) => context
                          .read<InvestmentProvider>()
                          .setPatrimonioAcoes(v),
                    ),
                    const SizedBox(width: 12),
                    Text('Posição ideal',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: inv.showIdealAcoes,
                      onChanged: (v) => context
                          .read<InvestmentProvider>()
                          .setShowIdealAcoes(v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: acoes.isEmpty
                      ? _emptyState(context,
                          'Sem lançamentos de Ações. Adicione via "Adicionar lançamento".')
                      : DonutChartWithLegend(acoes),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── FIIs ───────────────────────────────────────────────────────
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FIIs',
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (fiisData.isNotEmpty)
                          Text(
                            'Total: ${fmt.format(somaAtivos(fiisData))} • ${fiisData.length} lançamento${fiisData.length != 1 ? 's' : ''}',
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                    const Spacer(),
                    InvestmentSegmentedControl(
                      options: const [
                        'Consolidado',
                        'Por tipo',
                        'Por segmento',
                      ],
                      selected: inv.patrimonioFiis,
                      onChanged: (v) => context
                          .read<InvestmentProvider>()
                          .setPatrimonioFiis(v),
                    ),
                    const SizedBox(width: 12),
                    Text('Posição ideal',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: inv.showIdealFiis,
                      onChanged: (v) => context
                          .read<InvestmentProvider>()
                          .setShowIdealFiis(v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: fiis.isEmpty
                      ? _emptyState(context,
                          'Sem lançamentos de FIIs. Adicione via "Adicionar lançamento".')
                      : DonutChartWithLegend(fiis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Renda Fixa ─────────────────────────────────────────────────
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Renda Fixa',
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (rendaFixaData.isNotEmpty)
                          Text(
                            'Total: ${fmt.format(somaAtivos(rendaFixaData))} • ${rendaFixaData.length} lançamento${rendaFixaData.length != 1 ? 's' : ''}',
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text('Posição ideal',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: inv.showIdealRendaFixa,
                      onChanged: (v) => context
                          .read<InvestmentProvider>()
                          .setShowIdealRendaFixa(v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: rendaFixa.isEmpty
                      ? _emptyState(context,
                          'Sem lançamentos de Renda Fixa. Adicione via "Adicionar lançamento".')
                      : DonutChartWithLegend(rendaFixa),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget de estado vazio padronizado ────────────────────────────────────

  Widget _emptyState(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
