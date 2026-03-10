import 'dart:async';

import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  InvestmentsScreenState createState() => InvestmentsScreenState();
}

class InvestmentsScreenState extends State<InvestmentsScreen> {
  final FirestoreService _service = FirestoreService();
  final ApiService _api = ApiService();
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
  String _patrimonioRendaFixa = 'Consolidado';
  String _rentabilidadeRange = 'Desde o início';
  bool _showIdealConsolidacao = false;
  bool _showIdealAcoes = false;
  bool _showIdealFiis = false;
  bool _showIdealRendaFixa = false;

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
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Text('Total de cotas', style: TextStyle(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(
                              _formatDecimalValue(totalCotas, 8),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('Valor total', style: TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(
                            _formatCurrency(total, symbol: isUsd ? 'US\$' : 'R\$'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                        const Spacer(),
                        ElevatedButton.icon(
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: const Color(0xFF64748B)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
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
                return Text(DateFormat('MM/yy').format(months[idx]), style: const TextStyle(fontSize: 10));
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
                color: const Color(0xFF10B981),
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
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _filterPill(String label, {IconData? leading}) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              Icon(leading, size: 16, color: const Color(0xFF475569)),
              const SizedBox(width: 6),
            ],
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    String label, {
    Color background = const Color(0xFFF1F5F9),
    Color textColor = const Color(0xFF0F172A),
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
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
    return SegmentedButton<String>(
      segments: options.map((opt) => ButtonSegment(value: opt, label: Text(opt))).toList(),
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        side: MaterialStateProperty.all(const BorderSide(color: Color(0xFFE2E8F0))),
        backgroundColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.selected) ? const Color(0xFFF1F5F9) : Colors.white,
        ),
      ),
    );
  }

  Widget _donutChartWithLegend(List<_LegendEntry> entries, {bool showAmount = true}) {
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
                  Expanded(child: Text(entry.label, overflow: TextOverflow.ellipsis)),
                  Text('${pct.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 12)),
                  if (showAmount) ...[
                    const SizedBox(width: 8),
                    Text(_currency.format(entry.amount), style: const TextStyle(fontSize: 12)),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _proventosBarChart(List<String> labels, List<double> received, List<double> pending) {
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
                  child: Text(labels[idx], style: const TextStyle(fontSize: 10)),
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
                  BarChartRodStackItem(0, received[index], const Color(0xFF4F6FE5)),
                  BarChartRodStackItem(received[index], received[index] + pending[index], const Color(0xFFCBD5F5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _patrimonioBarChart(List<String> labels, List<double> applied, List<double> gain) {
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
                  child: Text(labels[idx], style: const TextStyle(fontSize: 10)),
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
                  BarChartRodStackItem(0, applied[index], const Color(0xFF22C55E)),
                  BarChartRodStackItem(applied[index], applied[index] + gain[index], const Color(0xFF86EFAC)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rentabilidadeLineChart(List<double> rentabilidade, List<double> cdi) {
    final maxValue = [...rentabilidade, ...cdi].fold<double>(0, (max, value) => value > max ? value : max);
    return LineChart(
      LineChartData(
        minY: 0,
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
                if (idx < 0 || idx >= rentabilidade.length) return const SizedBox.shrink();
                final month = idx + 1;
                final label = month % 2 == 1 ? '${month.toString().padLeft(2, '0')}/25' : '';
                return Text(label, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(rentabilidade.length, (index) => FlSpot(index.toDouble(), rentabilidade[index])),
            isCurved: true,
            color: const Color(0xFF4F6FE5),
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF4F6FE5).withOpacity(0.08)),
          ),
          LineChartBarData(
            spots: List.generate(cdi.length, (index) => FlSpot(index.toDouble(), cdi[index])),
            isCurved: true,
            color: const Color(0xFFF59E0B),
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoTab({
    required List<InvestmentModel> investments,
    required double patrimonio,
    required double totalInvestido,
    required Map<String, double> dist,
    required Map<String, List<InvestmentModel>> grouped,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo dos Investimentos', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
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
                      const Text('Evolução dos lançamentos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
                      const Text('Ativos na carteira', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
                Text('Meus Ativos (${investments.length})', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...grouped.entries.map((entry) {
                  final total = entry.value.fold<double>(0, (sum, inv) => sum + inv.valorInvestido);
                  final pct = dist.isEmpty ? 0 : ((dist[entry.key] ?? 0) / dist.values.fold<double>(0, (s, v) => s + v)) * 100;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(entry.key, style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w700)),
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
                                      color: operacao == 'Venda' ? Colors.red.shade50 : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      operacao,
                                      style: TextStyle(
                                        color: operacao == 'Venda' ? Colors.red.shade700 : Colors.green.shade700,
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
    final labels = <String>[
      '03/25',
      '04/25',
      '05/25',
      '06/25',
      '07/25',
      '08/25',
      '09/25',
      '10/25',
      '11/25',
      '12/25',
      '01/26',
      '02/26',
      '03/26',
    ];
    final received = <double>[8.2, 2.6, 3.8, 3.1, 2.6, 5.7, 2.4, 2.4, 2.6, 7.0, 2.3, 2.6, 3.8];
    final pending = <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1.1];
    final distribution = <_LegendEntry>[
      const _LegendEntry(label: 'VGIR11', amount: 13.19, color: Color(0xFF4F6FE5)),
      const _LegendEntry(label: 'GARE11', amount: 11.78, color: Color(0xFF38BDF8)),
      const _LegendEntry(label: 'VGHF11', amount: 11.68, color: Color(0xFF5EEAD4)),
      const _LegendEntry(label: 'BTCI11', amount: 9.52, color: Color(0xFFFACC15)),
      const _LegendEntry(label: 'XPCA11', amount: 8.32, color: Color(0xFFFB7185)),
    ];

    final historicoMensal = <List<String>>[
      ['2026', '2,37', '2,68', '3,77', '0,00', '0,00', '0,00', '0,00', '0,00', '0,00', '0,00', '0,00', '0,00', '2,94', '8,83'],
      ['2025', '2,02', '2,53', '8,26', '2,72', '3,88', '3,10', '2,64', '5,75', '2,43', '2,44', '2,72', '7,12', '3,80', '45,60'],
      ['2024', '2,51', '4,89', '4,17', '2,28', '2,85', '3,51', '3,69', '5,80', '2,57', '2,21', '2,55', '3,20', '3,35', '40,23'],
      ['2023', '0,00', '0,00', '0,00', '0,00', '0,00', '0,00', '0,00', '0,00', '0,00', '0,00', '0,00', '1,73', '0,14', '1,73'],
    ];

    final proventosRows = <_ProventoRow>[
      const _ProventoRow(
        ativo: 'BBSE3',
        tipoAtivo: 'Ações',
        status: 'Pago',
        tipoPagamento: 'Dividendos',
        dataCom: '12/02/2026',
        dataPagamento: '02/03/2026',
        quantidade: '1,00',
        valorDiv: 'R\$ 2,55',
        valorTotal: 'R\$ 2,55',
      ),
      const _ProventoRow(
        ativo: 'BBSE3',
        tipoAtivo: 'Ações',
        status: 'Pago',
        tipoPagamento: 'Rend. Trib.',
        dataCom: '12/02/2026',
        dataPagamento: '02/03/2026',
        quantidade: '1,00',
        valorDiv: 'R\$ 0,06',
        valorTotal: 'R\$ 0,06',
      ),
      const _ProventoRow(
        ativo: 'KLBN3',
        tipoAtivo: 'Ações',
        status: 'Pago',
        tipoPagamento: 'Dividendos',
        dataCom: '15/12/2025',
        dataPagamento: '27/02/2026',
        quantidade: '8,00',
        valorDiv: 'R\$ 0,05',
        valorTotal: 'R\$ 0,36',
      ),
      const _ProventoRow(
        ativo: 'VGIR11',
        tipoAtivo: 'FIIs',
        status: 'Pago',
        tipoPagamento: 'Dividendos',
        dataCom: '11/02/2026',
        dataPagamento: '20/02/2026',
        quantidade: '4,00',
        valorDiv: 'R\$ 0,13',
        valorTotal: 'R\$ 0,52',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        final summaryCard = _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Resumo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Média Mensal (últ. 12 meses)', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('R\$ 3,82', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text(' / Criar meta', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12)),
                  const Spacer(),
                  const Text('0%', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(
                value: 0.0,
                backgroundColor: Color(0xFFE2E8F0),
                color: Color(0xFF94A3B8),
                minHeight: 3,
              ),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: const [
                  Text('Total de 12 meses', style: TextStyle(color: Color(0xFF64748B))),
                  Spacer(),
                  Icon(Icons.expand_more, size: 18, color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('R\$ 45,81', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Divider(),
              const Text('Total da carteira', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              const Text('R\$ 96,38', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Divider(),
              const Text('Distribuição de proventos em 12 meses', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              SizedBox(height: 160, child: _donutChartWithLegend(distribution, showAmount: false)),
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
                  const Text('Evolução de Proventos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                children: const [
                  _LegendDot(color: Color(0xFF4F6FE5), label: 'Proventos recebidos'),
                  SizedBox(width: 12),
                  _LegendDot(color: Color(0xFFCBD5F5), label: 'Proventos a receber'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(height: 240, child: _proventosBarChart(labels, received, pending)),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        const Text('Histórico mensal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        _pill('Total  R\$ 96,38', background: const Color(0xFFE0F2FE), textColor: const Color(0xFF0284C7)),
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
                      child: DataTable(
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
                        rows: historicoMensal
                            .map((row) => DataRow(cells: row.map((cell) => DataCell(Text(cell))).toList()))
                            .toList(),
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
                        const Text('Meus proventos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        _pill('Total  R\$ 11,64', background: const Color(0xFFE0F2FE), textColor: const Color(0xFF0284C7)),
                        const SizedBox(width: 10),
                        _filterPill('2026', leading: Icons.calendar_month_outlined),
                        const SizedBox(width: 8),
                        _filterPill('Tipo de ativo', leading: Icons.tune),
                        const SizedBox(width: 8),
                        _filterPill('Ativos', leading: Icons.account_balance_wallet_outlined),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
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
                        rows: proventosRows.map((row) {
                          final statusColor = row.status == 'Pago' ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE);
                          final statusText = row.status == 'Pago' ? const Color(0xFF16A34A) : const Color(0xFF0284C7);
                          return DataRow(cells: [
                            DataCell(Text(row.ativo)),
                            DataCell(_pill(row.tipoAtivo, background: const Color(0xFFF1F5F9), textColor: const Color(0xFF475569))),
                            DataCell(_pill(row.status, background: statusColor, textColor: statusText, icon: Icons.monetization_on_outlined)),
                            DataCell(Text(row.tipoPagamento)),
                            DataCell(Text(row.dataCom)),
                            DataCell(Text(row.dataPagamento)),
                            DataCell(Text(row.quantidade)),
                            DataCell(Text(row.valorDiv)),
                            DataCell(Text(row.valorTotal)),
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
            const _LegendEntry(label: 'Renda Fixa', amount: 601.15, color: Color(0xFF38BDF8)),
            const _LegendEntry(label: 'Ações', amount: 237.82, color: Color(0xFF5EEAD4)),
            const _LegendEntry(label: 'FIIs', amount: 209.40, color: Color(0xFFFDE047)),
          ];

    final acoes = <_LegendEntry>[
      const _LegendEntry(label: 'BBAS3', amount: 50.42, color: Color(0xFF38BDF8)),
      const _LegendEntry(label: 'WEGE3', amount: 47.25, color: Color(0xFF22D3EE)),
      const _LegendEntry(label: 'ITSA3', amount: 40.98, color: Color(0xFF86EFAC)),
      const _LegendEntry(label: 'BBSE3', amount: 34.71, color: Color(0xFFFDE047)),
      const _LegendEntry(label: 'EGIE3', amount: 32.70, color: Color(0xFFFCA5A5)),
      const _LegendEntry(label: 'KLBN3', amount: 31.76, color: Color(0xFFFB7185)),
    ];

    final fiis = <_LegendEntry>[
      const _LegendEntry(label: 'GARE11', amount: 41.75, color: Color(0xFF38BDF8)),
      const _LegendEntry(label: 'VGIR11', amount: 39.08, color: Color(0xFF22D3EE)),
      const _LegendEntry(label: 'BTCI11', amount: 36.96, color: Color(0xFF86EFAC)),
      const _LegendEntry(label: 'VGHF11', amount: 35.25, color: Color(0xFFFDE047)),
      const _LegendEntry(label: 'XPCA11', amount: 34.88, color: Color(0xFFFCA5A5)),
      const _LegendEntry(label: 'VINO11', amount: 21.48, color: Color(0xFFFB7185)),
    ];

    final rendaFixa = <_LegendEntry>[
      const _LegendEntry(
        label: 'CDB - BANCO NUBANK - Pós-Fixado - 100% CDI',
        amount: 601.15,
        color: Color(0xFF38BDF8),
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
                    const Text('Evolução do Patrimônio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _filterPill('12 Meses', leading: Icons.calendar_month_outlined),
                    const SizedBox(width: 8),
                    _filterPill('Todos os tipos', leading: Icons.tune),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    _LegendDot(color: Color(0xFF22C55E), label: 'Valor aplicado'),
                    SizedBox(width: 14),
                    _LegendDot(color: Color(0xFF86EFAC), label: 'Ganho capital'),
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
                    const Text('Consolidação do patrimônio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _segmentedControl(
                      options: const ['Tipo de ativos', 'Ativos', 'Exposição ao exterior'],
                      selected: _patrimonioConsolidacao,
                      onChanged: (value) => setState(() => _patrimonioConsolidacao = value),
                    ),
                    const SizedBox(width: 12),
                    const Text('Exibir posição ideal', style: TextStyle(color: Color(0xFF64748B))),
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
                    const Text('Ações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _segmentedControl(
                      options: const ['Consolidado', 'Por tipo', 'Por segmento'],
                      selected: _patrimonioAcoes,
                      onChanged: (value) => setState(() => _patrimonioAcoes = value),
                    ),
                    const SizedBox(width: 12),
                    const Text('Exibir posição ideal', style: TextStyle(color: Color(0xFF64748B))),
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
                    const Text('FIIs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _segmentedControl(
                      options: const ['Consolidado', 'Por tipo', 'Por segmento'],
                      selected: _patrimonioFiis,
                      onChanged: (value) => setState(() => _patrimonioFiis = value),
                    ),
                    const SizedBox(width: 12),
                    const Text('Exibir posição ideal', style: TextStyle(color: Color(0xFF64748B))),
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
                    const Text('Renda Fixa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    const Text('Exibir posição ideal', style: TextStyle(color: Color(0xFF64748B))),
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
    final rentabilidade = <double>[
      0.5,
      2.2,
      3.1,
      4.6,
      6.2,
      7.4,
      9.1,
      11.4,
      10.6,
      12.2,
      14.8,
      15.4,
      17.2,
      18.1,
      19.4,
      20.2,
      22.3,
      24.1,
      26.7,
      28.9,
      27.8,
      29.4,
    ];
    final cdi = <double>[
      0.6,
      1.8,
      2.6,
      3.5,
      4.2,
      5.3,
      6.1,
      7.0,
      7.8,
      8.6,
      9.5,
      10.4,
      11.3,
      12.2,
      13.1,
      14.0,
      15.1,
      16.4,
      17.6,
      18.8,
      19.7,
      20.6,
    ];
    final tableRows = <List<String>>[
      ['2026', '2,52%', '1,05%', '-0,97%', '-', '-', '-', '-', '-', '-', '-', '-', '-', '2,60%', '28,15%'],
      ['2025', '1,50%', '-0,31%', '3,03%', '1,90%', '-0,45%', '1,20%', '-0,99%', '1,59%', '1,15%', '1,13%', '0,14%', '4,66%', '15,43%', '24,91%'],
      ['2024', '-0,38%', '1,90%', '1,34%', '-0,67%', '1,02%', '1,20%', '1,60%', '2,67%', '-1,13%', '-1,18%', '-0,45%', '0,37%', '6,39%', '8,21%'],
      ['2023', '-', '-', '-', '-', '-', '-', '-', '-', '-', '0,00%', '1,72%', '-', '1,72%', '1,72%'],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        final kpiCards = Column(
          children: [
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('28,15%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  SizedBox(height: 8),
                  Text('11,87% abaixo do CDI', style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Últimos 12 meses', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('17,03%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  SizedBox(height: 8),
                  Text('16,9% acima do CDI', style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Último mês', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('0,07%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  SizedBox(height: 8),
                  Text('93,41% abaixo do CDI', style: TextStyle(color: Color(0xFF64748B))),
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
                  const Text('Rentabilidade comparada com índices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                children: const [
                  _LegendDot(color: Color(0xFF4F6FE5), label: 'Rentabilidade'),
                  _LegendDot(color: Color(0xFFF59E0B), label: 'CDI'),
                  _LegendDot(color: Color(0xFF94A3B8), label: 'IPCA'),
                  _LegendDot(color: Color(0xFF94A3B8), label: 'IFIX'),
                  _LegendDot(color: Color(0xFF94A3B8), label: 'IBOV'),
                  _LegendDot(color: Color(0xFF94A3B8), label: 'SMLL'),
                  _LegendDot(color: Color(0xFF94A3B8), label: 'IDIV'),
                  _LegendDot(color: Color(0xFF94A3B8), label: 'IVVB11'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(height: 260, child: _rentabilidadeLineChart(rentabilidade, cdi)),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      child: DataTable(
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                        const Expanded(
                          child: Text(
                            'Investimentos',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: _refreshMarketData,
                          icon: const Icon(Icons.refresh),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
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
                      labelColor: const Color(0xFF0F172A),
                      unselectedLabelColor: const Color(0xFF64748B),
                      indicatorColor: const Color(0xFF0F172A),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
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
    return Container(
      height: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
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
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(_currency.format(item.price)),
                            const SizedBox(width: 6),
                            Text(
                              '${item.changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: positive ? Colors.green : Colors.red,
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

class _ProventoRow {
  const _ProventoRow({
    required this.ativo,
    required this.tipoAtivo,
    required this.status,
    required this.tipoPagamento,
    required this.dataCom,
    required this.dataPagamento,
    required this.quantidade,
    required this.valorDiv,
    required this.valorTotal,
  });

  final String ativo;
  final String tipoAtivo;
  final String status;
  final String tipoPagamento;
  final String dataCom;
  final String dataPagamento;
  final String quantidade;
  final String valorDiv;
  final String valorTotal;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

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
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
