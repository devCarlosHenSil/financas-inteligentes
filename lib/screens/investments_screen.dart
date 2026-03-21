import 'dart:async';

import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/models/provento_model.dart';
import 'package:financas_inteligentes/models/rentabilidade_model.dart';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/services/import_service.dart';
import 'package:financas_inteligentes/widgets/theme_mode_toggle.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  InvestmentsScreenState createState() => InvestmentsScreenState();
}

class InvestmentsScreenState extends State<InvestmentsScreen> {
  final FirestoreService _service = FirestoreService();
  final ApiService _api = ApiService();
  final ImportService _importService = ImportService();
  final NumberFormat _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  final List<String> _tiposCarteira = const [
    'Ações',
    'Fundos de Investimentos',
    'FIIs',
    'Criptomoedas',
    'Stock',
    'Reit',
    'BDRs',
    'ETF',
    'ETFs Internacionais',
    'Tesouro Direto',
    'Renda Fixa (CDB,LCI,LCA,LC,LF,RDB)',
    'Outros',
  ];

  Map<String, double> _quotes = {'USD': 0, 'EUR': 0, 'BTC': 0, 'ETH': 0};
  List<MarketTicker> _topEtfs = [];
  List<MarketTicker> _topFiis = [];
  List<MarketTicker> _topStocks = [];
  bool _loadingMarket = true;

  Timer? _refreshTimer;
  String _proventosPeriodo = 'Mensal';
  String _patrimonioConsolidacao = 'Tipo de ativos';
  String _patrimonioAcoes = 'Consolidado';
  String _patrimonioFiis = 'Consolidado';
  final String _rentabilidadeRange = 'Desde o início';
  bool _showIdealConsolidacao = false;
  bool _showIdealAcoes = false;
  bool _showIdealFiis = false;
  bool _showIdealRendaFixa = false;
  bool _importingProventos = false;
  bool _importingRentabilidade = false;

  bool _isUsdType(String tipo) =>
      tipo == 'Stock' || tipo == 'Reit' || tipo == 'ETFs Internacionais';

  bool _isFundosInvestimentos(String tipo) => tipo == 'Fundos de Investimentos';

  bool _isRendaFixa(String tipo) => tipo == 'Renda Fixa (CDB,LCI,LCA,LC,LF,RDB)';

  bool _isOutros(String tipo) => tipo == 'Outros';

