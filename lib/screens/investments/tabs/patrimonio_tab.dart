import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/providers/investment_provider.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_charts.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PatrimonioTab extends StatelessWidget {
  const PatrimonioTab({super.key, required this.investments});
  final List<InvestmentModel> investments;

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvestmentProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();

    final labels = List.generate(
      12,
      (i) => DateFormat('MM/yy').format(DateTime(now.year, now.month - 11 + i)),
    );

    final base = investments.fold<double>(
        0, (sum, i) => sum + i.valorInvestido.abs());
    final appliedSeed = base > 0 ? base / 12 : 920;
    final gainSeed = base > 0 ? appliedSeed * 0.06 : 40;
    final applied = List<double>.generate(
        12, (i) => appliedSeed + (i * appliedSeed * 0.02));
    final gain = List<double>.generate(
        12, (i) => gainSeed + (i * gainSeed * 0.02));

    final dist = distributionByType(investments);
    final palette = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
    ];

    final consolidacao = dist.isNotEmpty
        ? dist.entries.toList().asMap().entries.map((e) {
            final hue = (e.key * 360 / dist.length) % 360;
            return LegendEntry(
              label: e.value.key,
              amount: e.value.value.abs(),
              color: HSVColor.fromAHSV(1, hue, 0.65, 0.85).toColor(),
            );
          }).toList()
        : <LegendEntry>[
            LegendEntry(label: 'Renda Fixa', amount: 601.15, color: palette[0]),
            LegendEntry(label: 'Ações', amount: 237.82, color: palette[1]),
            LegendEntry(label: 'FIIs', amount: 209.40, color: palette[2]),
          ];

    final acoes = <LegendEntry>[
      LegendEntry(label: 'BBAS3', amount: 50.42, color: palette[0]),
      LegendEntry(label: 'WEGE3', amount: 47.25, color: palette[1]),
      LegendEntry(label: 'ITSA3', amount: 40.98, color: palette[2]),
      LegendEntry(label: 'BBSE3', amount: 34.71, color: palette[3]),
      LegendEntry(label: 'EGIE3', amount: 32.70, color: palette[4]),
      LegendEntry(label: 'KLBN3', amount: 31.76, color: palette[5]),
    ];

    final fiis = <LegendEntry>[
      LegendEntry(label: 'GARE11', amount: 41.75, color: palette[0]),
      LegendEntry(label: 'VGIR11', amount: 39.08, color: palette[1]),
      LegendEntry(label: 'BTCI11', amount: 36.96, color: palette[2]),
      LegendEntry(label: 'VGHF11', amount: 35.25, color: palette[3]),
      LegendEntry(label: 'XPCA11', amount: 34.88, color: palette[4]),
      LegendEntry(label: 'VINO11', amount: 21.48, color: palette[5]),
    ];

    final rendaFixa = <LegendEntry>[
      LegendEntry(
        label: 'CDB - BANCO NUBANK - Pós-Fixado - 100% CDI',
        amount: 601.15,
        color: palette[0],
      ),
    ];

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
                        color: colorScheme.tertiary, label: 'Valor aplicado'),
                    const SizedBox(width: 14),
                    LegendDot(
                        color: colorScheme.tertiaryContainer,
                        label: 'Ganho capital'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: PatrimonioBarChart(
                      labels: labels, applied: applied, gain: gain),
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
                        'Exposição ao exterior'
                      ],
                      selected: inv.patrimonioConsolidacao,
                      onChanged: (v) => context
                          .read<InvestmentProvider>()
                          .setPatrimonioConsolidacao(v),
                    ),
                    const SizedBox(width: 12),
                    Text('Exibir posição ideal',
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
                    child: DonutChartWithLegend(consolidacao)),
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
                    Text('Ações',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    InvestmentSegmentedControl(
                      options: const [
                        'Consolidado',
                        'Por tipo',
                        'Por segmento'
                      ],
                      selected: inv.patrimonioAcoes,
                      onChanged: (v) => context
                          .read<InvestmentProvider>()
                          .setPatrimonioAcoes(v),
                    ),
                    const SizedBox(width: 12),
                    Text('Exibir posição ideal',
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
                SizedBox(height: 240, child: DonutChartWithLegend(acoes)),
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
                    Text('FIIs',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    InvestmentSegmentedControl(
                      options: const [
                        'Consolidado',
                        'Por tipo',
                        'Por segmento'
                      ],
                      selected: inv.patrimonioFiis,
                      onChanged: (v) => context
                          .read<InvestmentProvider>()
                          .setPatrimonioFiis(v),
                    ),
                    const SizedBox(width: 12),
                    Text('Exibir posição ideal',
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
                SizedBox(height: 240, child: DonutChartWithLegend(fiis)),
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
                    Text('Renda Fixa',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('Exibir posição ideal',
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
                SizedBox(height: 240, child: DonutChartWithLegend(rendaFixa)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
