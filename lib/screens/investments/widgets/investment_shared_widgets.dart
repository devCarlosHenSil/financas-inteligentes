import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── Modelo de legenda ─────────────────────────────────────────────────────────

class LegendEntry {
  const LegendEntry({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final double amount;
  final Color color;
}

// ── LegendDot ─────────────────────────────────────────────────────────────────

class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ── SectionCard ───────────────────────────────────────────────────────────────

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.height,
  });
  final Widget child;
  final EdgeInsets padding;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

// ── SummaryCard ───────────────────────────────────────────────────────────────

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
  });
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

// ── FilterPill ────────────────────────────────────────────────────────────────

class FilterPill extends StatelessWidget {
  const FilterPill(this.label, {super.key, this.leading});
  final String label;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              Icon(leading, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Text(label,
                style:
                    textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down,
                size: 16, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── StatusPill ────────────────────────────────────────────────────────────────

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.background,
    this.textColor,
    this.icon,
  });
  final String label;
  final Color? background;
  final Color? textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bg = background ?? colorScheme.surfaceContainerHighest;
    final fg = textColor ?? colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ── InvestmentSegmentedControl ────────────────────────────────────────────────

class InvestmentSegmentedControl extends StatelessWidget {
  const InvestmentSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SegmentedButton<String>(
      segments:
          options.map((opt) => ButtonSegment(value: opt, label: Text(opt))).toList(),
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        side: WidgetStateProperty.all(
            BorderSide(color: colorScheme.outlineVariant)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerLow,
        ),
      ),
    );
  }
}

// ── DonutChartWithLegend ──────────────────────────────────────────────────────

class DonutChartWithLegend extends StatelessWidget {
  const DonutChartWithLegend(
    this.entries, {
    super.key,
    this.showAmount = true,
  });
  final List<LegendEntry> entries;
  final bool showAmount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final total = entries.fold<double>(0, (sum, item) => sum + item.amount);
    if (total <= 0) {
      return const Center(child: Text('Sem dados no momento.'));
    }
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 46,
              sectionsSpace: 2,
              sections: List.generate(entries.length, (index) {
                final entry = entries[index];
                return PieChartSectionData(
                  value: entry.amount,
                  color: entry.color,
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
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final pct = (entry.amount / total) * 100;
              return Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: entry.color,
                        borderRadius: BorderRadius.circular(99)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry.label,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall),
                  ),
                  Text('${pct.toStringAsFixed(2)}%',
                      style: textTheme.bodySmall),
                  if (showAmount) ...[
                    const SizedBox(width: 8),
                    Text(currency.format(entry.amount),
                        style: textTheme.bodySmall),
                  ],
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 80,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 10,
                        width: 80 * (entry.amount / total),
                        decoration: BoxDecoration(
                            color: entry.color,
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── TopListCard ───────────────────────────────────────────────────────────────

class TopListCard extends StatelessWidget {
  const TopListCard(this.title, this.items, {super.key});
  final String title;
  final List<MarketTicker> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      height: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Sem dados no momento.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final positive = item.changePercent >= 0;
                      final displayName =
                          (item.name == null || item.name!.isEmpty || item.name == item.symbol)
                              ? item.symbol
                              : '${item.symbol} • ${item.name}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${index + 1}. $displayName',
                                style: textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(currency.format(item.price)),
                            const SizedBox(width: 6),
                            Text(
                              '${item.changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: positive
                                    ? colorScheme.tertiary
                                    : colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers de distribuição ───────────────────────────────────────────────────

Map<String, double> distributionByType(List<InvestmentModel> data) {
  final dist = <String, double>{};
  for (final inv in data) {
    final parts = inv.nome.split('•').map((e) => e.trim()).toList();
    final type = parts.isNotEmpty ? parts.first : 'Outros';
    dist.update(type, (v) => v + inv.valorInvestido,
        ifAbsent: () => inv.valorInvestido);
  }
  dist.removeWhere((_, value) => value <= 0);
  return dist;
}

Map<String, List<InvestmentModel>> groupedByType(List<InvestmentModel> data) {
  final groups = <String, List<InvestmentModel>>{};
  for (final inv in data) {
    final parts = inv.nome.split('•').map((e) => e.trim()).toList();
    final type = parts.isNotEmpty ? parts.first : 'Outros';
    groups.putIfAbsent(type, () => []).add(inv);
  }
  return groups;
}
