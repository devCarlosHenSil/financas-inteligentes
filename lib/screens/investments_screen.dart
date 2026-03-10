import 'dart:async';

import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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
    'Fundos Imobiliários',
    'Renda Fixa',
    'ETF',
    'Tesouro Direto',
    'Cripto',
    'Câmbio',
    'Outros',
  ];

  Map<String, double> _quotes = {'USD': 0, 'EUR': 0, 'BTC': 0, 'ETH': 0};
  List<MarketTicker> _topEtfs = [];
  List<MarketTicker> _topFiis = [];
  List<MarketTicker> _topStocks = [];
  bool _loadingMarket = true;

  Timer? _refreshTimer;

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

    String tipoSelecionado = _tiposCarteira.first;
    DateTime dataSelecionada = DateTime.now();
    bool isCompra = true;

    double parseCurrency(String value) {
      return double.tryParse(value.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final quantidade = parseCurrency(quantidadeController.text);
            final preco = parseCurrency(precoController.text);
            final custos = parseCurrency(custosController.text);
            final total = quantidade * preco + custos;

            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
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
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: tipoSelecionado,
                            decoration: const InputDecoration(labelText: 'Tipo de ativo'),
                            items: _tiposCarteira
                                .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                                .toList(),
                            onChanged: (value) => setDialogState(() => tipoSelecionado = value ?? _tiposCarteira.first),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: ativoController,
                            decoration: const InputDecoration(labelText: 'Ativo'),
                          ),
                        ),
                      ],
                    ),
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
                        Expanded(
                          child: TextField(
                            controller: quantidadeController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(labelText: 'Quantidade'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precoController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(labelText: 'Preço em R\$'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: custosController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(labelText: 'Outros custos'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                            _currency.format(total),
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
                            final ativo = ativoController.text.trim();
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
                          label: const Text('Adicionar lançamento'),
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Resumo dos Investimentos',
                          style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
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
                        child: Container(
                          height: 360,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
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
                        child: Container(
                          height: 360,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
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
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${index + 1}. ${item.symbol}',
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
