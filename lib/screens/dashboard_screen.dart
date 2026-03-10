import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/screens/transactions_screen.dart';
import 'package:financas_inteligentes/screens/investments_screen.dart';
import 'package:financas_inteligentes/screens/shopping_list_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _service = FirestoreService();
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
      return 'Você gastou muito em itens supérfluos (R\$$totalSuperfluos) – considere poupar mais!';
    } else {
      return 'Bons gastos! Supérfluos estão baixos (R\$$totalSuperfluos). Continue assim!';
    }
  }

  List<PieChartSectionData> _getPieSections(Map<String, double> data, Color baseColor) {
    Map<String, Color> categoryColors = {
      'Uber': Colors.black,
      'Mercado Livre': Colors.yellow,
      'Shopee': Colors.orange,
      'Pix para esposa': Colors.purple,
      'Padaria': Colors.brown[200]!,
      'Super Mercado': Colors.blue[200]!,
      // Adicione mais categorias se necessário
    };

    List<PieChartSectionData> sections = [];
    List<Color> defaultColors = [
      baseColor,
      baseColor.withAlpha((0.8 * 255).round()),
      baseColor.withAlpha((0.6 * 255).round()),
      baseColor.withAlpha((0.4 * 255).round()),
      baseColor.withAlpha((0.2 * 255).round())
    ];
    int colorIndex = 0;
    data.forEach((key, value) {
      Color color = categoryColors[key] ?? defaultColors[colorIndex % defaultColors.length];
      sections.add(PieChartSectionData(
        value: value,
        color: color,
        title: '$key\nR\$${value.toStringAsFixed(2)}',
        radius: 90,
        titlePositionPercentageOffset: 1.15,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
      ));
      colorIndex++;
    });
    return sections;
  }

  Widget _buildPieChart(Map<String, double> data, Color baseColor) {
    if (data.isEmpty) {
      return const Center(
        child: Text('Sem dados para o mês atual'),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 42,
        sections: _getPieSections(data, baseColor),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Balanço: ${NumberFormat.currency(symbol: 'R\$').format(totalEntradas - totalSaidas)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Entradas por Categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 300,
                child: _buildPieChart(entradasPorCategoria, Colors.green),
              ),
              const SizedBox(height: 20),
              const Text('Saídas por Categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 300,
                child: _buildPieChart(saidasPorCategoria, Colors.red),
              ),
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
                  child: Text('Dica para poupança: Com R\$${totalEntradas - totalSaidas} sobrando, invista R\$100/mês para acumular R\$1200 em 1 ano!', style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())), child: const Text('Transações')),
              ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvestmentsScreen())), child: const Text('Investimentos')),
              ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen())), child: const Text('Lista de Compras')),
            ],
          ),
        ),
      ),
    );
  }
}
