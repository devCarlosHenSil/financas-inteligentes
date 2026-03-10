import 'dart:async';

import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/screens/investments_screen.dart';
import 'package:financas_inteligentes/screens/shopping_list_screen.dart';
import 'package:financas_inteligentes/screens/transactions_screen.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';
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

class _CategorySelection {
  _CategorySelection({
    required this.item,
    required this.percent,
  });

  final _CategoryTotal item;
  final double percent;
}

class DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _service = FirestoreService();
  final NumberFormat _currencyFormatter = NumberFormat.currency(symbol: 'R\$');

  StreamSubscription<List<TransactionModel>>? _transactionsSubscription;

  bool _isLoading = true;
  int _touchedIncomeIndex = -1;
  int _touchedExpenseIndex = -1;

  double totalEntradas = 0;
  double totalSaidas = 0;
  double totalSuperfluos = 0;

  Map<String, double> entradasPorCategoria = {};
  Map<String, double> saidasPorCategoria = {};

  @override
  void initState() {
    super.initState();
    _listenTransactions();
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  void _listenTransactions() {
    _transactionsSubscription =
        _service.getTransactions().listen((transactions) {
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

  String getGastosAnalise() {
    if (totalSuperfluos > totalSaidas * 0.3) {
      return 'Você gastou muito em supérfluos (${_currencyFormatter.format(totalSuperfluos)}). Revise gastos variáveis para equilibrar o mês.';
    }

    return 'Bons gastos! Supérfluos sob controle (${_currencyFormatter.format(totalSuperfluos)}).';
  }

  List<_CategoryTotal> _prepareChartData(Map<String, double> data) {
    return data.entries
        .map((entry) => _CategoryTotal(nome: entry.key, valor: entry.value))
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
  }

  Color _incomeTone(int index) {
    const tones = [
      Color(0xFF2E7D32),
      Color(0xFF43A047),
      Color(0xFF66BB6A),
      Color(0xFF81C784),
    ];

    return tones[index % tones.length];
  }

  Color _categoryColor(String category,
      {required bool isIncome, int index = 0}) {
    if (isIncome) {
      return _incomeTone(index);
    }

    final name = category.toLowerCase().trim();

    if (name.contains('mercado livre')) return const Color(0xFFFDD835);
    if (name.contains('shopee')) return const Color(0xFFFF6D00);
    if (name.contains('amazon')) return const Color(0xFFFF9900);
    if (name.contains('magalu') || name.contains('magazine luiza')) {
      return const Color(0xFF0086FF);
    }

    final hue =
        (name.codeUnits.fold<int>(0, (sum, c) => sum + c) % 360).toDouble();

    return HSVColor.fromAHSV(1, hue, 0.55, 0.82).toColor();
  }

  List<PieChartSectionData> _getPieSections(
    List<_CategoryTotal> items, {
    required bool isIncome,
    required int touchedIndex,
  }) {
    if (items.isEmpty) return [];

    final total = items.fold<double>(0, (sum, item) => sum + item.valor);

    return List.generate(items.length, (index) {
      final item = items[index];

      final percent = total == 0 ? 0 : (item.valor / total) * 100;

      final isTouched = index == touchedIndex;

      return PieChartSectionData(
        value: item.valor,
        color: _categoryColor(item.nome, isIncome: isIncome, index: index),
        title: isTouched
            ? '${item.nome}\n${percent.toStringAsFixed(1)}%'
            : '${percent.toStringAsFixed(1)}%',
        radius: isTouched ? 98 : 84,
        titleStyle: TextStyle(
          fontSize: isTouched ? 10 : 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  _CategorySelection? _selectedCategory(
    List<_CategoryTotal> items,
    int touchedIndex,
  ) {
    if (items.isEmpty || touchedIndex < 0 || touchedIndex >= items.length) {
      return null;
    }

    final total = items.fold<double>(0, (sum, item) => sum + item.valor);
    final selectedItem = items[touchedIndex];
    final percent = total == 0 ? 0 : (selectedItem.valor / total) * 100;

    return _CategorySelection(item: selectedItem, percent: percent);
  }

  Widget _buildCategoryList(List<_CategoryTotal> items, {required bool isIncome}) {
    if (items.isEmpty) {
      return const Text(
        'Sem categorias no período.',
        style: TextStyle(color: Colors.white70),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List.generate(items.length, (index) {
        final item = items[index];
        final color = _categoryColor(item.nome, isIncome: isIncome, index: index);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.nome,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildPieChart(
    List<_CategoryTotal> items, {
    required bool isIncome,
    required int touchedIndex,
  }) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        borderData: FlBorderData(show: false),
        sections: _getPieSections(
          items,
          isIncome: isIncome,
          touchedIndex: touchedIndex,
        ),
        pieTouchData: PieTouchData(
          enabled: true,
          touchCallback: (event, response) {
            final idx = response?.touchedSection?.touchedSectionIndex ?? -1;

            setState(() {
              if (isIncome) {
                _touchedIncomeIndex = idx;
              } else {
                _touchedExpenseIndex = idx;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Map<String, double> data,
    required bool isIncome,
  }) {
    final items = _prepareChartData(data);

    final touchedIndex =
        isIncome ? _touchedIncomeIndex : _touchedExpenseIndex;
    final selection = _selectedCategory(items, touchedIndex);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildPieChart(
                items,
                isIncome: isIncome,
                touchedIndex: touchedIndex,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selection == null
                  ? 'Passe o mouse em uma fatia para ver a categoria.'
                  : '${selection.item.nome} • ${_currencyFormatter.format(selection.item.valor)} (${selection.percent.toStringAsFixed(1)}%)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildCategoryList(items, isIncome: isIncome),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsAndActions(BuildContext context, double saldo) {
    final saldoPositivo = saldo >= 0;

    final sugestao = saldoPositivo
        ? 'Saldo positivo de ${_currencyFormatter.format(saldo)}. Continue investindo.'
        : 'Saldo negativo de ${_currencyFormatter.format(saldo)}. Ajuste gastos.';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(getGastosAnalise()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(sugestao),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Transações'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvestmentsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.trending_up),
                label: const Text('Investimentos'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShoppingListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Lista de Compras'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = totalEntradas - totalSaidas;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1D4ED8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Balanço: ${_currencyFormatter.format(saldo)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildChartCard(
                        title: 'Entradas por Categoria',
                        data: entradasPorCategoria,
                        isIncome: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildChartCard(
                        title: 'Saídas por Categoria',
                        data: saidasPorCategoria,
                        isIncome: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildInsightsAndActions(context, saldo),
            ],
          ),
        ),
      ),
    );
  }
}
