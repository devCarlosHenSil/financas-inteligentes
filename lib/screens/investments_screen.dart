import 'dart:async';

import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  InvestmentsScreenState createState() => InvestmentsScreenState();
}

class InvestmentsScreenState extends State<InvestmentsScreen> {
  final FirestoreService _service = FirestoreService();
  final ApiService _api = ApiService();
  final Logger logger = Logger();
  final NumberFormat _currency = NumberFormat.currency(symbol: 'R\$');

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();

  final List<String> _tiposCarteira = const [
    'CDB',
    'LCI',
    'LCA',
    'Tesouro Direto',
    'ETF',
    'Ações',
    'Fundos Imobiliários',
    'Dólar',
    'Euro',
    'Ouro',
    'Renda Fixa',
    'Cripto',
    'Outros',
  ];

  String _tipoSelecionado = 'CDB';

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
    _nomeController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _refreshMarketData() async {
    setState(() => _loadingMarket = true);
    try {
      final results = await Future.wait([
        _api.getRealtimeQuotes(),
        _api.getTopEtfs(),
        _api.getTopFiis(),
        _api.getTopStocks(),
      ]);

      if (!mounted) return;
      setState(() {
        _quotes = results[0] as Map<String, double>;
        _topEtfs = results[1] as List<MarketTicker>;
        _topFiis = results[2] as List<MarketTicker>;
        _topStocks = results[3] as List<MarketTicker>;
        _loadingMarket = false;
      });
    } catch (e) {
      logger.e('Erro ao carregar dados de mercado: $e');
      if (!mounted) return;
      setState(() => _loadingMarket = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar os dados de mercado agora.'),
        ),
      );
    }
  }

  Future<void> _addInvestment() async {
    final nome = _nomeController.text.trim();
    final valor =
        double.tryParse(_valorController.text.trim().replaceAll(',', '.')) ?? 0;

    if (nome.isEmpty || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ativo e valor investido válido.')),
      );
      return;
    }

    await _service.addInvestment(
      InvestmentModel(
        id: '',
        nome: '$_tipoSelecionado • $nome',
        valorInvestido: valor,
        data: DateTime.now(),
      ),
    );

    _nomeController.clear();
    _valorController.clear();
  }

  Widget _quoteCard(String label, double value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(_currency.format(value), style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _topListCard(String title, List<MarketTicker> items) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(_currency.format(item.price)),
                              const SizedBox(width: 8),
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
      ),
    );
  }

  Map<String, double> _distributionByType(List<InvestmentModel> data) {
    final Map<String, double> dist = {};

    for (final inv in data) {
      final type = inv.nome.contains('•')
          ? inv.nome.split('•').first.trim()
          : 'Outros';
      dist.update(type, (v) => v + inv.valorInvestido,
          ifAbsent: () => inv.valorInvestido);
    }

    return dist;
  }

  Widget _distributionChart(List<InvestmentModel> data) {
    final dist = _distributionByType(data);
    final total = dist.values.fold<double>(0, (s, v) => s + v);

    if (dist.isEmpty || total == 0) {
      return const Center(child: Text('Sem dados de carteira para distribuir.'));
    }

    final entries = dist.entries.toList();
    return PieChart(
      PieChartData(
        centerSpaceRadius: 36,
        sections: List.generate(entries.length, (i) {
          final entry = entries[i];
          final pct = (entry.value / total) * 100;
          final hue = (entry.key.codeUnits.fold(0, (a, b) => a + b) % 360)
              .toDouble();
          return PieChartSectionData(
            value: entry.value,
            color: HSVColor.fromAHSV(1, hue, 0.6, 0.9).toColor(),
            title: '${entry.key}\n${pct.toStringAsFixed(1)}%',
            radius: 84,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<List<InvestmentModel>>(
              stream: _service.getInvestments(),
              builder: (context, snapshot) {
                final investments = snapshot.data ?? [];
                return Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Investimentos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _refreshMarketData,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      ],
                    ),
                    if (_loadingMarket) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _quoteCard('Dólar (USD/BRL)', _quotes['USD'] ?? 0),
                        const SizedBox(width: 8),
                        _quoteCard('Euro (EUR/BRL)', _quotes['EUR'] ?? 0),
                        const SizedBox(width: 8),
                        _quoteCard('Bitcoin (BTC)', _quotes['BTC'] ?? 0),
                        const SizedBox(width: 8),
                        _quoteCard('Ethereum (ETH)', _quotes['ETH'] ?? 0),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      DropdownButtonFormField<String>(
                                        initialValue: _tipoSelecionado,
                                        decoration: const InputDecoration(
                                            labelText: 'Tipo de investimento'),
                                        items: _tiposCarteira
                                            .map((t) => DropdownMenuItem(
                                                  value: t,
                                                  child: Text(t),
                                                ))
                                            .toList(),
                                        onChanged: (v) => setState(
                                            () => _tipoSelecionado = v ?? 'CDB'),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _nomeController,
                                        decoration: const InputDecoration(
                                            labelText: 'Nome do ativo'),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _valorController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Valor investido (R\$)'),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _addInvestment,
                                          icon: const Icon(Icons.add),
                                          label: const Text('Adicionar à carteira'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: _distributionChart(investments),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      _topListCard('Top 10 ETFs do dia', _topEtfs),
                                      const SizedBox(width: 8),
                                      _topListCard('Top 10 FIIs do dia', _topFiis),
                                      const SizedBox(width: 8),
                                      _topListCard('Top 10 Ações do dia', _topStocks),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Minha Carteira (${investments.length})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: investments.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                    'Sem investimentos cadastrados.',
                                                  ),
                                                )
                                              : ListView.builder(
                                                  itemCount: investments.length,
                                                  itemBuilder: (context, index) {
                                                    final inv = investments[index];
                                                    return ListTile(
                                                      dense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      title: Text(inv.nome),
                                                      subtitle:
                                                          Text(DateFormat('dd/MM/yyyy')
                                                              .format(inv.data)),
                                                      trailing: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(_currency.format(
                                                              inv.valorInvestido)),
                                                          IconButton(
                                                            icon: const Icon(
                                                                Icons.delete_outline),
                                                            onPressed: () => _service
                                                                .deleteInvestment(
                                                                    inv.id),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
