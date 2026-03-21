import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── EvolutionBarChart ─────────────────────────────────────────────────────────

class EvolutionBarChart extends StatelessWidget {
  const EvolutionBarChart(this.data, {super.key});
  final List<InvestmentModel> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final months =
        List.generate(12, (i) => DateTime(now.year, now.month - 11 + i));

    final values = months.map((month) {
      return data
          .where((inv) =>
              inv.data.year == month.year && inv.data.month == month.month)
          .fold<double>(0, (sum, inv) => sum + inv.valorInvestido);
    }).toList();

    final maxY =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 10 : maxY * 1.3,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  DateFormat('MM/yy').format(months[idx]),
                  style: textTheme.bodySmall?.copyWith(
                      fontSize: 10, color: colorScheme.onSurfaceVariant),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          values.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index] < 0 ? 0 : values[index],
                color: colorScheme.tertiary,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── DistributionPieChart ──────────────────────────────────────────────────────

class DistributionPieChart extends StatelessWidget {
  const DistributionPieChart(this.dist, {super.key});
  final Map<String, double> dist;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = dist.values.fold<double>(0, (sum, v) => sum + v);

    if (dist.isEmpty || total <= 0) {
      return const Center(child: Text('Sem dados de carteira para distribuir.'));
    }

    final entries = dist.entries.toList();
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 48,
              sectionsSpace: 2,
              sections: List.generate(entries.length, (i) {
                final entry = entries[i];
                final hue = (entry.key.codeUnits
                            .fold<int>(0, (a, b) => a + b) %
                        360)
                    .toDouble();
                return PieChartSectionData(
                  value: entry.value,
                  color: HSVColor.fromAHSV(1, hue, 0.65, 0.85).toColor(),
                  title: '',
                  radius: 70,
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final e = entries[index];
              final pct = (e.value / total) * 100;
              final hue = (e.key.codeUnits.fold<int>(0, (a, b) => a + b) % 360)
                  .toDouble();
              return Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(1, hue, 0.65, 0.85).toColor(),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(e.key, overflow: TextOverflow.ellipsis)),
                  Text('${pct.toStringAsFixed(1)}%',
                      style: textTheme.bodySmall),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── ProventosBarChart ─────────────────────────────────────────────────────────

class ProventosBarChart extends StatelessWidget {
  const ProventosBarChart({
    super.key,
    required this.labels,
    required this.received,
    required this.pending,
  });
  final List<String> labels;
  final List<double> received;
  final List<double> pending;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxValue = List.generate(
      labels.length,
      (i) => received[i] + pending[i],
    ).fold<double>(0, (max, v) => v > max ? v : max);

    return BarChart(
      BarChartData(
        maxY: maxValue <= 0 ? 10 : maxValue * 1.3,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(labels[idx],
                      style: textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant)),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxValue <= 0 ? 2 : maxValue / 4,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          labels.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: received[index] + pending[index],
                width: 18,
                borderRadius: BorderRadius.circular(4),
                rodStackItems: [
                  BarChartRodStackItem(0, received[index], colorScheme.primary),
                  BarChartRodStackItem(
                    received[index],
                    received[index] + pending[index],
                    colorScheme.primaryContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PatrimonioBarChart ────────────────────────────────────────────────────────

class PatrimonioBarChart extends StatelessWidget {
  const PatrimonioBarChart({
    super.key,
    required this.labels,
    required this.applied,
    required this.gain,
  });
  final List<String> labels;
  final List<double> applied;
  final List<double> gain;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxValue = List.generate(
      labels.length,
      (i) => applied[i] + gain[i],
    ).fold<double>(0, (max, v) => v > max ? v : max);

    return BarChart(
      BarChartData(
        maxY: maxValue <= 0 ? 10 : maxValue * 1.2,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(labels[idx],
                      style: textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          labels.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: applied[index] + gain[index],
                width: 20,
                borderRadius: BorderRadius.circular(4),
                rodStackItems: [
                  BarChartRodStackItem(0, applied[index], colorScheme.tertiary),
                  BarChartRodStackItem(
                    applied[index],
                    applied[index] + gain[index],
                    colorScheme.tertiaryContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── RentabilidadeLineChart ────────────────────────────────────────────────────

class RentabilidadeLineChart extends StatelessWidget {
  const RentabilidadeLineChart({
    super.key,
    required this.rentabilidade,
    required this.cdi,
    this.labelDates,
  });
  final List<double> rentabilidade;
  final List<double> cdi;
  final List<DateTime>? labelDates;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final values = [...rentabilidade, ...cdi];
    final maxValue =
        values.fold<double>(0, (max, v) => v > max ? v : max);
    final minValue =
        values.fold<double>(0, (min, v) => v < min ? v : min);
    final dates = labelDates ??
        List.generate(rentabilidade.length, (i) {
          final now = DateTime.now();
          return DateTime(
              now.year, now.month - (rentabilidade.length - 1 - i), 1);
        });

    return LineChart(
      LineChartData(
        minY: minValue < 0 ? minValue * 1.2 : 0,
        maxY: maxValue <= 0 ? 10 : maxValue * 1.2,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= dates.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  DateFormat('MM/yy').format(dates[idx]),
                  style: textTheme.bodySmall?.copyWith(
                      fontSize: 10, color: colorScheme.onSurfaceVariant),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(rentabilidade.length,
                (i) => FlSpot(i.toDouble(), rentabilidade[i])),
            isCurved: true,
            color: colorScheme.primary,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
          LineChartBarData(
            spots: List.generate(
                cdi.length, (i) => FlSpot(i.toDouble(), cdi[i])),
            isCurved: true,
            color: colorScheme.secondary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
