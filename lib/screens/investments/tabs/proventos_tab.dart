import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:financas_inteligentes/models/provento_model.dart';
import 'package:financas_inteligentes/providers/investment_provider.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_shared_widgets.dart';
import 'package:financas_inteligentes/screens/investments/widgets/investment_charts.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/services/import_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ProventosTab extends StatefulWidget {
  const ProventosTab({super.key});

  @override
  State<ProventosTab> createState() => _ProventosTabState();
}

class _ProventosTabState extends State<ProventosTab> {
  final FirestoreService _service = FirestoreService();
  final ImportService _importService = ImportService();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  // ── Chaves de deduplicação ────────────────────────────────────────────────

  String _proventoKey(ProventoModel item) {
    final date = DateFormat('yyyy-MM-dd').format(item.dataPagamento);
    return '${item.ativo}|${item.tipoPagamento}|$date|'
        '${item.valorTotal.toStringAsFixed(2)}|${item.quantidade.toStringAsFixed(6)}';
  }

  String _formatDecimalValue(double value, int decimals) =>
      NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: decimals)
          .format(value);

  // ── Importação CSV ────────────────────────────────────────────────────────

  Future<void> _importProventosCsv() async {
    final inv = context.read<InvestmentProvider>();
    if (inv.importingProventos) return;
    inv.setImportingProventos(true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) {
        inv.setImportingProventos(false);
        return;
      }
      final content = await _readFile(result.files.single);
      final items = _importService.parseProventosCsv(content);
      await _batchInsertProventos(items);
    } catch (e) {
      _snack('Falha ao importar proventos: $e');
    } finally {
      if (mounted) inv.setImportingProventos(false);
    }
  }

  Future<void> _importProventosApi() async {
    final url = await _promptImportUrl('Importar Proventos via API');
    if (url == null) return;
    if (!mounted) return;
    final inv = context.read<InvestmentProvider>();
    inv.setImportingProventos(true);
    try {
      final data = await _importService.fetchJsonList(url);
      final items = _importService.parseProventosJson(data);
      await _batchInsertProventos(items);
    } catch (e) {
      _snack('Falha ao importar proventos: $e');
    } finally {
      if (mounted) inv.setImportingProventos(false);
    }
  }

  Future<void> _batchInsertProventos(List<ProventoModel> items) async {
    final existing = await _service.getProventosOnce();
    final existingKeys = existing.map(_proventoKey).toSet();
    final toInsert = <ProventoModel>[];
    var skipped = 0;
    for (final item in items) {
      final key = _proventoKey(item);
      if (existingKeys.contains(key)) {
        skipped++;
        continue;
      }
      existingKeys.add(key);
      toInsert.add(item);
    }
    await _service.addProventosBatch(toInsert);
    _snack('Proventos importados: ${toInsert.length} • Ignorados: $skipped');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  Future<String?> _promptImportUrl(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'URL da API (JSON)',
            hintText: 'https://...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result != null && result.isNotEmpty ? result : null;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvestmentProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isNarrow = MediaQuery.of(context).size.width < 1100;

    return StreamBuilder<List<ProventoModel>>(
      stream: _service.getProventos(),
      builder: (context, snapshot) {
        final proventos = snapshot.data ?? [];
        final now = DateTime.now();
        final months =
            List.generate(13, (i) => DateTime(now.year, now.month - 12 + i, 1));
        final currentYearLabel = DateFormat('yyyy').format(now);
        final labels =
            months.map((m) => DateFormat('MM/yy').format(m)).toList();
        final received = List<double>.filled(months.length, 0);
        final pending = List<double>.filled(months.length, 0);
        final last12Start = DateTime(now.year, now.month - 11, 1);

        double total12m = 0;
        double totalCarteira = 0;
        final distributionMap = <String, double>{};

        for (final p in proventos) {
          final isPaid = p.status.toLowerCase().contains('pago');
          final dateRef = p.dataPagamento;
          totalCarteira += p.valorTotal;
          if (isPaid &&
              dateRef.isAfter(
                  last12Start.subtract(const Duration(days: 1)))) {
            total12m += p.valorTotal;
            distributionMap.update(p.ativo, (v) => v + p.valorTotal,
                ifAbsent: () => p.valorTotal);
          }
          final idx = months.indexWhere(
              (m) => m.year == dateRef.year && m.month == dateRef.month);
          if (idx >= 0) {
            if (isPaid) {
              received[idx] += p.valorTotal;
            } else {
              pending[idx] += p.valorTotal;
            }
          }
        }

        final mediaMensal = total12m / 12;
        final distEntries = distributionMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final distribution = distEntries.asMap().entries.take(5).map((e) {
          final hue =
              (e.key * 360 / (distEntries.isEmpty ? 1 : distEntries.length)) %
                  360;
          return LegendEntry(
            label: e.value.key,
            amount: e.value.value,
            color: HSVColor.fromAHSV(1, hue, 0.65, 0.85).toColor(),
          );
        }).toList();

        final historicoMap = <int, List<double>>{};
        for (final p in proventos
            .where((p) => p.status.toLowerCase().contains('pago'))) {
          historicoMap.putIfAbsent(
              p.dataPagamento.year, () => List<double>.filled(12, 0));
          historicoMap[p.dataPagamento.year]![p.dataPagamento.month - 1] +=
              p.valorTotal;
        }
        final proventosSorted = [...proventos]
          ..sort((a, b) => b.dataPagamento.compareTo(a.dataPagamento));
        final historicoRows = historicoMap.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key));

        final summaryCard = SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resumo',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Média Mensal (últ. 12 meses)',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(_currency.format(mediaMensal),
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text('/ Criar meta',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.primary)),
                  const Spacer(),
                  Text('0%',
                      style: textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: 0.0,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
                minHeight: 3,
              ),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  Text('Total de 12 meses',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  Icon(Icons.expand_more,
                      size: 18, color: colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 6),
              Text(_currency.format(total12m),
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Divider(),
              Text('Total da carteira',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(_currency.format(totalCarteira),
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Divider(),
              Text('Distribuição de proventos em 12 meses',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: distribution.isEmpty
                    ? const Center(child: Text('Sem proventos no período.'))
                    : DonutChartWithLegend(distribution, showAmount: false),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () {}, child: const Text('Ver todos')),
              ),
            ],
          ),
        );

        final chartCard = SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Evolução de Proventos',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  InvestmentSegmentedControl(
                    options: const ['Mensal', 'Anual'],
                    selected: inv.proventosPeriodo,
                    onChanged: (v) =>
                        context.read<InvestmentProvider>().setProventosPeriodo(v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilterPill('Últimos 12 meses',
                      leading: Icons.calendar_month_outlined),
                  FilterPill('Tipo de ativo', leading: Icons.tune),
                  FilterPill('Ativos',
                      leading: Icons.account_balance_wallet_outlined),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  LegendDot(
                      color: colorScheme.primary,
                      label: 'Proventos recebidos'),
                  const SizedBox(width: 12),
                  LegendDot(
                      color: colorScheme.primaryContainer,
                      label: 'Proventos a receber'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: received.every((v) => v == 0) &&
                        pending.every((v) => v == 0)
                    ? const Center(
                        child: Text('Sem proventos no período.'))
                    : ProventosBarChart(
                        labels: labels,
                        received: received,
                        pending: pending,
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
                    onPressed: inv.importingProventos
                        ? null
                        : _importProventosCsv,
                    icon: inv.importingProventos
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
                        inv.importingProventos ? null : _importProventosApi,
                    icon: const Icon(Icons.link),
                    label: const Text('Importar API'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isNarrow) ...[
                summaryCard,
                const SizedBox(height: 12),
                chartCard,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: summaryCard),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: chartCard),
                  ],
                ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Histórico mensal',
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        StatusPill(
                          'Total  ${_currency.format(total12m)}',
                          background: colorScheme.secondaryContainer,
                          textColor: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 10),
                        FilterPill('Recebidos',
                            leading: Icons.calendar_month_outlined),
                        const SizedBox(width: 8),
                        FilterPill('Tipo de ativo', leading: Icons.tune),
                        const SizedBox(width: 8),
                        FilterPill('Ativos',
                            leading:
                                Icons.account_balance_wallet_outlined),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: historicoRows.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Sem proventos cadastrados.'),
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
                                DataColumn(label: Text('Média')),
                                DataColumn(label: Text('Total')),
                              ],
                              rows: historicoRows.map((entry) {
                                final year = entry.key;
                                final mv = entry.value;
                                final total = mv.fold<double>(
                                    0, (s, v) => s + v);
                                final media = total / 12;
                                final cells = [
                                  year.toString(),
                                  ...mv.map(
                                      (v) => _formatDecimalValue(v, 2)),
                                  _formatDecimalValue(media, 2),
                                  _formatDecimalValue(total, 2),
                                ];
                                return DataRow(
                                    cells: cells
                                        .map((c) => DataCell(Text(c)))
                                        .toList());
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Meus proventos',
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        StatusPill(
                          'Total  ${_currency.format(totalCarteira)}',
                          background: colorScheme.secondaryContainer,
                          textColor: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 10),
                        FilterPill(currentYearLabel,
                            leading: Icons.calendar_month_outlined),
                        const SizedBox(width: 8),
                        FilterPill('Tipo de ativo', leading: Icons.tune),
                        const SizedBox(width: 8),
                        FilterPill('Ativos',
                            leading:
                                Icons.account_balance_wallet_outlined),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: proventosSorted.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Sem proventos cadastrados.'),
                            )
                          : DataTable(
                              columns: const [
                                DataColumn(label: Text('Ativo')),
                                DataColumn(label: Text('Tipo de ativo')),
                                DataColumn(
                                    label: Text('Status do pagamento')),
                                DataColumn(
                                    label: Text('Tipo de pagamento')),
                                DataColumn(label: Text('Data Com')),
                                DataColumn(
                                    label: Text('Data Pagamento')),
                                DataColumn(label: Text('Quantidade')),
                                DataColumn(label: Text('Valor do div.')),
                                DataColumn(label: Text('Valor total')),
                              ],
                              rows: proventosSorted.map((row) {
                                final isPago = row.status
                                    .toLowerCase()
                                    .contains('pago');
                                final statusBg = isPago
                                    ? colorScheme.tertiaryContainer
                                    : colorScheme.secondaryContainer;
                                final statusFg = isPago
                                    ? colorScheme.tertiary
                                    : colorScheme.secondary;
                                return DataRow(cells: [
                                  DataCell(Text(row.ativo)),
                                  DataCell(StatusPill(row.tipoAtivo,
                                      background: colorScheme
                                          .surfaceContainerHighest,
                                      textColor:
                                          colorScheme.onSurfaceVariant)),
                                  DataCell(StatusPill(row.status,
                                      background: statusBg,
                                      textColor: statusFg,
                                      icon: Icons
                                          .monetization_on_outlined)),
                                  DataCell(Text(row.tipoPagamento)),
                                  DataCell(Text(DateFormat('dd/MM/yyyy')
                                      .format(row.dataCom))),
                                  DataCell(Text(DateFormat('dd/MM/yyyy')
                                      .format(row.dataPagamento))),
                                  DataCell(Text(_formatDecimalValue(
                                      row.quantidade, 2))),
                                  DataCell(Text(
                                      _currency.format(row.valorDiv))),
                                  DataCell(Text(
                                      _currency.format(row.valorTotal))),
                                ]);
                              }).toList(),
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