  double _parsePtBrNumber(String value) {
    final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  String _formatCurrency(double value, {String symbol = 'R\$'}) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: symbol, decimalDigits: 2)
        .format(value);
  }

  String _formatDecimalValue(double value, int decimals) {
    return NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: decimals)
        .format(value);
  }

  String _formatDecimalInput(double value, int decimals) {
    return NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: decimals)
        .format(value <= 0 ? 0 : value);
  }

  @override
  void initState() {
    super.initState();
    _refreshMarketData();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshMarketData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshMarketData() async {
    setState(() => _loadingMarket = true);

    final quotes = await _api.getRealtimeQuotes();
    final etfs = await _api.getTopEtfs();
    final fiis = await _api.getTopFiis();
    final stocks = await _api.getTopStocks();

    if (!mounted) return;

    setState(() {
      if (quotes.values.any((v) => v > 0)) {
        _quotes = quotes;
      }
      if (etfs.isNotEmpty) _topEtfs = etfs;
      if (fiis.isNotEmpty) _topFiis = fiis;
      if (stocks.isNotEmpty) _topStocks = stocks;
      _loadingMarket = false;
    });
  }

  Future<void> _openLaunchDialog() async {
    final ativoController = TextEditingController();
    final quantidadeController = TextEditingController(text: '1');
    final precoController = TextEditingController(text: '0,00');
    final custosController = TextEditingController(text: '0,00');
    final valorInvestidoController = TextEditingController(text: '0,01');
    final precoCotaController = TextEditingController(text: '0,00000000');
    final emissorController = TextEditingController();
    final taxaController = TextEditingController(text: '0,00');
    final valorRendaFixaController = TextEditingController(text: '0,00');
    final nomeOutroController = TextEditingController();
    final jurosAnualController = TextEditingController(text: '0,00');

    String tipoSelecionado = _tiposCarteira.first;
    DateTime dataSelecionada = DateTime.now();
    DateTime dataVencimento = DateTime.now().add(const Duration(days: 1));
    bool isCompra = true;
    bool liquidezDiaria = false;
    String tipoTitulo = 'CDB';
    String indexador = 'CDI';
    String formaRendaFixa = 'Pós-fixado';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;
            final isFundos = _isFundosInvestimentos(tipoSelecionado);
            final isUsd = _isUsdType(tipoSelecionado);
            final isRendaFixa = _isRendaFixa(tipoSelecionado);
            final isOutros = _isOutros(tipoSelecionado);
            final isCrypto = tipoSelecionado == 'Criptomoedas';

            final quantidade = _parsePtBrNumber(quantidadeController.text);
            final preco = _parsePtBrNumber(precoController.text);
            final custos = _parsePtBrNumber(custosController.text);
            final valorInvestido = _parsePtBrNumber(valorInvestidoController.text);
            final precoCota = _parsePtBrNumber(precoCotaController.text);
            final valorRendaFixa = _parsePtBrNumber(valorRendaFixaController.text);
            final jurosAnual = _parsePtBrNumber(jurosAnualController.text);

            final totalAcoes = quantidade * preco + custos;
            final totalFundos = valorInvestido + custos;
            final totalRendaFixa = valorRendaFixa + custos;
            final totalOutros = preco + custos + jurosAnual;

            final total = isFundos
                ? totalFundos
                : isRendaFixa
                    ? totalRendaFixa
                    : isOutros
                        ? totalOutros
                        : totalAcoes;

            final totalCotas = precoCota > 0 ? valorInvestido / precoCota : 0.0;

            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Adicionar Lançamento',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Compra'), icon: Icon(Icons.add_shopping_cart)),
                        ButtonSegment(value: false, label: Text('Venda'), icon: Icon(Icons.sell_outlined)),
                      ],
                      selected: {isCompra},
                      onSelectionChanged: (value) => setDialogState(() => isCompra = value.first),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: tipoSelecionado,
                      decoration: const InputDecoration(labelText: 'Tipo de ativo'),
                      items: _tiposCarteira
                          .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        tipoSelecionado = value ?? _tiposCarteira.first;
                        ativoController.clear();
                      }),
                    ),
                    const SizedBox(height: 10),
                    if (!isRendaFixa && !isOutros)
                      _AssetSearchField(
                        controller: ativoController,
                        tipoSelecionado: tipoSelecionado,
                        isUsd: isUsd,
                        isFundos: isFundos,
                        onSelect: (asset) {
                          if (isFundos) {
                            precoCotaController.text = _formatDecimalInput(asset.price, 8);
                          } else {
                            final decimals = isCrypto || isUsd ? 8 : 2;
                            precoController.text = _formatDecimalInput(asset.price, decimals);
                          }
                          setDialogState(() {});
                        },
                        api: _api,
                      ),
                    if (isOutros)
                      TextField(
                        controller: nomeOutroController,
                        decoration: const InputDecoration(labelText: 'Nome do ativo'),
                      ),
                    if (isRendaFixa) ...[
                      TextField(
                        controller: emissorController,
                        decoration: const InputDecoration(labelText: 'Emissor'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: tipoTitulo,
                        decoration: const InputDecoration(labelText: 'Tipo de título'),
                        items: const [
                          'CDB',
                          'LCI',
                          'LCA',
                          'LC',
                          'LF',
                          'RDB',
                          'Debênture',
                          'CRI',
                          'CRA',
                          'CCB',
                        ]
                            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) => setDialogState(() => tipoTitulo = value ?? 'CDB'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: indexador,
                        decoration: const InputDecoration(labelText: 'Indexador'),
                        items: const ['CDI', 'CDI+', 'IPCA+']
                            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) => setDialogState(() => indexador = value ?? 'CDI'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: taxaController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [PtBrDecimalInputFormatter(decimalDigits: 2, suffix: ' %')],
                        decoration: const InputDecoration(labelText: 'Taxa do CDI'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: formaRendaFixa,
                        decoration: const InputDecoration(labelText: 'Forma (Opcional)'),
                        items: const ['Pós-fixado', 'Pré-fixado']
                            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) => setDialogState(() => formaRendaFixa = value ?? 'Pós-fixado'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dataSelecionada,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setDialogState(() => dataSelecionada = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: isCompra ? 'Data da compra' : 'Data da venda',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(DateFormat('dd/MM/yyyy').format(dataSelecionada)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (!isFundos && !isRendaFixa)
                          Expanded(
                            child: TextField(
                              controller: quantidadeController,
                              keyboardType: isCrypto
                                  ? const TextInputType.numberWithOptions(decimal: true)
                                  : TextInputType.number,
                              inputFormatters: isCrypto
                                  ? [PtBrDecimalInputFormatter(decimalDigits: 8)]
                                  : [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: isCrypto ? 'Quantidade (fração)' : 'Quantidade',
                              ),
                            ),
                          ),
                        if (isRendaFixa)
                          Expanded(
                            child: TextField(
                              controller: valorRendaFixaController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [PtBrDecimalInputFormatter(decimalDigits: 2)],
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(labelText: 'Valor em R\$ (Opcional)'),
                            ),
                          ),
                      ],
                    ),
                    if (isFundos) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: valorInvestidoController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [PtBrDecimalInputFormatter(decimalDigits: 2)],
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(labelText: 'Valor investido'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: precoCotaController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [PtBrDecimalInputFormatter(decimalDigits: 8)],
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(labelText: 'Preço da cota em R\$'),
                            ),
                          ),
                        ],
                      ),
                    ] else if (!isRendaFixa) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: precoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          PtBrDecimalInputFormatter(decimalDigits: isCrypto || isUsd ? 8 : 2),
                        ],
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(labelText: isUsd ? 'Preço em US\$' : 'Preço em R\$'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (!isRendaFixa)
                      TextField(
                        controller: custosController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [PtBrDecimalInputFormatter(decimalDigits: 2)],
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(labelText: 'Outros custos (Opcional)'),
                      ),
                    if (isRendaFixa) ...[
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Liquidez diária'),
                        value: liquidezDiaria,
                        onChanged: (value) => setDialogState(() => liquidezDiaria = value),
                      ),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dataVencimento,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 36500)),
                          );
                          if (picked != null) {
                            setDialogState(() => dataVencimento = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Data de vencimento',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(DateFormat('dd/MM/yyyy').format(dataVencimento)),
                        ),
                      ),
                    ],
                    if (isOutros) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: jurosAnualController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [PtBrDecimalInputFormatter(decimalDigits: 2)],
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(labelText: 'Juros anual'),
                      ),
                    ],
                    if (isFundos) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Total de cotas',
                              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(
                              _formatDecimalValue(totalCotas, 8),
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Valor total',
                            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            _formatCurrency(total, symbol: isUsd ? 'US\$' : 'R\$'),
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () async {
                            final ativo = isRendaFixa
                                ? '${emissorController.text.trim()} • $tipoTitulo • $indexador'
                                : isOutros
                                    ? nomeOutroController.text.trim()
                                    : ativoController.text.trim();

                            if (ativo.isEmpty || total <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Preencha ativo e valores válidos.')),
                              );
                              return;
                            }

                            final valorLancamento = isCompra ? total : -total;
                            final operacao = isCompra ? 'Compra' : 'Venda';

                            await _service.addInvestment(
                              InvestmentModel(
                                id: '',
                                nome: '$tipoSelecionado • $ativo • $operacao',
                                valorInvestido: valorLancamento,
                                data: dataSelecionada,
                              ),
                            );

                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar Lançamento'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    ativoController.dispose();
    quantidadeController.dispose();
    precoController.dispose();
    custosController.dispose();
    valorInvestidoController.dispose();
    precoCotaController.dispose();
    emissorController.dispose();
    taxaController.dispose();
    valorRendaFixaController.dispose();
    nomeOutroController.dispose();
    jurosAnualController.dispose();
  }

  Map<String, double> _distributionByType(List<InvestmentModel> data) {
    final dist = <String, double>{};
    for (final inv in data) {
      final parts = inv.nome.split('•').map((e) => e.trim()).toList();
      final type = parts.isNotEmpty ? parts.first : 'Outros';
      dist.update(type, (v) => v + inv.valorInvestido, ifAbsent: () => inv.valorInvestido);
    }
    dist.removeWhere((_, value) => value <= 0);
    return dist;
  }

  Map<String, List<InvestmentModel>> _groupedByType(List<InvestmentModel> data) {
    final groups = <String, List<InvestmentModel>>{};
    for (final inv in data) {
      final parts = inv.nome.split('•').map((e) => e.trim()).toList();
      final type = parts.isNotEmpty ? parts.first : 'Outros';
      groups.putIfAbsent(type, () => []).add(inv);
    }
    return groups;
  }

  Widget _summaryCard({
    required String title,
    required String value,
    String? subtitle,
    IconData? icon,
  }) {
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
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _distributionChart(List<InvestmentModel> data) {
    final dist = _distributionByType(data);
    final total = dist.values.fold<double>(0, (sum, value) => sum + value);

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
                final hue = (entry.key.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
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
              return Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(
                        1,
                        (e.key.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble(),
                        0.65,
                        0.85,
                      ).toColor(),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis)),
                  Text('${pct.toStringAsFixed(1)}%'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _evolutionChart(List<InvestmentModel> data) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final months = List.generate(12, (i) => DateTime(now.year, now.month - 11 + i));
    final values = <double>[];

    for (final month in months) {
      final monthValue = data
          .where((inv) => inv.data.year == month.year && inv.data.month == month.month)
          .fold<double>(0, (sum, inv) => sum + inv.valorInvestido);
      values.add(monthValue);
    }

    final maxY = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 10 : maxY * 1.3,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                return Text(
                  DateFormat('MM/yy').format(months[idx]),
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
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

  Widget _sectionCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double? height,
  }) {
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

  Widget _filterPill(String label, {IconData? leading}) {
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
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, size: 16, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    String label, {
    Color? background,
    Color? textColor,
    IconData? icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bg = background ?? colorScheme.surfaceContainerHighest;
    final fg = textColor ?? colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
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

  Widget _segmentedControl({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SegmentedButton<String>(
      segments: options.map((opt) => ButtonSegment(value: opt, label: Text(opt))).toList(),
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        side: WidgetStateProperty.all(BorderSide(color: colorScheme.outlineVariant)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerLow,
        ),
      ),
    );
  }

  Widget _donutChartWithLegend(List<_LegendEntry> entries, {bool showAmount = true}) {
    final textTheme = Theme.of(context).textTheme;
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
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.label,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(2)}%',
                    style: textTheme.bodySmall,
                  ),
                  if (showAmount) ...[
                    const SizedBox(width: 8),
                    Text(
                      _currency.format(entry.amount),
                      style: textTheme.bodySmall,
                    ),
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
                          borderRadius: BorderRadius.circular(6),
                        ),
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

  Widget _proventosBarChart(List<String> labels, List<double> received, List<double> pending) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxValue = List.generate(
      labels.length,
      (index) => received[index] + pending[index],
    ).fold<double>(0, (max, value) => value > max ? value : max);
    return BarChart(
      BarChartData(
        maxY: maxValue <= 0 ? 10 : maxValue * 1.3,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    labels[idx],
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
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

  Widget _patrimonioBarChart(List<String> labels, List<double> applied, List<double> gain) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxValue = List.generate(
      labels.length,
      (index) => applied[index] + gain[index],
    ).fold<double>(0, (max, value) => value > max ? value : max);
    return BarChart(
      BarChartData(
        maxY: maxValue <= 0 ? 10 : maxValue * 1.2,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    labels[idx],
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
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

  Widget _rentabilidadeLineChart(List<double> rentabilidade, List<double> cdi, {List<DateTime>? labels}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final values = [...rentabilidade, ...cdi];
    final maxValue = values.fold<double>(0, (max, value) => value > max ? value : max);
    final minValue = values.fold<double>(0, (min, value) => value < min ? value : min);
    final labelDates = labels ?? List.generate(rentabilidade.length, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - (rentabilidade.length - 1 - i), 1);
    });
    return LineChart(
      LineChartData(
        minY: minValue < 0 ? minValue * 1.2 : 0,
        maxY: maxValue <= 0 ? 10 : maxValue * 1.2,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labelDates.length) return const SizedBox.shrink();
                final date = labelDates[idx];
                final label = DateFormat('MM/yy').format(date);
                return Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(rentabilidade.length, (index) => FlSpot(index.toDouble(), rentabilidade[index])),
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
            spots: List.generate(cdi.length, (index) => FlSpot(index.toDouble(), cdi[index])),
            isCurved: true,
            color: colorScheme.secondary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Future<void> _importProventosCsv() async {
    if (_importingProventos) return;
    setState(() => _importingProventos = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _importingProventos = false);
        return;
      }
      final file = result.files.single;
      String content;
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception('Arquivo inválido.');
        }
        content = utf8.decode(bytes);
      } else {
        final path = file.path;
        if (path == null) {
          throw Exception('Arquivo inválido.');
        }
        content = await File(path).readAsString();
      }

      final items = _importService.parseProventosCsv(content);
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proventos importados: ${toInsert.length} • Ignorados: $skipped')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao importar proventos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importingProventos = false);
    }
  }

  Future<void> _importRentabilidadeCsv() async {
    if (_importingRentabilidade) return;
    setState(() => _importingRentabilidade = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _importingRentabilidade = false);
        return;
      }
      final file = result.files.single;
      String content;
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception('Arquivo inválido.');
        }
        content = utf8.decode(bytes);
      } else {
        final path = file.path;
        if (path == null) {
          throw Exception('Arquivo inválido.');
        }
        content = await File(path).readAsString();
      }

      final items = _importService.parseRentabilidadeCsv(content);
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rentabilidade importada: ${toInsert.length} • Ignorados: $skipped')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao importar rentabilidade: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importingRentabilidade = false);
    }
  }

  Future<void> _importProventosApi() async {
    final url = await _promptImportUrl('Importar Proventos via API');
    if (url == null) return;
    setState(() => _importingProventos = true);
    try {
      final data = await _importService.fetchJsonList(url);
      final items = _importService.parseProventosJson(data);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proventos importados: ${toInsert.length} • Ignorados: $skipped')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao importar proventos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importingProventos = false);
    }
  }

  Future<void> _importRentabilidadeApi() async {
    final url = await _promptImportUrl('Importar Rentabilidade via API');
    if (url == null) return;
    setState(() => _importingRentabilidade = true);
    try {
      final data = await _importService.fetchJsonList(url);
      final items = _importService.parseRentabilidadeJson(data);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rentabilidade importada: ${toInsert.length} • Ignorados: $skipped')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao importar rentabilidade: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importingRentabilidade = false);
    }
  }

  Future<String?> _promptImportUrl(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'URL da API (JSON)',
              hintText: 'https://...',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Importar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result != null && result.isNotEmpty ? result : null;
  }

  String _proventoKey(ProventoModel item) {
    final date = DateFormat('yyyy-MM-dd').format(item.dataPagamento);
    return '${item.ativo}|${item.tipoPagamento}|$date|${item.valorTotal.toStringAsFixed(2)}|${item.quantidade.toStringAsFixed(6)}';
  }

  String _rentabilidadeKey(RentabilidadeModel item) {
    final date = DateFormat('yyyy-MM').format(item.data);
    return '$date|${item.rentabilidade.toStringAsFixed(4)}|${item.cdi.toStringAsFixed(4)}';
  }

  Widget _buildResumoTab({
    required List<InvestmentModel> investments,
    required double patrimonio,
    required double totalInvestido,
    required Map<String, double> dist,
    required Map<String, List<InvestmentModel>> grouped,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo dos Investimentos',
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (_loadingMarket) const LinearProgressIndicator(),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 1100
                ? 4
                : MediaQuery.of(context).size.width > 640
                    ? 2
                    : 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            childAspectRatio: MediaQuery.of(context).size.width > 1400
                ? 3.0
                : MediaQuery.of(context).size.width > 1100
                    ? 2.4
                    : MediaQuery.of(context).size.width > 800
                        ? 2.0
                        : MediaQuery.of(context).size.width > 640
                            ? 1.7
                            : 2.6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _summaryCard(
                title: 'Patrimônio total',
                value: _currency.format(patrimonio),
                subtitle: 'Valor investido: ${_currency.format(totalInvestido)}',
                icon: Icons.account_balance_wallet_outlined,
              ),
              _summaryCard(
                title: 'Lucro estimado',
                value: _currency.format((patrimonio - totalInvestido).clamp(-999999999, 999999999)),
                subtitle: 'Com base nos lançamentos da carteira',
                icon: Icons.trending_up,
              ),
              _summaryCard(
                title: 'Ativos cadastrados',
                value: investments.length.toString(),
                subtitle: '${grouped.length} classes de ativos',
                icon: Icons.pie_chart_outline,
              ),
              _summaryCard(
                title: 'Moedas e cripto',
                value: 'USD ${_quotes['USD']?.toStringAsFixed(2) ?? '0.00'} • BTC ${_quotes['BTC']?.toStringAsFixed(0) ?? '0'}',
                subtitle: 'EUR ${_quotes['EUR']?.toStringAsFixed(2) ?? '0.00'} • ETH ${_quotes['ETH']?.toStringAsFixed(0) ?? '0'}',
                icon: Icons.currency_exchange,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _sectionCard(
                  height: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evolução dos lançamentos',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      Expanded(child: _evolutionChart(investments)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _sectionCard(
                  height: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ativos na carteira',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      Expanded(child: _distributionChart(investments)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meus Ativos (${investments.length})',
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...grouped.entries.map((entry) {
                  final total = entry.value.fold<double>(0, (sum, inv) => sum + inv.valorInvestido);
                  final pct = dist.isEmpty ? 0 : ((dist[entry.key] ?? 0) / dist.values.fold<double>(0, (s, v) => s + v)) * 100;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            entry.key,
                            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('Ativos ${entry.value.length} • Valor total ${_currency.format(total)} • % na carteira ${pct.toStringAsFixed(1)}%'),
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
                            rows: entry.value.map((inv) {
                              final parts = inv.nome.split('•').map((e) => e.trim()).toList();
                              final ativo = parts.length > 1 ? parts[1] : inv.nome;
                              final operacao = parts.length > 2 ? parts[2] : (inv.valorInvestido >= 0 ? 'Compra' : 'Venda');
                              return DataRow(cells: [
                                DataCell(Text(ativo)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                DataCell(Text(DateFormat('dd/MM/yyyy').format(inv.data))),
                                DataCell(Text(_currency.format(inv.valorInvestido))),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _service.deleteInvestment(inv.id),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
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
              Expanded(child: _topListCard('Top ETFs do dia', _topEtfs)),
              const SizedBox(width: 10),
              Expanded(child: _topListCard('Top FIIs do dia', _topFiis)),
              const SizedBox(width: 10),
              Expanded(child: _topListCard('Top Ações do dia', _topStocks)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProventosTab() {
    return StreamBuilder<List<ProventoModel>>(
      stream: _service.getProventos(),
      builder: (context, snapshot) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final proventos = snapshot.data ?? [];
        final now = DateTime.now();
        final months = List.generate(
          13,
          (i) => DateTime(now.year, now.month - 12 + i, 1),
        );
        final currentYearLabel = DateFormat('yyyy').format(now);
        final labels = months.map((m) => DateFormat('MM/yy').format(m)).toList();
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
          if (isPaid && dateRef.isAfter(last12Start.subtract(const Duration(days: 1)))) {
            total12m += p.valorTotal;
            distributionMap.update(p.ativo, (v) => v + p.valorTotal, ifAbsent: () => p.valorTotal);
          }

          final idx = months.indexWhere((m) => m.year == dateRef.year && m.month == dateRef.month);
          if (idx >= 0) {
            if (isPaid) {
              received[idx] += p.valorTotal;
            } else {
              pending[idx] += p.valorTotal;
            }
          }
        }

        final mediaMensal = total12m / 12;
        final distEntries = distributionMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final distribution = distEntries.asMap().entries.take(5).map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final hue = (idx * 360 / (distEntries.isEmpty ? 1 : distEntries.length)) % 360;
          return _LegendEntry(
            label: item.key,
            amount: item.value,
            color: HSVColor.fromAHSV(1, hue, 0.65, 0.85).toColor(),
          );
        }).toList();

        final historicoMap = <int, List<double>>{};
        for (final p in proventos.where((p) => p.status.toLowerCase().contains('pago'))) {
          historicoMap.putIfAbsent(p.dataPagamento.year, () => List<double>.filled(12, 0));
          historicoMap[p.dataPagamento.year]![p.dataPagamento.month - 1] += p.valorTotal;
        }
        final proventosSorted = [...proventos]..sort((a, b) => b.dataPagamento.compareTo(a.dataPagamento));
        final historicoRows = historicoMap.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key));

        final isNarrow = MediaQuery.of(context).size.width < 1100;
        final summaryCard = _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumo',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Média Mensal (últ. 12 meses)',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    _currency.format(mediaMensal),
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ Criar meta',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
                  ),
                  const Spacer(),
                  Text('0%', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                  Text(
                    'Total de 12 meses',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Icon(Icons.expand_more, size: 18, color: colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _currency.format(total12m),
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Divider(),
              Text(
                'Total da carteira',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                _currency.format(totalCarteira),
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Divider(),
              Text(
                'Distribuição de proventos em 12 meses',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: distribution.isEmpty
                    ? const Center(child: Text('Sem proventos no período.'))
                    : _donutChartWithLegend(distribution, showAmount: false),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () {}, child: const Text('Ver todos')),
              ),
            ],
          ),
        );

        final chartCard = _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Evolução de Proventos',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  _segmentedControl(
                    options: const ['Mensal', 'Anual'],
                    selected: _proventosPeriodo,
                    onChanged: (value) => setState(() => _proventosPeriodo = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _filterPill('Últimos 12 meses', leading: Icons.calendar_month_outlined),
                  _filterPill('Tipo de ativo', leading: Icons.tune),
                  _filterPill('Ativos', leading: Icons.account_balance_wallet_outlined),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _LegendDot(color: colorScheme.primary, label: 'Proventos recebidos'),
                  const SizedBox(width: 12),
                  _LegendDot(color: colorScheme.primaryContainer, label: 'Proventos a receber'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: received.every((v) => v == 0) && pending.every((v) => v == 0)
                    ? const Center(child: Text('Sem proventos no período.'))
                    : _proventosBarChart(labels, received, pending),
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
                    onPressed: _importingProventos ? null : _importProventosCsv,
                    icon: _importingProventos
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text('Importar CSV'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _importingProventos ? null : _importProventosApi,
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
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: summaryCard),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: chartCard),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Histórico mensal',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        _pill(
                          'Total  ${_currency.format(total12m)}',
                          background: colorScheme.secondaryContainer,
                          textColor: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 10),
                        _filterPill('Recebidos', leading: Icons.calendar_month_outlined),
                        const SizedBox(width: 8),
                        _filterPill('Tipo de ativo', leading: Icons.tune),
                        const SizedBox(width: 8),
                        _filterPill('Ativos', leading: Icons.account_balance_wallet_outlined),
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
                                final monthsValues = entry.value;
                                final total = monthsValues.fold<double>(0, (s, v) => s + v);
                                final media = total / 12;
                                final cells = [
                                  year.toString(),
                                  ...monthsValues.map((v) => _formatDecimalValue(v, 2)),
                                  _formatDecimalValue(media, 2),
                                  _formatDecimalValue(total, 2),
                                ];
                                return DataRow(cells: cells.map((cell) => DataCell(Text(cell))).toList());
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Meus proventos',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        _pill(
                          'Total  ${_currency.format(totalCarteira)}',
                          background: colorScheme.secondaryContainer,
                          textColor: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 10),
                        _filterPill(currentYearLabel, leading: Icons.calendar_month_outlined),
                        const SizedBox(width: 8),
                        _filterPill('Tipo de ativo', leading: Icons.tune),
                        const SizedBox(width: 8),
                        _filterPill('Ativos', leading: Icons.account_balance_wallet_outlined),
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
                                DataColumn(label: Text('Status do pagamento')),
                                DataColumn(label: Text('Tipo de pagamento')),
                                DataColumn(label: Text('Data Com')),
                                DataColumn(label: Text('Data Pagamento')),
                                DataColumn(label: Text('Quantidade')),
                                DataColumn(label: Text('Valor do div.')),
                                DataColumn(label: Text('Valor total')),
                              ],
                              rows: proventosSorted.map((row) {
                                final statusColor = row.status.toLowerCase().contains('pago')
                                    ? colorScheme.tertiaryContainer
                                    : colorScheme.secondaryContainer;
                                final statusText = row.status.toLowerCase().contains('pago')
                                    ? colorScheme.tertiary
                                    : colorScheme.secondary;
                                return DataRow(cells: [
                                  DataCell(Text(row.ativo)),
                                  DataCell(
                                    _pill(
                                      row.tipoAtivo,
                                      background: colorScheme.surfaceContainerHighest,
                                      textColor: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  DataCell(_pill(row.status, background: statusColor, textColor: statusText, icon: Icons.monetization_on_outlined)),
                                  DataCell(Text(row.tipoPagamento)),
                                  DataCell(Text(DateFormat('dd/MM/yyyy').format(row.dataCom))),
                                  DataCell(Text(DateFormat('dd/MM/yyyy').format(row.dataPagamento))),
                                  DataCell(Text(_formatDecimalValue(row.quantidade, 2))),
                                  DataCell(Text(_currency.format(row.valorDiv))),
                                  DataCell(Text(_currency.format(row.valorTotal))),
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

  Widget _buildPatrimonioTab({required List<InvestmentModel> investments}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final labels = List.generate(
      12,
      (i) => DateFormat('MM/yy').format(DateTime(now.year, now.month - 11 + i)),
    );
    final base = investments.fold<double>(0, (sum, inv) => sum + inv.valorInvestido.abs());
    final appliedSeed = base > 0 ? base / 12 : 920;
    final gainSeed = base > 0 ? appliedSeed * 0.06 : 40;
    final applied = List<double>.generate(12, (i) => appliedSeed + (i * appliedSeed * 0.02)).toList();
    final gain = List<double>.generate(12, (i) => gainSeed + (i * gainSeed * 0.02)).toList();

    final dist = _distributionByType(investments);
    final palette = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
    ];
    final consolidacao = dist.isNotEmpty
        ? dist.entries.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final hue = (idx * 360 / dist.length) % 360;
            return _LegendEntry(
              label: item.key,
              amount: item.value.abs(),
              color: HSVColor.fromAHSV(1, hue, 0.65, 0.85).toColor(),
            );
          }).toList()
        : <_LegendEntry>[
            _LegendEntry(label: 'Renda Fixa', amount: 601.15, color: palette[0]),
            _LegendEntry(label: 'Ações', amount: 237.82, color: palette[1]),
            _LegendEntry(label: 'FIIs', amount: 209.40, color: palette[2]),
          ];

    final acoes = <_LegendEntry>[
      _LegendEntry(label: 'BBAS3', amount: 50.42, color: palette[0]),
      _LegendEntry(label: 'WEGE3', amount: 47.25, color: palette[1]),
      _LegendEntry(label: 'ITSA3', amount: 40.98, color: palette[2]),
      _LegendEntry(label: 'BBSE3', amount: 34.71, color: palette[3]),
      _LegendEntry(label: 'EGIE3', amount: 32.70, color: palette[4]),
      _LegendEntry(label: 'KLBN3', amount: 31.76, color: palette[5]),
    ];

    final fiis = <_LegendEntry>[
      _LegendEntry(label: 'GARE11', amount: 41.75, color: palette[0]),
      _LegendEntry(label: 'VGIR11', amount: 39.08, color: palette[1]),
      _LegendEntry(label: 'BTCI11', amount: 36.96, color: palette[2]),
      _LegendEntry(label: 'VGHF11', amount: 35.25, color: palette[3]),
      _LegendEntry(label: 'XPCA11', amount: 34.88, color: palette[4]),
      _LegendEntry(label: 'VINO11', amount: 21.48, color: palette[5]),
    ];

    final rendaFixa = <_LegendEntry>[
      _LegendEntry(
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
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Evolução do Patrimônio',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    _filterPill('12 Meses', leading: Icons.calendar_month_outlined),
                    const SizedBox(width: 8),
                    _filterPill('Todos os tipos', leading: Icons.tune),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _LegendDot(color: colorScheme.tertiary, label: 'Valor aplicado'),
                    const SizedBox(width: 14),
                    _LegendDot(color: colorScheme.tertiaryContainer, label: 'Ganho capital'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(height: 260, child: _patrimonioBarChart(labels, applied, gain)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Consolidação do patrimônio',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    _segmentedControl(
                      options: const ['Tipo de ativos', 'Ativos', 'Exposição ao exterior'],
                      selected: _patrimonioConsolidacao,
                      onChanged: (value) => setState(() => _patrimonioConsolidacao = value),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Exibir posição ideal',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: _showIdealConsolidacao,
                      onChanged: (value) => setState(() => _showIdealConsolidacao = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(height: 240, child: _donutChartWithLegend(consolidacao)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Ações',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    _segmentedControl(
                      options: const ['Consolidado', 'Por tipo', 'Por segmento'],
                      selected: _patrimonioAcoes,
                      onChanged: (value) => setState(() => _patrimonioAcoes = value),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Exibir posição ideal',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: _showIdealAcoes,
                      onChanged: (value) => setState(() => _showIdealAcoes = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(height: 240, child: _donutChartWithLegend(acoes)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'FIIs',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    _segmentedControl(
                      options: const ['Consolidado', 'Por tipo', 'Por segmento'],
                      selected: _patrimonioFiis,
                      onChanged: (value) => setState(() => _patrimonioFiis = value),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Exibir posição ideal',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: _showIdealFiis,
                      onChanged: (value) => setState(() => _showIdealFiis = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(height: 240, child: _donutChartWithLegend(fiis)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Renda Fixa',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      'Exibir posição ideal',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: _showIdealRendaFixa,
                      onChanged: (value) => setState(() => _showIdealRendaFixa = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(height: 240, child: _donutChartWithLegend(rendaFixa)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentabilidadeTab() {
    return StreamBuilder<List<RentabilidadeModel>>(
      stream: _service.getRentabilidade(),
      builder: (context, snapshot) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final entries = [...(snapshot.data ?? [])];
        entries.sort((a, b) => a.data.compareTo(b.data));

        double compoundPercent(Iterable<double> values) {
          var acc = 1.0;
          for (final v in values) {
            acc *= 1 + (v / 100);
          }
          return (acc - 1) * 100;
        }

        String pct(double value) => '${value.toStringAsFixed(2).replaceAll('.', ',')}%';

        final now = DateTime.now();
        final last12Start = DateTime(now.year, now.month - 11, 1);
        final last12 = entries.where((e) => e.data.isAfter(last12Start.subtract(const Duration(days: 1)))).toList();
        final totalReturn = entries.isEmpty ? 0.0 : compoundPercent(entries.map((e) => e.rentabilidade));
        final totalCdi = entries.isEmpty ? 0.0 : compoundPercent(entries.map((e) => e.cdi));
        final last12Return = last12.isEmpty ? 0.0 : compoundPercent(last12.map((e) => e.rentabilidade));
        final last12Cdi = last12.isEmpty ? 0.0 : compoundPercent(last12.map((e) => e.cdi));
        final lastMonth = entries.isNotEmpty ? entries.last : null;

        final seriesEntries = entries.length > 24 ? entries.sublist(entries.length - 24) : entries;
        final rentSeries = <double>[];
        final cdiSeries = <double>[];
        var rentAcc = 1.0;
        var cdiAcc = 1.0;
        for (final entry in seriesEntries) {
          rentAcc *= 1 + (entry.rentabilidade / 100);
          cdiAcc *= 1 + (entry.cdi / 100);
          rentSeries.add((rentAcc - 1) * 100);
          cdiSeries.add((cdiAcc - 1) * 100);
        }

        final byYear = <int, List<RentabilidadeModel?>>{};
        for (final entry in entries) {
          byYear.putIfAbsent(entry.data.year, () => List<RentabilidadeModel?>.filled(12, null));
          byYear[entry.data.year]![entry.data.month - 1] = entry;
        }
        final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

        final tableRows = <List<String>>[];
        double acumulado = 1.0;
        final yearsAsc = years.toList()..sort();
        final acumuladoByYear = <int, double>{};
        for (final year in yearsAsc) {
          final months = byYear[year] ?? List<RentabilidadeModel?>.filled(12, null);
          final yearReturn = compoundPercent(months.whereType<RentabilidadeModel>().map((e) => e.rentabilidade));
          acumulado *= 1 + (yearReturn / 100);
          acumuladoByYear[year] = (acumulado - 1) * 100;
        }
        for (final year in years) {
          final months = byYear[year] ?? List<RentabilidadeModel?>.filled(12, null);
          final monthValues = months
              .map((entry) => entry == null ? '-' : pct(entry.rentabilidade))
              .toList();
          final yearReturn = compoundPercent(months.whereType<RentabilidadeModel>().map((e) => e.rentabilidade));
          tableRows.add([
            year.toString(),
            ...monthValues,
            pct(yearReturn),
            pct(acumuladoByYear[year] ?? 0),
          ]);
        }

        final isNarrow = MediaQuery.of(context).size.width < 1100;
        final totalColor = totalReturn >= 0 ? colorScheme.tertiary : colorScheme.error;
        final last12Color = last12Return >= 0 ? colorScheme.tertiary : colorScheme.error;
        final lastMonthColor = (lastMonth?.rentabilidade ?? 0) >= 0 ? colorScheme.tertiary : colorScheme.error;

        final kpiCards = Column(
          children: [
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    pct(totalReturn),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: totalColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(totalReturn - totalCdi).toStringAsFixed(2).replaceAll('.', ',')}% ${totalReturn >= totalCdi ? 'acima' : 'abaixo'} do CDI',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Últimos 12 meses',
                    style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pct(last12Return),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: last12Color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(last12Return - last12Cdi).toStringAsFixed(2).replaceAll('.', ',')}% ${last12Return >= last12Cdi ? 'acima' : 'abaixo'} do CDI',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Último mês',
                    style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pct(lastMonth?.rentabilidade ?? 0),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: lastMonthColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${((lastMonth?.rentabilidade ?? 0) - (lastMonth?.cdi ?? 0)).toStringAsFixed(2).replaceAll('.', ',')}% ${(lastMonth?.rentabilidade ?? 0) >= (lastMonth?.cdi ?? 0) ? 'acima' : 'abaixo'} do CDI',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        );

        final chartCard = _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Rentabilidade comparada com índices',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  _filterPill(_rentabilidadeRange, leading: Icons.calendar_month_outlined),
                  const SizedBox(width: 8),
                  _filterPill('Todos os tipos', leading: Icons.tune),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _LegendDot(color: colorScheme.primary, label: 'Rentabilidade'),
                  _LegendDot(color: colorScheme.secondary, label: 'CDI'),
                  _LegendDot(color: colorScheme.onSurfaceVariant, label: 'IPCA'),
                  _LegendDot(color: colorScheme.onSurfaceVariant, label: 'IFIX'),
                  _LegendDot(color: colorScheme.onSurfaceVariant, label: 'IBOV'),
                  _LegendDot(color: colorScheme.onSurfaceVariant, label: 'SMLL'),
                  _LegendDot(color: colorScheme.onSurfaceVariant, label: 'IDIV'),
                  _LegendDot(color: colorScheme.onSurfaceVariant, label: 'IVVB11'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: rentSeries.isEmpty
                    ? const Center(child: Text('Sem dados de rentabilidade.'))
                    : _rentabilidadeLineChart(
                        rentSeries,
                        cdiSeries,
                        labels: seriesEntries.map<DateTime>((e) => e.data).toList(),
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
                    onPressed: _importingRentabilidade ? null : _importRentabilidadeCsv,
                    icon: _importingRentabilidade
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text('Importar CSV'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _importingRentabilidade ? null : _importRentabilidadeApi,
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
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 260, child: kpiCards),
                    const SizedBox(width: 12),
                    Expanded(child: chartCard),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rentabilidade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                                  .map((row) => DataRow(cells: row.map((cell) => DataCell(Text(cell))).toList()))
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: StreamBuilder<List<InvestmentModel>>(
          stream: _service.getInvestments(),
          builder: (context, snapshot) {
            final investments = snapshot.data ?? [];
            final patrimonio = investments.fold<double>(0, (sum, inv) => sum + inv.valorInvestido);
            final totalInvestido = investments
                .where((inv) => inv.valorInvestido > 0)
                .fold<double>(0, (sum, inv) => sum + inv.valorInvestido);
            final dist = _distributionByType(investments);
            final grouped = _groupedByType(investments);

            return DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Investimentos',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const ThemeModeToggle(compact: true),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _refreshMarketData,
                          icon: const Icon(Icons.refresh),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _openLaunchDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar lançamento'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TabBar(
                      labelColor: colorScheme.onSurface,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      indicatorColor: colorScheme.primary,
                      indicatorWeight: 2,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: colorScheme.outlineVariant,
                      labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      tabs: const [
                        Tab(text: 'Resumo'),
                        Tab(text: 'Proventos'),
                        Tab(text: 'Patrimônio'),
                        Tab(text: 'Rentabilidade'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildResumoTab(
                          investments: investments,
                          patrimonio: patrimonio,
                          totalInvestido: totalInvestido,
                          dist: dist,
                          grouped: grouped,
                        ),
                        _buildProventosTab(),
                        _buildPatrimonioTab(investments: investments),
                        _buildRentabilidadeTab(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _topListCard(String title, List<MarketTicker> items) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Sem dados no momento.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final positive = item.changePercent >= 0;
                      final displayName = (item.name == null ||
                              item.name!.isEmpty ||
                              item.name == item.symbol)
                          ? item.symbol
                          : '${item.symbol} • ${item.name}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${index + 1}. $displayName',
                                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(_currency.format(item.price)),
                            const SizedBox(width: 6),
                            Text(
                              '${item.changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: positive ? colorScheme.tertiary : colorScheme.error,
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

class _LegendEntry {
  const _LegendEntry({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(width: 6),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}


class _AssetSearchField extends StatefulWidget {
  const _AssetSearchField({
    required this.controller,
    required this.tipoSelecionado,
    required this.api,
    required this.onSelect,
    required this.isUsd,
    required this.isFundos,
  });

  final TextEditingController controller;
  final String tipoSelecionado;
  final ApiService api;
  final ValueChanged<AssetOption> onSelect;
  final bool isUsd;
  final bool isFundos;

  @override
  State<_AssetSearchField> createState() => _AssetSearchFieldState();
}

class _AssetSearchFieldState extends State<_AssetSearchField> {
  List<AssetOption> _options = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search(widget.controller.text);
  }

  @override
  void didUpdateWidget(covariant _AssetSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tipoSelecionado != widget.tipoSelecionado) {
      _options = [];
      _queueSearch(widget.controller.text);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _queueSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _search(value);
    });
  }

  Future<void> _search(String value) async {
    setState(() => _loading = true);
    final results = await widget.api.searchAssetsByType(
      tipo: widget.tipoSelecionado,
      query: value,
    );
    if (!mounted) return;
    setState(() {
      _options = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: 'Ativo',
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _queueSearch,
        ),
        if (_options.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _options.length,
              itemBuilder: (context, index) {
                final item = _options[index];
                return ListTile(
                  dense: true,
                  title: Text(item.label),
                  subtitle: Text(
                    '${item.currency == 'USD' ? 'US\$' : 'R\$'} ${item.price.toStringAsFixed(widget.isFundos || widget.tipoSelecionado == 'Criptomoedas' || widget.isUsd ? 8 : 2)}',
                  ),
                  onTap: () {
                    widget.controller.text = item.label;
                    widget.onSelect(item);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class PtBrDecimalInputFormatter extends TextInputFormatter {
  PtBrDecimalInputFormatter({required this.decimalDigits, this.suffix = ''});

  final int decimalDigits;
  final String suffix;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      final empty = decimalDigits == 0 ? '0' : '0,${'0' * decimalDigits}';
      return TextEditingValue(
        text: '$empty$suffix',
        selection: TextSelection.collapsed(offset: empty.length),
      );
    }

    final parsed = double.parse(digits) / _pow10(decimalDigits);
    final formatted = NumberFormat.decimalPatternDigits(
      locale: 'pt_BR',
      decimalDigits: decimalDigits,
    ).format(parsed);
    final text = '$formatted$suffix';

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  double _pow10(int exp) {
    var value = 1.0;
    for (var i = 0; i < exp; i++) {
      value *= 10;
    }
    return value;
  }
}
