import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:financas_inteligentes/models/rentabilidade_model.dart';
import 'package:financas_inteligentes/providers/investment_provider.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_charts.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_shared_widgets.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/services/import_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class RentabilidadeTab extends StatefulWidget {
  const RentabilidadeTab({super.key});

  @override
  State<RentabilidadeTab> createState() => _RentabilidadeTabState();
}

class _RentabilidadeTabState extends State<RentabilidadeTab> {
  final FirestoreService _service = FirestoreService();
  final ImportService _importService = ImportService();

  String _rentabilidadeKey(RentabilidadeModel item) {
    final date = DateFormat('yyyy-MM').format(item.data);
    return '$date|${item.rentabilidade.toStringAsFixed(4)}|${item.cdi.toStringAsFixed(4)}';
  }

  Future<void> _importCsv() async {
    final inv = context.read<InvestmentProvider>();
    if (inv.importingRentabilidade) return;
    inv.setImportingRentabilidade(true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) {
        inv.setImportingRentabilidade(false);
        return;
      }
      final content = await _readFile(result.files.single);
      final items = _importService.parseRentabilidadeCsv(content);
      await _batchInsert(items);
    } catch (e) {
      _snack('Falha ao importar rentabilidade: $e');
    } finally {
      if (mounted) inv.setImportingRentabilidade(false);
    }
  }

  Future<void> _importApi() async {
    final url = await _promptUrl('Importar Rentabilidade via API');
    if (url == null) return;
    if (!mounted) return;
    final inv = context.read<InvestmentProvider>();
    inv.setImportingRentabilidade(true);
    try {
      final data = await _importService.fetchJsonList(url);
      final items = _importService.parseRentabilidadeJson(data);
      await _batchInsert(items);
    } catch (e) {
      _snack('Falha ao importar rentabilidade: $e');
    } finally {
      if (mounted) inv.setImportingRentabilidade(false);
    }
  }

  Future<void> _batchInsert(List<RentabilidadeModel> items) async {
    final existing = await _service.getRentabilidadeOnce();
    final existingKeys = existing.map(_rentabilidadeKey).toSet();
    final toInsert = <RentabilidadeModel>[];
    var skipped = 0;
    for (final item in items) {
      final key = _rentabilidadeKey(item);
      if (existingKeys.contains(key)) {
        skipped++;
        continue;
      }
      existingKeys.add(key);
      toInsert.add(item);
    }
    await _service.addRentabilidadeBatch(toInsert);
    _snack('Rentabilidade importada: ${toInsert.length} • Ignorados: $skipped');
  }

  Future<String> _readFile(PlatformFile file) async {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Arquivo inválido.');
      return utf8.decode(bytes);
    }
    final path = file.path;
    if (path == null) throw Exception('Arquivo inválido.');
    return File(path).readAsString();
  }

  Future<String?> _promptUrl(String title) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'URL da API (JSON)', hintText: 'https://...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result != null && result.isNotEmpty ? result : null;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvestmentProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isNarrow = MediaQuery.of(context).size.width < 1100;

    return StreamBuilder<List<RentabilidadeModel>>(
      stream: _service.getRentabilidade(),
      builder: (context, snapshot) {
        final entries = [...(snapshot.data ?? [])]
          ..sort((a, b) => a.data.compareTo(b.data));

        double compoundPercent(Iterable<double> values) {
          var acc = 1.0;
          for (final v in values) {
            acc *= 1 + (v / 100);
          }
          return (acc - 1) * 100;
        }

        String pct(double value) =>
            '${value.toStringAsFixed(2).replaceAll('.', ',')}%';

        final now = DateTime.now();
        final last12Start = DateTime(now.year, now.month - 11, 1);
        final last12 = entries
            .where((e) => e.data
                .isAfter(last12Start.subtract(const Duration(days: 1))))
            .toList();

        final totalReturn = entries.isEmpty
            ? 0.0
            : compoundPercent(entries.map((e) => e.rentabilidade));
        final totalCdi = entries.isEmpty
            ? 0.0
            : compoundPercent(entries.map((e) => e.cdi));
        final last12Return = last12.isEmpty
            ? 0.0
            : compoundPercent(last12.map((e) => e.rentabilidade));
        final last12Cdi = last12.isEmpty
            ? 0.0
            : compoundPercent(last12.map((e) => e.cdi));
        final lastMonth = entries.isNotEmpty ? entries.last : null;

        final seriesEntries =
            entries.length > 24 ? entries.sublist(entries.length - 24) : entries;
        final rentSeries = <double>[];
        final cdiSeries = <double>[];
        var rentAcc = 1.0;
        var cdiAcc = 1.0;
        for (final e in seriesEntries) {
          rentAcc *= 1 + (e.rentabilidade / 100);
          cdiAcc *= 1 + (e.cdi / 100);
          rentSeries.add((rentAcc - 1) * 100);
          cdiSeries.add((cdiAcc - 1) * 100);
        }

        final byYear = <int, List<RentabilidadeModel?>>{};
        for (final e in entries) {
          byYear.putIfAbsent(
              e.data.year, () => List<RentabilidadeModel?>.filled(12, null));
          byYear[e.data.year]![e.data.month - 1] = e;
        }
        final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
        final yearsAsc = [...years]..sort();
        double acumulado = 1.0;
        final acumuladoByYear = <int, double>{};
        for (final year in yearsAsc) {
          final months =
              byYear[year] ?? List<RentabilidadeModel?>.filled(12, null);
          final yr = compoundPercent(months
              .whereType<RentabilidadeModel>()
              .map((e) => e.rentabilidade));
          acumulado *= 1 + (yr / 100);
          acumuladoByYear[year] = (acumulado - 1) * 100;
        }

        final tableRows = <List<String>>[];
        for (final year in years) {
          final months =
              byYear[year] ?? List<RentabilidadeModel?>.filled(12, null);
          final monthValues = months
              .map((e) => e == null ? '-' : pct(e.rentabilidade))
              .toList();
          final yr = compoundPercent(months
              .whereType<RentabilidadeModel>()
              .map((e) => e.rentabilidade));
          tableRows.add([
            year.toString(),
            ...monthValues,
            pct(yr),
            pct(acumuladoByYear[year] ?? 0),
          ]);
        }

        final totalColor =
            totalReturn >= 0 ? colorScheme.tertiary : colorScheme.error;
        final last12Color =
            last12Return >= 0 ? colorScheme.tertiary : colorScheme.error;
        final lastMonthColor = (lastMonth?.rentabilidade ?? 0) >= 0
            ? colorScheme.tertiary
            : colorScheme.error;

        Widget kpiCard(
            String title, double value, double cdiValue, Color color) {
          final diff = value - cdiValue;
          return SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(pct(value),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 8),
                Text(
                  '${diff.toStringAsFixed(2).replaceAll('.', ',')}% '
                  '${diff >= 0 ? 'acima' : 'abaixo'} do CDI',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        final kpiCards = Column(
          children: [
            kpiCard('Total', totalReturn, totalCdi, totalColor),
            const SizedBox(height: 12),
            kpiCard(
                'Últimos 12 meses', last12Return, last12Cdi, last12Color),
            const SizedBox(height: 12),
            kpiCard(
              'Último mês',
              lastMonth?.rentabilidade ?? 0,
              lastMonth?.cdi ?? 0,
              lastMonthColor,
            ),
          ],
        );

        final chartCard = SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Rentabilidade comparada com índices',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  FilterPill('Desde o início',
                      leading: Icons.calendar_month_outlined),
                  const SizedBox(width: 8),
                  FilterPill('Todos os tipos', leading: Icons.tune),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  LegendDot(
                      color: colorScheme.primary,
                      label: 'Rentabilidade'),
                  LegendDot(color: colorScheme.secondary, label: 'CDI'),
                  LegendDot(
                      color: colorScheme.onSurfaceVariant, label: 'IPCA'),
                  LegendDot(
                      color: colorScheme.onSurfaceVariant, label: 'IFIX'),
                  LegendDot(
                      color: colorScheme.onSurfaceVariant, label: 'IBOV'),
                  LegendDot(
                      color: colorScheme.onSurfaceVariant, label: 'SMLL'),
                  LegendDot(
                      color: colorScheme.onSurfaceVariant, label: 'IDIV'),
                  LegendDot(
                      color: colorScheme.onSurfaceVariant,
                      label: 'IVVB11'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: rentSeries.isEmpty
                    ? const Center(
                        child: Text('Sem dados de rentabilidade.'))
                    : RentabilidadeLineChart(
                        rentabilidade: rentSeries,
                        cdi: cdiSeries,
                        labelDates: seriesEntries
                            .map<DateTime>((e) => e.data)
                            .toList(),
                      ),
              ),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed:
                        inv.importingRentabilidade ? null : _importCsv,
                    icon: inv.importingRentabilidade
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file),
                    label: const Text('Importar CSV'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        inv.importingRentabilidade ? null : _importApi,
                    icon: const Icon(Icons.link),
                    label: const Text('Importar API'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isNarrow) ...[
                kpiCards,
                const SizedBox(height: 12),
                chartCard,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 260, child: kpiCards),
                    const SizedBox(width: 12),
                    Expanded(child: chartCard),
                  ],
                ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rentabilidade',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: tableRows.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Sem dados de rentabilidade.'),
                            )
                          : DataTable(
                              columns: const [
                                DataColumn(label: Text('Ano')),
                                DataColumn(label: Text('Jan')),
                                DataColumn(label: Text('Fev')),
                                DataColumn(label: Text('Mar')),
                                DataColumn(label: Text('Abr')),
                                DataColumn(label: Text('Mai')),
                                DataColumn(label: Text('Jun')),
                                DataColumn(label: Text('Jul')),
                                DataColumn(label: Text('Ago')),
                                DataColumn(label: Text('Set')),
                                DataColumn(label: Text('Out')),
                                DataColumn(label: Text('Nov')),
                                DataColumn(label: Text('Dez')),
                                DataColumn(label: Text('Ano')),
                                DataColumn(label: Text('Acumulado')),
                              ],
                              rows: tableRows
                                  .map((row) => DataRow(
                                      cells: row
                                          .map((c) => DataCell(Text(c)))
                                          .toList()))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
