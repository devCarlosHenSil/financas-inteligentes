import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/screens/investments_screen.dart';
import 'package:financas_inteligentes/screens/shopping_list_screen.dart';
import 'package:financas_inteligentes/screens/transactions_screen.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class _CategoryTotal {
  _CategoryTotal({required this.nome, required this.valor});

  final String nome;
  final double valor;
}

class DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _service = FirestoreService();
  final NumberFormat _currencyFormatter = NumberFormat.currency(symbol: 'R\$');

  StreamSubscription<List<TransactionModel>>? _transactionsSubscription;
  bool _isLoading = true;

  double totalEntradas = 0, totalSaidas = 0, totalSuperfluos = 0;
  Map<String, double> entradasPorCategoria = {};
  Map<String, double> saidasPorCategoria = {};

  @override
  void initState() {
    super.initState();
    _listenTransactions();
  }

  void _listenTransactions() {
    _transactionsSubscription = _service.getTransactions().listen((transactions) {
      final now = DateTime.now();
      final txMesAtual = transactions.where(
        (t) => t.data.month == now.month && t.data.year == now.year,
      );

      final Map<String, double> novasEntradasPorCategoria = {};
      final Map<String, double> novasSaidasPorCategoria = {};
      double novasEntradas = 0;
      double novasSaidas = 0;
      double novosSuperfluos = 0;

      for (final t in txMesAtual) {
        if (t.tipo == 'entrada') {
          novasEntradas += t.valor;
          novasEntradasPorCategoria.update(
            t.categoria,
            (value) => value + t.valor,
            ifAbsent: () => t.valor,
          );
        } else if (t.tipo == 'saida') {
          novasSaidas += t.valor;
          novasSaidasPorCategoria.update(
            t.categoria,
            (value) => value + t.valor,
            ifAbsent: () => t.valor,
          );
        }

        if (t.superfluo) {
          novosSuperfluos += t.valor;
        }
      }

      if (!mounted) return;
      setState(() {
        totalEntradas = novasEntradas;
        totalSaidas = novasSaidas;
        totalSuperfluos = novosSuperfluos;
        entradasPorCategoria = novasEntradasPorCategoria;
        saidasPorCategoria = novasSaidasPorCategoria;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  String getGastosAnalise() {
    if (totalSuperfluos > totalSaidas * 0.3) {
      return 'Você gastou muito em itens supérfluos (${_currencyFormatter.format(totalSuperfluos)}) – considere poupar mais!';
    }

    return 'Bons gastos! Supérfluos estão baixos (${_currencyFormatter.format(totalSuperfluos)}). Continue assim!';
  }

  List<_CategoryTotal> _prepareChartData(
    Map<String, double> data, {
    int maxItems = 6,
    double minPercent = 0.05,
  }) {
    if (data.isEmpty) return [];

    final ordered = data.entries
        .map((entry) => _CategoryTotal(nome: entry.key, valor: entry.value))
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));

    final total = ordered.fold<double>(0, (sum, item) => sum + item.valor);
    final selected = <_CategoryTotal>[];
    double outros = 0;

    for (final item in ordered) {
      final percent = total == 0 ? 0 : item.valor / total;
      final shouldGroup = selected.length >= maxItems || percent < minPercent;

      if (shouldGroup) {
        outros += item.valor;
      } else {
        selected.add(item);
      }
    }

    if (outros > 0) {
      selected.add(_CategoryTotal(nome: 'Outros', valor: outros));
    }

    return selected;
  }

  List<PieChartSectionData> _getPieSections(List<_CategoryTotal> items, Color baseColor) {
    if (items.isEmpty) return [];

    final total = items.fold<double>(0, (sum, item) => sum + item.valor);
    final palette = [
      baseColor,
      baseColor.withAlpha((0.8 * 255).round()),
      baseColor.withAlpha((0.65 * 255).round()),
      baseColor.withAlpha((0.5 * 255).round()),
      Colors.amber,
      Colors.deepPurple.shade300,
      Colors.blueGrey.shade400,
    ];

    return List.generate(items.length, (index) {
      final item = items[index];
      final percent = total == 0 ? 0 : (item.valor / total) * 100;

      return PieChartSectionData(
        value: item.valor,
        color: palette[index % palette.length],
        title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
        radius: 84,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  Widget _buildLegend(List<_CategoryTotal> items, Color baseColor) {
    final palette = [
      baseColor,
      baseColor.withAlpha((0.8 * 255).round()),
      baseColor.withAlpha((0.65 * 255).round()),
      baseColor.withAlpha((0.5 * 255).round()),
      Colors.amber,
      Colors.deepPurple.shade300,
      Colors.blueGrey.shade400,
    ];

    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: palette[index % palette.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.nome,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(_currencyFormatter.format(item.valor)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPieChartCard(String title, Map<String, double> data, Color color) {
    final items = _prepareChartData(data);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const SizedBox(
                height: 220,
                child: Center(child: Text('Sem dados para o mês atual')),
              )
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: _getPieSections(items, color),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildLegend(items, color),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = totalEntradas - totalSaidas;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading) const LinearProgressIndicator(),
              if (_isLoading) const SizedBox(height: 16),
              Text(
                'Balanço: ${_currencyFormatter.format(saldo)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildPieChartCard('Entradas por Categoria', entradasPorCategoria, Colors.green),
              const SizedBox(height: 16),
              _buildPieChartCard('Saídas por Categoria', saidasPorCategoria, Colors.red),
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(getGastosAnalise(), style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                color: Colors.white,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Dica para poupança: Com ${_currencyFormatter.format(saldo)} sobrando, invista R\$100/mês para acumular R\$1200 em 1 ano!',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                ),
                child: const Text('Transações'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InvestmentsScreen()),
                ),
                child: const Text('Investimentos'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
                ),
                child: const Text('Lista de Compras'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
